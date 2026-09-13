--[[
	EconomyConfig.lua

	Every progression/economy number: cash, skill-slot pricing,
	reputation unlocks, XP/levels, and run rewards. First-pass balance —
	tune here only. The math that uses these lives in Progression.lua.
]]

local EconomyConfig = {}

EconomyConfig.StartingCash = 500

-- Skill slots ---------------------------------------------------------------
-- Price of the i-th filled slot on a chassis:
--   floor(BaseSlotCost * chassis.priceMultiplier * SlotCostGrowth^(i-1))
EconomyConfig.BaseSlotCost = 100
EconomyConfig.SlotCostGrowth = 1.08

-- Lowering an owned upgrade refunds this fraction of that slot's price.
EconomyConfig.RespecRefundRate = 0.6

-- Reputation unlocks slots in batches. Slots are shared across all
-- categories on a chassis (5 categories x 9 levels = 45 max).
EconomyConfig.BaseUnlockedSlots = 5
EconomyConfig.SlotsPerBatch = 5
-- Reputation needed for each additional batch, in order.
EconomyConfig.ReputationBatchThresholds = { 100, 300, 700, 1300, 2200, 3500, 5200, 7500 }

-- Player Level ----------------------------------------------------------------
-- XP needed to go from level L to L+1 = floor(XPBase * L^XPExponent)
EconomyConfig.XPBase = 100
EconomyConfig.XPExponent = 1.4
EconomyConfig.MaxPlayerLevel = 50

-- Run rewards -----------------------------------------------------------------
-- Fare for one delivered passenger = FareBase + FarePerStop * stopsTravelled
EconomyConfig.FareBase = 10
EconomyConfig.FarePerStop = 6
-- Extra fraction of the fare when delivered before its deadline.
EconomyConfig.OnTimeBonusRate = 0.25
-- Extra fraction of total fares for a run with zero collisions
-- (requires at least CleanRunMinDeliveries deliveries).
EconomyConfig.CleanRunBonusRate = 0.15
EconomyConfig.CleanRunMinDeliveries = 1

EconomyConfig.XPPerCash = 0.5
EconomyConfig.XPPerDelivery = 5
EconomyConfig.ParticipationXP = 20

-- Reputation per run = faresPerMinute * RepPerFarePerMinute
--   * (RepOnTimeFloor + (1 - RepOnTimeFloor) * onTimeFraction)
--   * (1 + min(bestCleanStreak * RepStreakBonusPerDelivery, RepStreakBonusCap))
EconomyConfig.RepPerFarePerMinute = 0.1
EconomyConfig.RepOnTimeFloor = 0.5
EconomyConfig.RepStreakBonusPerDelivery = 0.05
EconomyConfig.RepStreakBonusCap = 0.5

return EconomyConfig
