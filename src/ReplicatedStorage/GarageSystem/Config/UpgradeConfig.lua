--[[
	UpgradeConfig.lua

	Single source of truth for garage upgrade categories, levels, and
	chassis tiers. EDIT THIS FILE to add/remove a category, change the
	max level, or retune a chassis — no other script hardcodes any of
	this, so the GUI, the bus builder, the driving stats, and the server
	all update automatically.
]]

local UpgradeConfig = {}

-- Order controls the order rows are built in the GUI (top to bottom).
-- Matches the 5 categories in the Equipment List spreadsheet.
UpgradeConfig.Categories = {
	"Engine",
	"Accel",
	"Brakes",
	"Handles",
	"Health",
}

UpgradeConfig.MinLevel = 0 -- 0 = nothing installed (base bus)
UpgradeConfig.MaxLevel = 9 -- matches the 9-level equipment list

--[[
	Chassis tiers, in unlock order.

	requiredLevel   Player Level needed to buy it (GDD: chassis gated by Level)
	price           Cash price to buy it (0 = owned from the start)
	priceMultiplier Scales every skill-slot price on this chassis
	baseStats       Stats at upgrade level 0, empty bus. Units: studs, studs/s,
	                studs/s^2, radians/s. See BusStats.lua for how upgrades and
	                passenger load modify them.
	body            Placeholder block-bus shape used by BusBuilder.
]]
UpgradeConfig.ChassisTiers = {
	{
		id = "Tier1",
		displayName = "Beat-Up Local Minibus",
		requiredLevel = 1,
		price = 0,
		priceMultiplier = 1,
		baseStats = {
			capacity = 8,
			topSpeed = 70,
			accel = 22,
			brakeDecel = 45,
			grip = 60,
			turnRate = 1.6,
			maxHealth = 100,
		},
		body = {
			length = 18,
			width = 7,
			height = 7,
			decks = 1,
			axles = 2,
			color = Color3.fromRGB(230, 170, 40),
			stripeColor = Color3.fromRGB(40, 120, 60),
		},
	},
	{
		id = "Tier2",
		displayName = "Standard City Minibus",
		requiredLevel = 5,
		price = 5000,
		priceMultiplier = 2.5,
		baseStats = {
			capacity = 14,
			topSpeed = 76,
			accel = 19,
			brakeDecel = 42,
			grip = 55,
			turnRate = 1.35,
			maxHealth = 140,
		},
		body = {
			length = 24,
			width = 8,
			height = 8,
			decks = 1,
			axles = 2,
			color = Color3.fromRGB(40, 110, 190),
			stripeColor = Color3.fromRGB(240, 240, 240),
		},
	},
	{
		id = "Tier3",
		displayName = "Full-Size City Bus",
		requiredLevel = 12,
		price = 20000,
		priceMultiplier = 6,
		baseStats = {
			capacity = 24,
			topSpeed = 82,
			accel = 16,
			brakeDecel = 38,
			grip = 50,
			turnRate = 1.1,
			maxHealth = 200,
		},
		body = {
			length = 34,
			width = 9,
			height = 9,
			decks = 1,
			axles = 2,
			color = Color3.fromRGB(200, 50, 50),
			stripeColor = Color3.fromRGB(250, 210, 60),
		},
	},
	{
		id = "Tier4",
		displayName = "Articulated / Double-Decker",
		requiredLevel = 20,
		price = 60000,
		priceMultiplier = 15,
		baseStats = {
			capacity = 36,
			topSpeed = 80,
			accel = 13,
			brakeDecel = 34,
			grip = 44,
			turnRate = 0.95,
			maxHealth = 280,
		},
		body = {
			length = 40,
			width = 9,
			height = 7,
			decks = 2,
			axles = 3,
			color = Color3.fromRGB(30, 140, 110),
			stripeColor = Color3.fromRGB(245, 245, 245),
		},
	},
}

UpgradeConfig.DefaultChassisId = "Tier1"

-- Returns the tier table for an id, or nil.
function UpgradeConfig.GetChassis(chassisId)
	for index, tier in ipairs(UpgradeConfig.ChassisTiers) do
		if tier.id == chassisId then
			return tier, index
		end
	end
	return nil
end

return UpgradeConfig
