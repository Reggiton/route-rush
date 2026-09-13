
local Progression = require(RS.Shared.Modules.Progression)
local BusStats = require(RS.Shared.Modules.BusStats)
local PowerScore = require(RS.Shared.Modules.PowerScore)
local UpgradeConfig = require(RS.GarageSystem.Config.UpgradeConfig)
local EconomyConfig = require(RS.Shared.Config.EconomyConfig)

local failures, passes = 0, 0
local function check(name, condition, detail)
	if condition then
		passes = passes + 1
	else
		failures = failures + 1
		print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
	end
end
local function eq(name, actual, expected)
	check(name, actual == expected, "got " .. tostring(actual) .. ", expected " .. tostring(expected))
end

local function levels(t)
	local l = {}
	for _, c in ipairs(UpgradeConfig.Categories) do
		l[c] = (t and t[c]) or 0
	end
	return l
end
local function allLevels(n)
	local l = {}
	for _, c in ipairs(UpgradeConfig.Categories) do
		l[c] = n
	end
	return l
end

-- Slot prices
eq("slot 1 price", Progression.SlotCost("Tier1", 1), 100)
eq("slot 2 price", Progression.SlotCost("Tier1", 2), 108)
eq("tier2 multiplier", Progression.SlotCost("Tier2", 1), 250)
eq("max slots", Progression.MaxSlotsPerChassis, 45)

-- Quotes
local buy3 = Progression.QuoteChange("Tier1", levels(), levels({ Engine = 3 }))
eq("buy3 cost", buy3.cost, 100 + 108 + 116)
eq("buy3 refund", buy3.refund, 0)
eq("buy3 slotsAfter", buy3.slotsAfter, 3)

local sell2 = Progression.QuoteChange("Tier1", levels({ Engine = 3 }), levels({ Engine = 1 }))
eq("sell2 refund", sell2.refund, math.floor((108 + 116) * 0.6))
eq("sell2 cost", sell2.cost, 0)
eq("sell2 net", sell2.net, -math.floor((108 + 116) * 0.6))
eq("sell2 slotsAfter", sell2.slotsAfter, 1)

local respec = Progression.QuoteChange("Tier1", levels({ Engine = 2 }), levels({ Engine = 1, Accel = 1 }))
eq("respec removed", respec.removed, 1)
eq("respec added", respec.added, 1)
eq("respec cost", respec.cost, 108)
eq("respec refund = 60%", respec.refund, math.floor(108 * EconomyConfig.RespecRefundRate))
eq("respec slots unchanged", respec.slotsAfter, 2)

-- Buying then selling any amount always refunds exactly floor(60%) of what was paid.
for n = 1, 45 do
	local full = allLevels(9)
	local target = levels()
	local remaining = n
	for _, c in ipairs(UpgradeConfig.Categories) do
		local take = math.min(9, remaining)
		target[c] = take
		remaining = remaining - take
	end
	local paid = Progression.QuoteChange("Tier3", levels(), target).cost
	local back = Progression.QuoteChange("Tier3", target, levels()).refund
	check("round trip refund " .. n, back == math.floor(paid * 0.6), back .. " vs " .. paid)
end
eq("no-op quote", Progression.QuoteChange("Tier1", allLevels(4), allLevels(4)).net, 0)

-- Reputation slots
eq("slots at 0 rep", Progression.UnlockedSlots(0), 5)
eq("slots at 100 rep", Progression.UnlockedSlots(100), 10)
eq("slots at 99 rep", Progression.UnlockedSlots(99), 5)
eq("slots maxed", Progression.UnlockedSlots(1e9), 45)
eq("next unlock at 0", Progression.NextUnlockReputation(0), 100)
eq("next unlock maxed", Progression.NextUnlockReputation(1e9), nil)

-- Levels
eq("xp to lv2", Progression.XPToNextLevel(1), 100)
eq("level at 0 xp", (Progression.LevelFromXP(0)), 1)
eq("level at 99 xp", (Progression.LevelFromXP(99)), 1)
eq("level at 100 xp", (Progression.LevelFromXP(100)), 2)
local lvl, into, nextNeeded = Progression.LevelFromXP(150)
eq("xp into level", into, 50)
eq("xp for next", nextNeeded, Progression.XPToNextLevel(2))
check("level capped", (Progression.LevelFromXP(1e12)) == EconomyConfig.MaxPlayerLevel)

-- Fares & payout
eq("fare 3 stops", Progression.Fare(3), 28)
eq("on-time bonus", Progression.OnTimeBonus(28), 7)
local payout = Progression.RunPayout({
	fares = 1000,
	deliveries = 20,
	onTimeDeliveries = 20,
	collisions = 0,
	bestCleanStreak = 20,
	durationSeconds = 300,
})
eq("clean bonus", payout.cleanBonus, 150)
eq("payout cash", payout.cash, 1150)
eq("payout xp", payout.xp, 20 + 575 + 100)
eq("payout rep", payout.reputation, 30)
eq("fares per minute", payout.faresPerMinute, 200)
local dirty = Progression.RunPayout({ fares = 1000, deliveries = 20, onTimeDeliveries = 0, collisions = 2, bestCleanStreak = 0, durationSeconds = 300 })
eq("no clean bonus with collisions", dirty.cleanBonus, 0)
eq("rep halves with no on-time", dirty.reputation, 10)
eq("empty run rep", Progression.RunPayout({ durationSeconds = 300 }).reputation, 0)

-- Bus stats
local base = BusStats.Compute("Tier1", levels(), 0)
eq("base top speed", base.topSpeed, 70)
eq("base capacity", base.capacity, 8)
eq("handles 9 doubles capacity", BusStats.Compute("Tier1", levels({ Handles = 9 }), 0).capacity, 16)
local full = BusStats.Compute("Tier1", levels(), 8)
check("full load slower", math.abs(full.topSpeed - 70 * 0.85) < 1e-6, full.topSpeed)
check("full load grip penalty", math.abs(full.grip - 60 * 0.6) < 1e-6, full.grip)
eq("passengers clamped", BusStats.Compute("Tier1", levels(), 999).passengers, 8)
local handled = BusStats.Compute("Tier1", levels({ Handles = 9 }), 16)
check("handles softens load grip penalty", handled.grip / (60 * 1.36) > full.grip / 60, handled.grip)
check("health reduces damage", BusStats.Compute("Tier1", levels({ Health = 9 }), 0).damageMult < 1)
eq("unknown chassis falls back", BusStats.Compute("Nope", levels(), 0).capacity, 8)

for _, tier in ipairs(UpgradeConfig.ChassisTiers) do
	for _, lv in ipairs({ 0, 9 }) do
		local s = BusStats.Compute(tier.id, allLevels(lv), 999)
		for _, key in ipairs({ "topSpeed", "accel", "brakeDecel", "grip", "turnRate", "maxHealth", "damageMult" }) do
			check(tier.id .. " lv" .. lv .. " " .. key .. " positive", s[key] > 0, s[key])
		end
	end
	local previous = -1
	for lv = 0, 9 do
		local s = BusStats.Compute(tier.id, levels({ Engine = lv }), 0)
		check(tier.id .. " engine monotonic " .. lv, s.topSpeed > previous)
		previous = s.topSpeed
	end
end

-- Power score & brackets
eq("fresh tier1 score", PowerScore.Driving("Tier1", levels()), 0)
eq("fresh bracket", PowerScore.Bracket(0), 1)
eq("maxed tier1 score", PowerScore.Driving("Tier1", allLevels(9)), 45.9)
eq("maxed tier1 bracket", PowerScore.Bracket(PowerScore.Driving("Tier1", allLevels(9))), 2)
eq("fresh tier2 bracket", PowerScore.Bracket(PowerScore.Driving("Tier2", levels())), 1)

-- Upgrade catalog (generated from the spreadsheet)
local UpgradeCatalog = require(RS.GarageSystem.Config.UpgradeCatalog)
local catalogCount = 0
for _, tier in ipairs(UpgradeConfig.ChassisTiers) do
	for _, category in ipairs(UpgradeConfig.Categories) do
		for lv = 1, UpgradeConfig.MaxLevel do
			local entry = UpgradeCatalog.Get(tier.id, category, lv)
			check("catalog " .. tier.id .. " " .. category .. " " .. lv, entry ~= nil and #entry.name > 0)
			if entry then
				catalogCount = catalogCount + 1
			end
		end
	end
end
eq("catalog has all 180 upgrades", catalogCount, 180)
eq("catalog sample name", UpgradeCatalog.Get("Tier1", "Engine", 4).name, "Bazaar Turbo Kit")
eq("catalog level 0 is nil", UpgradeCatalog.Get("Tier1", "Engine", 0), nil)

print(string.format("%d passed, %d failed", passes, failures))
if failures > 0 then
	error("tests failed")
end
