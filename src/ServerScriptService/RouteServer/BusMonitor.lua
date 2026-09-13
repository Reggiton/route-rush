--[[
	BusMonitor.lua

	Server-side watcher for every released bus. Clients own their bus's
	physics, so the server judges what happened from replicated motion:

	  - Collisions: BOTH must be true to count as an impact --
	      1. a real slowdown, measured from replicated POSITIONS over a
	         short window (velocity readings from a client-owned bus are
	         too noisy to trust), bigger than the bus's own brakes could
	         cause, and
	      2. something solid (curb, obstacle, another bus) is actually
	         touching the bus's collision box right now.
	    Damage scales with the excess slowdown and the Health upgrade.
	    At 0 health the bus breaks down.
	  - Sanity: sustained over-speed, teleports, falling off the world,
	    or lying on its side -> server reclaims and resets it to the road.

	Other systems react through the callbacks passed to Start():
	  onImpact(player, damage), onBreakdown(player)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DrivingConfig = require(ReplicatedStorage.Shared.Config.DrivingConfig)
local BusStats = require(ReplicatedStorage.Shared.Modules.BusStats)
local BusSpawner = require(script.Parent.BusSpawner)
local TrackBuilder = require(script.Parent.TrackBuilder)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StopEvent = Remotes:WaitForChild("StopEvent")

local C = DrivingConfig.Collision

local BusMonitor = {}

local connection
local callbacks = {}
local states = {} -- [Player] = { bus, history = {{t, position}}, cooldownUntil, speedStrikes, flippedSince }
local accumulator = 0
local distances = {} -- [Player] = studs driven this race (kept after Stop for idle checks)

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z).Magnitude
end

local function resetBus(player, record, position)
	BusSpawner.ResetTo(player, TrackBuilder.NearestRoadCFrame(record.track, position))
	states[player] = nil
end

local function breakDown(player, bus, stats)
	bus:SetAttribute("Health", 0)
	bus:SetAttribute("BrokenDown", true)
	if callbacks.onBreakdown then
		callbacks.onBreakdown(player)
	end
	task.delay(C.BreakdownSeconds, function()
		if bus.Parent then
			bus:SetAttribute("Health", math.floor(stats.maxHealth * C.BreakdownRepairFraction))
			bus:SetAttribute("BrokenDown", false)
		end
	end)
end

-- The newest history entry at least `age` seconds old (or the oldest one).
local function entryAtAge(history, now, age)
	for i = #history, 1, -1 do
		if now - history[i].t >= age then
			return history[i]
		end
	end
	return history[1]
end

-- Returns the first solid thing touching the bus's sides/front/back/top, or nil.
-- The query box starts 1 stud above the Root's bottom so the road under a
-- hovering bus never counts.
local function findContact(player, bus, root)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { bus }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude

	local size = root.Size + Vector3.new(C.ContactMargin * 2, -1, C.ContactMargin * 2)
	local parts = workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0, 0.5, 0), size, params)
	for _, part in ipairs(parts) do
		if part.CanCollide and not (part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")) then
			return part
		end
	end
	return nil
end

local function sample(player, record, now)
	local bus = record.bus
	local root = bus.PrimaryPart
	if not root or not root.Parent then
		return
	end
	local position = root.Position

	local state = states[player]
	if not state or state.bus ~= bus then
		state = {
			bus = bus,
			history = {},
			cooldownUntil = now + C.ImpactCooldown,
			speedStrikes = 0,
			flippedSince = nil,
		}
		states[player] = state
	end

	local history = state.history
	local previous = history[#history]
	table.insert(history, { t = now, position = position })
	while #history > 2 and now - history[1].t > C.HistorySeconds do
		table.remove(history, 1)
	end
	if not previous then
		return
	end
	distances[player] = (distances[player] or 0) + horizontal(position - previous.position)

	local stats = BusStats.Compute(record.chassisId, record.levels, bus:GetAttribute("Passengers") or 0)

	-- Falling out of the world
	if position.Y < record.track.center.Y + C.FallResetY then
		resetBus(player, record, previous.position)
		return
	end

	-- Teleport check
	local elapsed = math.max(now - previous.t, 1e-3)
	if horizontal(position - previous.position) > stats.topSpeed * C.SpeedTolerance * elapsed + C.MaxTeleportStuds then
		resetBus(player, record, previous.position)
		return
	end

	-- On its side / roof
	if root.CFrame.UpVector.Y < 0.35 then
		state.flippedSince = state.flippedSince or now
		if now - state.flippedSince >= C.FlipResetSeconds then
			resetBus(player, record, position)
			return
		end
	else
		state.flippedSince = nil
	end

	-- Speeds from positions: the last RecentWindow seconds vs the BeforeWindow before it.
	local recentEntry = entryAtAge(history, now, C.RecentWindow)
	local recentSpan = now - recentEntry.t
	if recentSpan < C.RecentWindow * 0.5 then
		return
	end
	local recentSpeed = horizontal(position - recentEntry.position) / recentSpan

	-- Over-speed check
	if recentSpeed > stats.topSpeed * C.SpeedTolerance + 5 then
		state.speedStrikes = state.speedStrikes + 1
		if state.speedStrikes >= C.SpeedStrikesToReset then
			resetBus(player, record, position)
			return
		end
	else
		state.speedStrikes = 0
	end

	local beforeEntry = entryAtAge(history, recentEntry.t, C.BeforeWindow)
	local beforeSpan = recentEntry.t - beforeEntry.t
	if beforeSpan < C.BeforeWindow * 0.5 then
		return
	end
	local beforeSpeed = horizontal(recentEntry.position - beforeEntry.position) / beforeSpan

	-- Impact check
	if now < state.cooldownUntil or bus:GetAttribute("BrokenDown") or beforeSpeed < C.ImpactMinSpeed then
		return
	end
	local drop = beforeSpeed - recentSpeed
	local allowed = stats.brakeDecel * (recentSpan + beforeSpan) * 0.5 * C.BrakeSlack
	local excess = drop - allowed
	if excess < C.ImpactMinDrop then
		return
	end
	local hitPart = findContact(player, bus, root)
	if not hitPart then
		return
	end

	state.cooldownUntil = now + C.ImpactCooldown
	local damage = math.max(1, math.floor(excess * C.DamagePerStudPerSecond * stats.damageMult + 0.5))
	local health = math.max(0, (bus:GetAttribute("Health") or stats.maxHealth) - damage)
	bus:SetAttribute("Health", health)

	StopEvent:FireClient(player, { kind = "impact", damage = damage, what = hitPart.Name })
	if callbacks.onImpact then
		callbacks.onImpact(player, damage)
	end
	if health <= 0 then
		breakDown(player, bus, stats)
	end
end

function BusMonitor.Start(newCallbacks)
	BusMonitor.Stop()
	callbacks = newCallbacks or {}
	accumulator = 0
	distances = {}

	connection = RunService.Heartbeat:Connect(function(dt)
		accumulator = accumulator + dt
		if accumulator < C.SampleInterval then
			return
		end
		accumulator = 0

		local now = os.clock()
		for player, record in pairs(BusSpawner.All()) do
			if record.released and player.Parent == Players then
				sample(player, record, now)
			end
		end
	end)
end

function BusMonitor.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	states = {}
	callbacks = {}
end

-- Studs a player's bus has driven since the race started (0 if unknown).
function BusMonitor.GetDistance(player)
	return distances[player] or 0
end

return BusMonitor
