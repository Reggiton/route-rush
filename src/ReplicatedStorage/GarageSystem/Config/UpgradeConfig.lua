--[[
	UpgradeConfig.lua

	Single source of truth for garage upgrade categories, levels, and
	chassis data. EDIT THIS FILE to add/remove a category, change the
	max level, or add a chassis tier — no other script hardcodes any
	of this, so the GUI, the bus builder, and the server all update
	automatically.
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

-- Chassis tiers. Only Tier1 exists for now (placeholder block bus).
-- Add Tier2/3/4 here later — nothing else needs to change as long as
-- BusBuilder knows how to build each id.
UpgradeConfig.ChassisTiers = {
	{
		id = "Tier1",
		displayName = "Beat-Up Local Minibus",
	},
}

UpgradeConfig.DefaultChassisId = "Tier1"

return UpgradeConfig
