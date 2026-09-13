--[[
	RestorationConfig.lua

	Controls how a rusted bus gradually turns into the pristine one as
	its upgrades level up. EDIT THIS FILE to change which upgrade
	restores which part of the bus, and at which levels.

	Needs two models per tier (see README "Rusted → pristine buses"):
	  ReplicatedStorage.GarageAssets.Buses.Tier1.Rusted
	  ReplicatedStorage.GarageAssets.Buses.Tier1.Pristine

	HOW IT WORKS
	  Every part of both models is sorted into the FIRST region below whose
	  box contains the part's center. Box ranges are fractions of the bus:
	      x: 0 = left side   .. 1 = right side
	      y: 0 = bottom      .. 1 = top
	      z: 0 = front       .. 1 = back
	  (leave an axis out to mean the whole 0..1 range)

	  Each region is split into slices along its `sweep` direction, one
	  slice per entry in `levels`. When the region's upgrade `category`
	  reaches a slice's level, that slice swaps from rusted to pristine.
	      levels = { 1, 3, 5, 7, 9 }  -> 5 slices, at Lv1, Lv3, Lv5, Lv7, Lv9
	      levels = { 4, 9 }           -> front half at Lv4, back half at Lv9
	      levels = { 9 }              -> the whole region at Lv9
	      levels = {}                 -> the region always stays rusted

	  sweep: "FrontToBack" | "BackToFront" | "BottomToTop" | "TopToBottom"
	         | "LeftToRight" | "RightToLeft"

	  Hand-pick instead of using regions: set attributes on any part (or a
	  Model/Folder grouping parts) inside BOTH the rusted and pristine
	  models:
	      RestoreLevel    (number) the level that unrusts it
	      RestoreCategory (string) which upgrade, e.g. "Engine"
]]

local RestorationConfig = {}

-- Passengers pay more on a nicer bus:
-- fare x (1 + MaxFareBonus x fraction restored). 0.25 = +25% when fully pristine.
RestorationConfig.MaxFareBonus = 0.25

-- Hide the colored placeholder upgrade blocks on buses that use real
-- rusted/pristine models (the unrusting is the visual upgrade).
RestorationConfig.HideUpgradeBlocksOnRealModels = true

RestorationConfig.Regions = {
	{
		name = "Wheels & undercarriage",
		category = "Brakes",
		box = { y = { 0, 0.22 } },
		sweep = "FrontToBack",
		levels = { 1, 3, 5, 7, 9 },
	},
	{
		name = "Roof",
		category = "Handles",
		box = { y = { 0.8, 1 } },
		sweep = "FrontToBack",
		levels = { 1, 3, 5, 7, 9 },
	},
	{
		name = "Front & engine",
		category = "Engine",
		box = { z = { 0, 0.22 } },
		sweep = "BottomToTop",
		levels = { 1, 3, 5, 7, 9 },
	},
	{
		name = "Rear",
		category = "Accel",
		box = { z = { 0.78, 1 } },
		sweep = "BottomToTop",
		levels = { 1, 3, 5, 7, 9 },
	},
	{
		name = "Body panels",
		category = "Health",
		box = {}, -- everything not claimed above
		sweep = "FrontToBack",
		levels = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
	},
}

-- Optional per-tier replacements for Regions, e.g. a double-decker whose
-- roof should restore differently:
--   RestorationConfig.TierOverrides.Tier4 = { ...same shape as Regions... }
RestorationConfig.TierOverrides = {}

return RestorationConfig
