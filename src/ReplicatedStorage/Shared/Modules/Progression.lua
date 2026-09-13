--[[
	Progression.lua

	Pure progression/economy math (no Roblox services), shared by the
	server (authoritative) and the client (previews). Every number comes
	from EconomyConfig / UpgradeConfig.

	Skill slots: every upgrade level on a chassis fills one slot. Slot
	prices depend only on the slot's index on that chassis, so selling
	the top N slots and re-buying them is exactly symmetric — which is
	what makes "refund = 60% of what you paid" hold without storing any
	purchase history.
]]

local ReplicatedStorage = script.Parent.Parent.Parent
local UpgradeConfig = require(ReplicatedStorage.GarageSystem.Config.UpgradeConfig)
local EconomyConfig = require(script.Parent.Parent.Config.EconomyConfig)

local Progression = {}

Progression.MaxSlotsPerChassis = #UpgradeConfig.Categories * UpgradeConfig.MaxLevel

-- Levels ----------------------------------------------------------------------

-- XP required to advance from `level` to `level + 1`.
function Progression.XPToNextLevel(level)
	return math.floor(EconomyConfig.XPBase * level ^ EconomyConfig.XPExponent)
end

-- Returns level, xpIntoLevel, xpNeededForNext (nil at max level).
function Progression.LevelFromXP(xp)
	xp = math.max(0, xp or 0)
	local level = 1
	while level < EconomyConfig.MaxPlayerLevel do
		local needed = Progression.XPToNextLevel(level)
		if xp < needed then
			return level, xp, needed
		end
		xp = xp - needed
		level = level + 1
	end
	return level, 0, nil
end

-- Slots ----------------------------------------------------------------------------

function Progression.UnlockedSlots(reputation)
	reputation = reputation or 0
	local slots = EconomyConfig.BaseUnlockedSlots
	for _, threshold in ipairs(EconomyConfig.ReputationBatchThresholds) do
		if reputation >= threshold then
			slots = slots + EconomyConfig.SlotsPerBatch
		end
	end
	return math.min(slots, Progression.MaxSlotsPerChassis)
end

-- Reputation needed for the next slot batch, or nil if all are unlocked.
function Progression.NextUnlockReputation(reputation)
	reputation = reputation or 0
	if Progression.UnlockedSlots(reputation) >= Progression.MaxSlotsPerChassis then
		return nil
	end
	for _, threshold in ipairs(EconomyConfig.ReputationBatchThresholds) do
		if reputation < threshold then
			return threshold
		end
	end
	return nil
end

function Progression.SlotsUsed(levels)
	local total = 0
	for _, category in ipairs(UpgradeConfig.Categories) do
		total = total + ((levels and levels[category]) or 0)
	end
	return total
end

-- Price of the i-th filled slot (1-based) on a chassis.
function Progression.SlotCost(chassisId, slotIndex)
	local tier = UpgradeConfig.GetChassis(chassisId)
	local multiplier = tier and tier.priceMultiplier or 1
	return math.floor(EconomyConfig.BaseSlotCost * multiplier * EconomyConfig.SlotCostGrowth ^ (slotIndex - 1))
end

local function sumSlotCosts(chassisId, fromIndex, toIndex)
	local total = 0
	for i = fromIndex, toIndex do
		total = total + Progression.SlotCost(chassisId, i)
	end
	return total
end

--[[
	Quote for changing a chassis from `fromLevels` to `toLevels`.
	Removed levels are sold first (from the top slot down, refunded at
	RespecRefundRate), then added levels are bought from that point.
	Returns { cost, refund, net, added, removed, slotsBefore, slotsAfter }.
	net > 0 means the player pays; net < 0 means they receive cash.
]]
function Progression.QuoteChange(chassisId, fromLevels, toLevels)
	local added, removed = 0, 0
	for _, category in ipairs(UpgradeConfig.Categories) do
		local from = (fromLevels and fromLevels[category]) or 0
		local to = (toLevels and toLevels[category]) or 0
		if to > from then
			added = added + (to - from)
		elseif from > to then
			removed = removed + (from - to)
		end
	end

	local slotsBefore = Progression.SlotsUsed(fromLevels)
	local base = slotsBefore - removed

	local refund = math.floor(sumSlotCosts(chassisId, base + 1, slotsBefore) * EconomyConfig.RespecRefundRate)
	local cost = sumSlotCosts(chassisId, base + 1, base + added)

	return {
		cost = cost,
		refund = refund,
		net = cost - refund,
		added = added,
		removed = removed,
		slotsBefore = slotsBefore,
		slotsAfter = base + added,
	}
end

-- Run rewards -----------------------------------------------------------------------

function Progression.Fare(stopsTravelled)
	return EconomyConfig.FareBase + EconomyConfig.FarePerStop * math.max(0, stopsTravelled)
end

function Progression.OnTimeBonus(fare)
	return math.floor(fare * EconomyConfig.OnTimeBonusRate)
end

--[[
	runStats = {
		fares,             -- cash from deliveries, on-time bonuses included
		deliveries,        -- passengers delivered
		onTimeDeliveries,
		collisions,
		bestCleanStreak,   -- most deliveries in a row without a collision
		durationSeconds,
	}
]]
function Progression.ReputationForRun(runStats)
	local minutes = math.max((runStats.durationSeconds or 0) / 60, 1 / 60)
	local faresPerMinute = (runStats.fares or 0) / minutes
	local deliveries = runStats.deliveries or 0
	local onTimeFraction = deliveries > 0 and (runStats.onTimeDeliveries or 0) / deliveries or 0

	local onTimeFactor = EconomyConfig.RepOnTimeFloor + (1 - EconomyConfig.RepOnTimeFloor) * onTimeFraction
	local streakFactor = 1
		+ math.min((runStats.bestCleanStreak or 0) * EconomyConfig.RepStreakBonusPerDelivery, EconomyConfig.RepStreakBonusCap)

	return math.floor(faresPerMinute * EconomyConfig.RepPerFarePerMinute * onTimeFactor * streakFactor)
end

-- Returns { fares, cleanBonus, cash, xp, reputation, faresPerMinute }.
function Progression.RunPayout(runStats)
	local fares = runStats.fares or 0
	local deliveries = runStats.deliveries or 0

	local cleanBonus = 0
	if (runStats.collisions or 0) == 0 and deliveries >= EconomyConfig.CleanRunMinDeliveries then
		cleanBonus = math.floor(fares * EconomyConfig.CleanRunBonusRate)
	end

	local cash = fares + cleanBonus
	local xp = EconomyConfig.ParticipationXP
		+ math.floor(cash * EconomyConfig.XPPerCash)
		+ deliveries * EconomyConfig.XPPerDelivery

	local minutes = math.max((runStats.durationSeconds or 0) / 60, 1 / 60)

	return {
		fares = fares,
		cleanBonus = cleanBonus,
		cash = cash,
		xp = xp,
		reputation = Progression.ReputationForRun(runStats),
		faresPerMinute = math.floor(fares / minutes),
	}
end

return Progression
