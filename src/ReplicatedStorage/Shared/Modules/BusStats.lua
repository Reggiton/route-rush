--[[
	BusStats.lua

	The ONLY place that turns (chassis, upgrade levels, passengers) into
	effective driving stats. Used by the client drive controller, the
	server's collision/sanity monitor, and the garage stat preview, so
	all three always agree.
]]

local ReplicatedStorage = script.Parent.Parent.Parent
local UpgradeConfig = require(ReplicatedStorage.GarageSystem.Config.UpgradeConfig)
local DrivingConfig = require(script.Parent.Parent.Config.DrivingConfig)

local BusStats = {}

local PER_LEVEL = DrivingConfig.PerLevel
local LOAD = DrivingConfig.LoadPenalty

local function levelOf(levels, category)
	local level = (levels and levels[category]) or 0
	return math.clamp(level, UpgradeConfig.MinLevel, UpgradeConfig.MaxLevel)
end

-- Capacity only depends on chassis + Handles level.
function BusStats.Capacity(chassisId, levels)
	local tier = UpgradeConfig.GetChassis(chassisId) or UpgradeConfig.GetChassis(UpgradeConfig.DefaultChassisId)
	local handles = levelOf(levels, "Handles")
	return math.floor(tier.baseStats.capacity * (1 + handles * PER_LEVEL.Handles.capacity) + 0.5)
end

--[[
	Returns {
		topSpeed, accel, brakeDecel, grip, turnRate,  -- load-adjusted
		capacity, passengers, load (0..1),
		maxHealth, damageMult,
	}
]]
function BusStats.Compute(chassisId, levels, passengers)
	local tier = UpgradeConfig.GetChassis(chassisId) or UpgradeConfig.GetChassis(UpgradeConfig.DefaultChassisId)
	local base = tier.baseStats

	local engine = levelOf(levels, "Engine")
	local accel = levelOf(levels, "Accel")
	local brakes = levelOf(levels, "Brakes")
	local handles = levelOf(levels, "Handles")
	local health = levelOf(levels, "Health")

	local capacity = BusStats.Capacity(chassisId, levels)
	passengers = math.clamp(passengers or 0, 0, capacity)
	local load = capacity > 0 and passengers / capacity or 0

	-- Handles upgrades make a loaded bus corner more like an empty one.
	local handlingPenaltyScale = math.max(0, 1 - handles * PER_LEVEL.Handles.loadPenaltyReduction)

	return {
		topSpeed = base.topSpeed * (1 + engine * PER_LEVEL.Engine.topSpeed) * (1 - LOAD.topSpeed * load),
		accel = base.accel * (1 + accel * PER_LEVEL.Accel.accel) * (1 - LOAD.accel * load),
		brakeDecel = base.brakeDecel * (1 + brakes * PER_LEVEL.Brakes.brakeDecel) * (1 - LOAD.brakeDecel * load),
		grip = base.grip * (1 + handles * PER_LEVEL.Handles.grip) * (1 - LOAD.grip * load * handlingPenaltyScale),
		turnRate = base.turnRate * (1 - LOAD.turnRate * load * handlingPenaltyScale),

		capacity = capacity,
		passengers = passengers,
		load = load,

		maxHealth = math.floor(base.maxHealth * (1 + health * PER_LEVEL.Health.maxHealth)),
		damageMult = math.max(0.1, 1 - health * PER_LEVEL.Health.damageReduction),
	}
end

return BusStats
