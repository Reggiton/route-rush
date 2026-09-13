--[[
	BusDamageEffects.client.lua

	Visual damage for every bus on a route: smoke from the hood that gets
	thicker and darker, a red tint that deepens (and pulses when critical),
	and flames when nearly wrecked. Everything scales gradually with the
	bus's Health attribute (set by the server's BusMonitor).

	Runs locally on each player's screen, so nothing extra replicates.
	Tuning lives in Shared/Config/DamageEffectsConfig.lua.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.DamageEffectsConfig)

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local REAPPLY_STEP = 0.02 -- only rebuild particle sequences when intensity moves this much

local tracked = {} -- [bus] = record

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- 0 at StartBelowHealth, 1 at 0 health.
local function intensityAtHealth(fraction)
	if Config.StartBelowHealth <= 0 then
		return 0
	end
	return math.clamp(1 - fraction / Config.StartBelowHealth, 0, 1)
end

local function targetIntensity(bus)
	local maxHealth = bus:GetAttribute("MaxHealth") or 0
	if maxHealth <= 0 then
		return 0
	end
	if bus:GetAttribute("BrokenDown") then
		return 1
	end
	local health = bus:GetAttribute("Health") or maxHealth
	return intensityAtHealth(math.clamp(health / maxHealth, 0, 1))
end

local function untrack(bus)
	local record = tracked[bus]
	if not record then
		return
	end
	tracked[bus] = nil
	record.ancestryConnection:Disconnect()
	record.attachment:Destroy()
	record.highlight:Destroy()
end

local function trackBus(bus)
	if tracked[bus] or not bus:IsA("Model") then
		return
	end
	local root = bus.PrimaryPart or bus:WaitForChild("Root", 10)
	if not root or tracked[bus] or not bus:IsDescendantOf(workspace) then
		return
	end

	-- Emitters sit on the hood, near the front of the roofline.
	local attachment = Instance.new("Attachment")
	attachment.Name = "DamageEffects"
	attachment.Position = Vector3.new(0, root.Size.Y / 2 + 0.5, -root.Size.Z / 2 + math.min(4, root.Size.Z * 0.2))
	attachment.Parent = root

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "DamageSmoke"
	smoke.Texture = SMOKE_TEXTURE
	smoke.Rate = 0
	smoke.Lifetime = NumberRange.new(1.5, 2.6)
	smoke.Speed = NumberRange.new(4, 8)
	smoke.SpreadAngle = Vector2.new(18, 18)
	smoke.Acceleration = Vector3.new(0, 3, 0)
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.Parent = attachment

	local fire = Instance.new("ParticleEmitter")
	fire.Name = "DamageFire"
	fire.Texture = FIRE_TEXTURE
	fire.Rate = 0
	fire.Lifetime = NumberRange.new(0.35, 0.7)
	fire.Speed = NumberRange.new(2, 5)
	fire.SpreadAngle = Vector2.new(20, 20)
	fire.LightEmission = 1
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(230, 60, 20))
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0.4) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	fire.Parent = attachment

	local highlight = Instance.new("Highlight")
	highlight.Name = "DamageTint"
	highlight.Adornee = bus
	highlight.FillColor = Config.TintColor
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = bus

	tracked[bus] = {
		attachment = attachment,
		smoke = smoke,
		fire = fire,
		highlight = highlight,
		intensity = 0,
		appliedIntensity = -1,
		ancestryConnection = bus.AncestryChanged:Connect(function()
			if not bus:IsDescendantOf(workspace) then
				untrack(bus)
			end
		end),
	}
end

-- Discovery: workspace.RouteInstances.Track_N.Buses.<bus> ---------------------------------------

local function watchTrack(track)
	local buses = track:WaitForChild("Buses", 10)
	if not buses then
		return
	end
	for _, bus in ipairs(buses:GetChildren()) do
		task.spawn(trackBus, bus)
	end
	buses.ChildAdded:Connect(function(bus)
		task.spawn(trackBus, bus)
	end)
end

local function watchInstances(folder)
	for _, track in ipairs(folder:GetChildren()) do
		task.spawn(watchTrack, track)
	end
	folder.ChildAdded:Connect(function(track)
		task.spawn(watchTrack, track)
	end)
end

local existing = workspace:FindFirstChild("RouteInstances")
if existing then
	watchInstances(existing)
end
workspace.ChildAdded:Connect(function(child)
	if child.Name == "RouteInstances" then
		watchInstances(child)
	end
end)

-- Per-frame update -------------------------------------------------------------------------------------

local fireStartIntensity = intensityAtHealth(Config.FireBelowHealth)
local pulseStartIntensity = intensityAtHealth(Config.PulseBelowHealth)

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for bus, record in pairs(tracked) do
		local target = targetIntensity(bus)
		record.intensity = record.intensity + (target - record.intensity) * math.min(1, dt * Config.Smoothing)
		local intensity = record.intensity

		if intensity < 0.01 then
			if record.appliedIntensity ~= 0 then
				record.appliedIntensity = 0
				record.smoke.Rate = 0
				record.fire.Rate = 0
				record.highlight.Enabled = false
			end
		else
			-- Smoke and fire (rebuilt only when intensity changes noticeably)
			if math.abs(intensity - record.appliedIntensity) >= REAPPLY_STEP then
				record.appliedIntensity = intensity

				local smokeRate = lerp(Config.SmokeMinRate, Config.SmokeMaxRate, intensity)
				if bus:GetAttribute("BrokenDown") then
					smokeRate = Config.BrokenDownSmokeRate
				end
				record.smoke.Rate = smokeRate
				record.smoke.Color = ColorSequence.new(Config.SmokeLightColor:Lerp(Config.SmokeDarkColor, intensity))
				local size = lerp(Config.SmokeMinSize, Config.SmokeMaxSize, intensity)
				record.smoke.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, size * 0.5),
					NumberSequenceKeypoint.new(1, size * 1.8),
				})
				record.smoke.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, lerp(0.65, 0.1, intensity)),
					NumberSequenceKeypoint.new(1, 1),
				})

				local fireStrength = fireStartIntensity < 1
						and math.clamp((intensity - fireStartIntensity) / (1 - fireStartIntensity), 0, 1)
					or 0
				record.fire.Rate = fireStrength * Config.FireMaxRate
			end

			-- Red tint, pulsing when critical
			local opacity = Config.TintMaxOpacity * intensity
			if intensity >= pulseStartIntensity then
				opacity = opacity * (0.65 + 0.35 * math.sin(now * Config.PulseSpeed))
			end
			record.highlight.Enabled = true
			record.highlight.FillTransparency = 1 - math.clamp(opacity, 0, 1)
		end
	end
end)
