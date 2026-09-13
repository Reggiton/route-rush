--[[
	BusMonitor.lua

	Server-side watcher for every released bus. Clients own their bus's
	physics, so the server judges what happened from replicated motion:

	  - Collisions: a speed drop bigger than the bus's own brakes could
	    produce in one sample = an impact. Damage scales with the excess
	    and the Health upgrade. At 0 health the bus breaks down.
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

local C = DrivingConfig.Collision

local BusMonitor = {}

local connection
local callbacks = {}
local samples = {} -- [Player] = { bus, lastSpeed, lastPosition, lastTime, cooldownUntil, speedStrikes, flippedSince }
local accumulator = 0

local function resetBus(player, record, position)
	BusSpawner.ResetTo(player, TrackBuilder.NearestRoadCFrame(record.track, position))
	samples[player] = nil
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

local function sample(player, record, now)
	local bus = record.bus
	local root = bus.PrimaryPart
	if not root or not root.Parent then
		return
	end

	local stats = BusStats.Compute(record.chassisId, record.levels, bus:GetAttribute("Passengers") or 0)
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local position = root.Position

	local state = samples[player]
	if not state or state.bus ~= bus then
		samples[player] = {
			bus = bus,
			lastSpeed = speed,
			lastPosition = position,
			lastTime = now,
			cooldownUntil = 0,
			speedStrikes = 0,
			flippedSince = nil,
		}
		return
	end
	local elapsed = math.max(now - state.lastTime, 1e-3)

	-- Falling out of the world
	if position.Y < record.track.center.Y + C.FallResetY then
		resetBus(player, record, state.lastPosition)
		return
	end

	-- Teleport check
	local moved = Vector3.new(position.X - state.lastPosition.X, 0, position.Z - state.lastPosition.Z).Magnitude
	local expected = math.max(state.lastSpeed, speed, stats.topSpeed) * elapsed
	if moved > expected + C.MaxTeleportStuds then
		resetBus(player, record, state.lastPosition)
		return
	end

	-- Over-speed check
	if speed > stats.topSpeed * C.SpeedTolerance + 5 then
		state.speedStrikes = state.speedStrikes + 1
		if state.speedStrikes >= C.SpeedStrikesToReset then
			resetBus(player, record, position)
			return
		end
	else
		state.speedStrikes = 0
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

	-- Impact check
	local drop = state.lastSpeed - speed
	local allowed = stats.brakeDecel * elapsed * C.BrakeSlack
	local excess = drop - allowed
	if excess > C.ImpactMinDrop and now >= state.cooldownUntil and not bus:GetAttribute("BrokenDown") then
		state.cooldownUntil = now + C.ImpactCooldown
		local damage = math.floor(excess * C.DamagePerStudPerSecond * stats.damageMult + 0.5)
		local health = math.max(0, (bus:GetAttribute("Health") or stats.maxHealth) - damage)
		bus:SetAttribute("Health", health)
		if callbacks.onImpact then
			callbacks.onImpact(player, damage)
		end
		if health <= 0 then
			breakDown(player, bus, stats)
		end
	end

	state.lastSpeed = speed
	state.lastPosition = position
	state.lastTime = now
end

function BusMonitor.Start(newCallbacks)
	BusMonitor.Stop()
	callbacks = newCallbacks or {}
	accumulator = 0

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
	samples = {}
	callbacks = {}
end

return BusMonitor
