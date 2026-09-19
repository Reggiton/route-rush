--[[
	DriverScreenEffects.client.lua

	What a hard-driven bus does to your screen, for YOUR bus only:

	  Engine strain   the edges bleed red as the engine cooks, and past
	                  ShakeAt the whole screen starts shaking. Both track
	                  the Strain attribute the server publishes (BusMonitor).
	  Breakdown       a short drain to black and white, so the wreck lands
	                  as a moment rather than just a pause.

	The vignette is built from four gradient strips rather than an image, so
	it needs no uploaded asset and scales to any screen.

	The shake is applied on BindToRenderStep AFTER the camera priority, so
	it layers on top of whatever ChaseCamera did that frame instead of
	fighting it for control of the camera.

	Tuning lives in DrivingConfig.Strain / .Collision.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DrivingConfig = require(ReplicatedStorage.Shared.Config.DrivingConfig)

local S = DrivingConfig.Strain

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SHAKE_MAX_POSITION = 0.55 -- studs at full strain
local SHAKE_MAX_ROTATION = 1.4 -- degrees at full strain
local SHAKE_SPEED = 38
local DESATURATE_SECONDS = 0.45
local DESATURATE_HOLD = 0.35

-- Vignette ---------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DriverScreenEffects"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 50
screenGui.Parent = playerGui

local strips = {}
do
	-- Each edge is a band that fades from solid at the screen edge to clear
	-- inward; together they read as a vignette.
	local EDGES = {
		{ name = "Top", size = UDim2.new(1, 0, 0.3, 0), position = UDim2.new(0, 0, 0, 0), rotation = 90 },
		{ name = "Bottom", size = UDim2.new(1, 0, 0.3, 0), position = UDim2.new(0, 0, 1, 0), rotation = 270, anchor = Vector2.new(0, 1) },
		{ name = "Left", size = UDim2.new(0.25, 0, 1, 0), position = UDim2.new(0, 0, 0, 0), rotation = 180 },
		{ name = "Right", size = UDim2.new(0.25, 0, 1, 0), position = UDim2.new(1, 0, 0, 0), rotation = 0, anchor = Vector2.new(1, 0) },
	}

	for _, edge in ipairs(EDGES) do
		local strip = Instance.new("Frame")
		strip.Name = edge.name
		strip.Size = edge.size
		strip.Position = edge.position
		strip.AnchorPoint = edge.anchor or Vector2.new(0, 0)
		strip.BackgroundColor3 = Color3.fromRGB(180, 20, 15)
		strip.BackgroundTransparency = 1
		strip.BorderSizePixel = 0
		strip.Parent = screenGui

		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge.rotation
		-- Opaque at the screen edge, gone by the inner side of the band.
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		gradient.Parent = strip

		table.insert(strips, strip)
	end
end

local function setVignette(intensity)
	local transparency = 1 - math.clamp(intensity, 0, 1)
	for _, strip in ipairs(strips) do
		strip.BackgroundTransparency = transparency
	end
end

-- Finding your own bus ------------------------------------------------------------------------

local myBus

local function findMyBus()
	local instances = workspace:FindFirstChild("RouteInstances")
	if not instances then
		return nil
	end
	for _, track in ipairs(instances:GetChildren()) do
		local buses = track:FindFirstChild("Buses")
		if buses then
			for _, bus in ipairs(buses:GetChildren()) do
				if bus:GetAttribute("OwnerUserId") == player.UserId then
					return bus
				end
			end
		end
	end
	return nil
end

-- Black and white on a wreck --------------------------------------------------------------------

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "BreakdownDrain"
colorCorrection.Saturation = 0
colorCorrection.Enabled = false
colorCorrection.Parent = Lighting

local drainToken = 0

local function drainColor()
	drainToken = drainToken + 1
	local myToken = drainToken

	colorCorrection.Saturation = 0
	colorCorrection.Enabled = true
	TweenService:Create(
		colorCorrection,
		TweenInfo.new(DESATURATE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Saturation = -1 }
	):Play()

	task.delay(DESATURATE_SECONDS + DESATURATE_HOLD, function()
		if drainToken ~= myToken then
			return -- a second breakdown already took over
		end
		local back = TweenService:Create(
			colorCorrection,
			TweenInfo.new(DESATURATE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Saturation = 0 }
		)
		back.Completed:Connect(function()
			if drainToken == myToken then
				colorCorrection.Enabled = false
			end
		end)
		back:Play()
	end)
end

-- Watch the bus for breakdowns --------------------------------------------------------------------

local breakdownConnection

local function watchBus(bus)
	if breakdownConnection then
		breakdownConnection:Disconnect()
		breakdownConnection = nil
	end
	if not bus then
		return
	end
	breakdownConnection = bus:GetAttributeChangedSignal("BrokenDown"):Connect(function()
		-- A tow-back sets BrokenDown too; that's a winch, not a wreck.
		if bus:GetAttribute("BrokenDown") and not bus:GetAttribute("Towing") then
			drainColor()
		end
	end)
end

task.spawn(function()
	while true do
		if myBus and not myBus:IsDescendantOf(workspace) then
			myBus = nil
			watchBus(nil)
			setVignette(0)
		end
		if not myBus then
			local bus = findMyBus()
			if bus then
				myBus = bus
				watchBus(bus)
			end
		end
		task.wait(0.5)
	end
end)

-- Per-frame: vignette + shake ------------------------------------------------------------------------

local shakeSeed = math.random() * 100

RunService:BindToRenderStep("BusStrainShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local bus = myBus
	if not bus or not bus.Parent then
		setVignette(0)
		return
	end

	local strain = bus:GetAttribute("Strain") or 0

	-- Vignette ramps in from WarnAt so the warning arrives before the
	-- breakdown does, giving you time to lift off.
	local warn = 0
	if strain > S.WarnAt then
		warn = (strain - S.WarnAt) / math.max(1 - S.WarnAt, 0.001)
	end
	setVignette(math.clamp(warn, 0, 1) * 0.75)

	if strain <= S.ShakeAt then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local shake = (strain - S.ShakeAt) / math.max(1 - S.ShakeAt, 0.001)
	shakeSeed = shakeSeed + dt * SHAKE_SPEED
	local offsetX = (math.noise(shakeSeed, 0) * 2) * SHAKE_MAX_POSITION * shake
	local offsetY = (math.noise(0, shakeSeed) * 2) * SHAKE_MAX_POSITION * shake
	local roll = (math.noise(shakeSeed, shakeSeed) * 2) * math.rad(SHAKE_MAX_ROTATION) * shake

	camera.CFrame = camera.CFrame * CFrame.new(offsetX, offsetY, 0) * CFrame.Angles(0, 0, roll)
end)
