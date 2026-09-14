
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
local tier1 = UpgradeConfig.GetChassis("Tier1").baseStats
local base = BusStats.Compute("Tier1", levels(), 0)
eq("base top speed", base.topSpeed, tier1.topSpeed)
eq("base capacity", base.capacity, tier1.capacity)
eq("handles 9 doubles capacity", BusStats.Compute("Tier1", levels({ Handles = 9 }), 0).capacity, tier1.capacity * 2)
local full = BusStats.Compute("Tier1", levels(), tier1.capacity)
check("full load slower", math.abs(full.topSpeed - tier1.topSpeed * 0.85) < 1e-6, full.topSpeed)
check("full load grip penalty", math.abs(full.grip - tier1.grip * 0.6) < 1e-6, full.grip)
eq("passengers clamped", BusStats.Compute("Tier1", levels(), 999).passengers, tier1.capacity)
local handled = BusStats.Compute("Tier1", levels({ Handles = 9 }), tier1.capacity * 2)
check("handles softens load grip penalty", handled.grip / (tier1.grip * 1.36) > full.grip / tier1.grip, handled.grip)
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

-- Restoration (rusted -> pristine)
local Restoration = require(RS.Shared.Modules.Restoration)
local RestorationConfig = require(RS.GarageSystem.Config.RestorationConfig)
eq("fresh bus fully rusted", Restoration.Fraction("Tier1", levels()), 0)
eq("maxed bus fully restored", Restoration.Fraction("Tier1", allLevels(9)), 1)
eq("fresh fare multiplier", Restoration.FareMultiplier("Tier1", levels()), 1)
eq("maxed fare multiplier", Restoration.FareMultiplier("Tier1", allLevels(9)), 1 + RestorationConfig.MaxFareBonus)
local previousFraction = -1
for lv = 0, 9 do
	local fraction = Restoration.Fraction("Tier1", allLevels(lv))
	check("restoration never goes backwards at lv" .. lv, fraction >= previousFraction, fraction)
	previousFraction = fraction
end
check("one upgrade restores only part of the bus", Restoration.Fraction("Tier1", levels({ Engine = 9 })) < 1)
eq("low part -> wheels region", Restoration.RegionFor("Tier1", 0.5, 0.1, 0.5).category, "Brakes")
eq("high part -> roof region", Restoration.RegionFor("Tier1", 0.5, 0.95, 0.5).category, "Handles")
eq("front part -> engine region", Restoration.RegionFor("Tier1", 0.5, 0.5, 0.05).category, "Engine")
eq("rear part -> rear region", Restoration.RegionFor("Tier1", 0.5, 0.5, 0.95).category, "Accel")
eq("middle part -> body panels", Restoration.RegionFor("Tier1", 0.5, 0.5, 0.5).category, "Health")
eq("out-of-range point clamps", Restoration.RegionFor("Tier1", 2, -1, 0.5).category, "Brakes")
for _, region in ipairs(RestorationConfig.Regions) do
	local first = region.levels[1]
	local last = region.levels[#region.levels]
	local lowT = Restoration.ThresholdFor(region, 0, 0, 0)
	local highT = Restoration.ThresholdFor(region, 1, 1, 1)
	check(region.name .. " thresholds come from its levels list", (lowT == first or lowT == last) and (highT == first or highT == last))
end
eq("empty levels never restore", Restoration.ThresholdFor({ levels = {} }, 0.5, 0.5, 0.5), math.huge)
eq("single level region", Restoration.ThresholdFor({ levels = { 4 } }, 0.9, 0.9, 0.9), 4)
eq("two-slice sweep front", Restoration.ThresholdFor({ levels = { 2, 8 }, sweep = "FrontToBack" }, 0.5, 0.5, 0.1), 2)
eq("two-slice sweep back", Restoration.ThresholdFor({ levels = { 2, 8 }, sweep = "FrontToBack" }, 0.5, 0.5, 0.9), 8)

-- Boarding on the move
local Boarding = require(RS.Shared.Modules.Boarding)
local RouteConfig = require(RS.Shared.Config.RouteConfig)
local mph = Boarding.Studs -- mph -> studs/s, the unit the game measures in

eq("mph round-trips through studs", Boarding.Mph(Boarding.Studs(37)), 37)
eq("zero is zero mph", Boarding.Mph(0), 0)

-- The three tiers, checked at their exact thresholds (inclusive) and just over.
eq("30 mph picks up 2", Boarding.BoardCap(mph(30)), 2)
eq("just over 30 picks up nobody", Boarding.BoardCap(mph(30.1)), 0)
eq("20 mph picks up 4", Boarding.BoardCap(mph(20)), 4)
eq("25 mph is still the 30 tier", Boarding.BoardCap(mph(25)), 2)
eq("10 mph takes the whole crowd", Boarding.BoardCap(mph(10)), math.huge)
eq("a full stop takes the whole crowd", Boarding.BoardCap(0), math.huge)

check("cannot board way too fast", not Boarding.CanBoard(mph(60)))
check("can board at the top tier", Boarding.CanBoard(mph(30)))
check("drop-offs happen at 30", Boarding.CanDropOff(mph(30)))
check("no drop-offs over 30", not Boarding.CanDropOff(mph(31)))
eq("fastest boarding speed", Boarding.MaxBoardSpeed(), mph(30))

-- Slowing down must never cost you capacity.
local previousCap = -1
for speedMph = 40, 0, -1 do
	local cap = Boarding.BoardCap(mph(speedMph))
	check("slower never boards less (" .. speedMph .. " mph)", cap >= previousCap, cap)
	previousCap = cap
end

-- NextTier points at the least slowing down that actually buys you something.
eq("next tier from 30 is 20", Boarding.NextTier(mph(30)).speed, mph(20))
eq("next tier from 25 is 20", Boarding.NextTier(mph(25)).speed, mph(20))
eq("next tier from 20 is 10", Boarding.NextTier(mph(20)).speed, mph(10))
eq("next tier from 50 is 30", Boarding.NextTier(mph(50)).speed, mph(30))
check("no tier below the slowest", Boarding.NextTier(mph(5)) == nil)

local sorted = Boarding.TiersBySpeed()
eq("tiers sort slowest first", sorted[1].speed, mph(10))
eq("tiers sort fastest last", sorted[#sorted].speed, mph(30))
check("sorting does not mutate the config", RouteConfig.BoardTiers[1].speed == mph(30))

-- Tier thresholds are stored in studs/s, so retuning the speedometer's mph
-- conversion must not move them.
eq("tiers are stored in studs", RouteConfig.BoardTiers[1].speed, 45)
eq("drop-off threshold is stored in studs", RouteConfig.DropOffSpeed, 45)

-- Track layouts ------------------------------------------------------------------
local TrackLayouts = require(RS.Shared.Config.TrackLayouts)

-- A stand-in for Roblox's Random: the layouts only need NextNumber, and taking
-- it as an argument is what lets TrackBuilder keep drawing obstacles from the
-- same generator.
local function fakeRng(values)
	local index = 0
	return {
		NextNumber = function(_, low, high)
			index = index + 1
			local value = values[(index - 1) % #values + 1]
			if low and high then
				return low + value * (high - low)
			end
			return value
		end,
	}
end

eq("three layouts", #TrackLayouts.List, 3)
eq("default is the original loop", TrackLayouts.DefaultId, "cityLoop")
check("unknown id has no layout", TrackLayouts.Get("nope") == nil)
check("non-string id has no layout", TrackLayouts.Get(42) == nil)
check("unknown id resolves to the default", TrackLayouts.Resolve("nope").id == "cityLoop")
check("nil resolves to the default", TrackLayouts.Resolve(nil).id == "cityLoop")

local seenIds = {}
for _, layout in ipairs(TrackLayouts.List) do
	check("unique id: " .. layout.id, not seenIds[layout.id])
	seenIds[layout.id] = true
	check(layout.id .. " has a name", type(layout.name) == "string" and #layout.name > 0)
	check(layout.id .. " has a blurb", type(layout.blurb) == "string" and #layout.blurb > 0)
	check(layout.id .. " has a sane road width", layout.roadWidth >= 20 and layout.roadWidth <= 120)
	check(layout.id .. " declares curbs", type(layout.curbs) == "boolean")
	check(layout.id .. " has at least 2 grid columns", layout.gridColumns >= 2)

	local points = layout.points(fakeRng({ 0.25, 0.75 }))
	check(layout.id .. " returns points", #points >= 8)

	-- Closed ring: the last point must NOT repeat the first (TrackBuilder wraps
	-- with i % #points + 1), and no segment may be zero-length or laneCFrame's
	-- .Unit would be NaN.
	local first, last = points[1], points[#points]
	check(layout.id .. " does not duplicate the closing point", (first.x - last.x) ^ 2 + (first.z - last.z) ^ 2 > 1)

	local minSegment, total = math.huge, 0
	for i = 1, #points do
		local a, b = points[i], points[i % #points + 1]
		check(layout.id .. " point " .. i .. " is finite", a.x == a.x and a.z == a.z and a.y == a.y)
		local segment = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2)
		minSegment = math.min(minSegment, segment)
		total = total + segment
	end
	check(layout.id .. " has no zero-length segment", minSegment > 1, minSegment)
	check(layout.id .. " is a sensible length", total > 800 and total < 6000, total)
end

-- The default layout must draw exactly two numbers, in order, and keep the rest
-- of the generator untouched: TrackBuilder reuses the same rng for obstacles, so
-- a third draw here would move every obstacle on the live map.
local counted = 0
local countingRng = {
	NextNumber = function(_, low, high)
		counted = counted + 1
		return low and (low + 0.5 * (high - low)) or 0.5
	end,
}
TrackLayouts.Get("cityLoop").points(countingRng)
eq("city loop draws exactly two random numbers", counted, 2)

check("city loop is flat", (function()
	for _, point in ipairs(TrackLayouts.Get("cityLoop").points(fakeRng({ 0.3 }))) do
		if point.y ~= 0 then
			return false
		end
	end
	return true
end)())

check("hill circuit climbs and descends", (function()
	local low, high = math.huge, -math.huge
	for _, point in ipairs(TrackLayouts.Get("hills").points(fakeRng({ 0.3 }))) do
		low, high = math.min(low, point.y), math.max(high, point.y)
	end
	return high > 10 and low < -10 and high <= RouteConfig.HillAmplitude + 0.001
end)())

check("boulevard is wider than the city loop", TrackLayouts.Get("boulevard").roadWidth > TrackLayouts.Get("cityLoop").roadWidth)
check("boulevard has no curbs", not TrackLayouts.Get("boulevard").curbs)
check("city loop keeps its curbs", TrackLayouts.Get("cityLoop").curbs)

-- Map vote -----------------------------------------------------------------------
local MapVote = require(RS.Shared.Modules.MapVote)

local counts, total = MapVote.Tally({ a = "hills", b = "hills", c = "boulevard" })
eq("tally counts a winner", counts.hills, 2)
eq("tally counts a runner-up", counts.boulevard, 1)
eq("tally totals", total, 3)

local ignored, ignoredTotal = MapVote.Tally({ a = "nonsense", b = nil, c = 7 })
eq("unknown ids are ignored", ignoredTotal, 0)
check("unknown ids leave no counts", next(ignored) == nil)

eq("most votes wins", MapVote.Winner({ a = "hills", b = "hills", c = "boulevard" }), "hills")
eq("a single vote wins", MapVote.Winner({ a = "boulevard" }), "boulevard")
eq("nobody voting keeps the default", MapVote.Winner({}), "cityLoop")
eq("only junk votes keeps the default", MapVote.Winner({ a = "nonsense" }), "cityLoop")
-- Ties fall back through registry order, and the default sits first.
eq("a tie including the default takes the default", MapVote.Winner({ a = "cityLoop", b = "hills" }), "cityLoop")
eq("a tie without the default takes registry order", MapVote.Winner({ a = "hills", b = "boulevard" }), "boulevard")

-- The grid spread must still put two columns exactly where they have always been.
local function gridLateral(column, columns, width)
	return (column - (columns - 1) / 2) * width / columns
end
eq("two-column grid, left slot unchanged", gridLateral(0, 2, 28), -7)
eq("two-column grid, right slot unchanged", gridLateral(1, 2, 28), 7)
eq("four-column grid is centred", gridLateral(0, 4, 56) + gridLateral(3, 4, 56), 0)

-- Stops alternate kerbs. Mirrors TrackBuilder's rule so a change there without a
-- change here shows up; -1 is the left kerb, the side everything used to be on.
local function stopSide(index, alternating)
	return (alternating and index % 2 == 0) and 1 or -1
end
eq("stop 1 stays on the left", stopSide(1, true), -1)
eq("stop 2 crosses to the right", stopSide(2, true), 1)
eq("stop 3 is back on the left", stopSide(3, true), -1)
eq("stop 8 is on the right", stopSide(8, true), 1)
check("alternating uses both kerbs", (function()
	local left, right = 0, 0
	for index = 1, RouteConfig.StopCount do
		if stopSide(index, true) < 0 then
			left = left + 1
		else
			right = right + 1
		end
	end
	return left > 0 and right > 0 and left + right == RouteConfig.StopCount
end)())
check("turning it off puts every stop back on the left", (function()
	for index = 1, RouteConfig.StopCount do
		if stopSide(index, false) ~= -1 then
			return false
		end
	end
	return true
end)())

-- A bay must fit inside the lane it sits in, on every layout, or it would spill
-- across the centre line.
for _, layout in ipairs(TrackLayouts.List) do
	local laneCentre = layout.roadWidth / 4
	local bayHalf = RouteConfig.StopBayWidth / 2
	check(layout.id .. " bay stays inside its lane", bayHalf <= laneCentre, bayHalf .. " vs " .. laneCentre)
	check(layout.id .. " bay does not cross the centre line", laneCentre - bayHalf >= 0)
end

print(string.format("%d passed, %d failed", passes, failures))
if failures > 0 then
	error("tests failed")
end
