--[[
	Restoration.lua

	Pure math for the rusted → pristine system (no Roblox instances), shared
	by BusRestoration (visuals), PassengerService (fare bonus), and the
	garage UI. Rules live in GarageSystem/Config/RestorationConfig.lua.

	Coordinates are fractions of the bus: x 0 = left, y 0 = bottom, z 0 = front.
]]

local ReplicatedStorage = script.Parent.Parent.Parent
local RestorationConfig = require(ReplicatedStorage.GarageSystem.Config.RestorationConfig)

local Restoration = {}

local SWEEPS = {
	FrontToBack = function(_, _, z)
		return z
	end,
	BackToFront = function(_, _, z)
		return 1 - z
	end,
	BottomToTop = function(_, y)
		return y
	end,
	TopToBottom = function(_, y)
		return 1 - y
	end,
	LeftToRight = function(x)
		return x
	end,
	RightToLeft = function(x)
		return 1 - x
	end,
}

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

local function inRange(range, value)
	return range == nil or (value >= range[1] and value <= range[2])
end

-- Position of `value` inside `range`, as 0..1 (whole axis if no range).
local function withinRange(range, value)
	if not range then
		return value
	end
	local span = range[2] - range[1]
	if span <= 0 then
		return 0
	end
	return clamp01((value - range[1]) / span)
end

function Restoration.GetRegions(chassisId)
	return (chassisId and RestorationConfig.TierOverrides[chassisId]) or RestorationConfig.Regions
end

-- The first region whose box contains the point (last region as a fallback).
function Restoration.RegionFor(chassisId, x, y, z)
	x, y, z = clamp01(x), clamp01(y), clamp01(z)
	local regions = Restoration.GetRegions(chassisId)
	for _, region in ipairs(regions) do
		local box = region.box or {}
		if inRange(box.x, x) and inRange(box.y, y) and inRange(box.z, z) then
			return region
		end
	end
	return regions[#regions]
end

-- The upgrade level at which a point inside `region` unrusts.
function Restoration.ThresholdFor(region, x, y, z)
	local levels = region.levels or {}
	if #levels == 0 then
		return math.huge -- never restores
	end
	local box = region.box or {}
	local sweep = SWEEPS[region.sweep or "FrontToBack"] or SWEEPS.FrontToBack
	local t = clamp01(sweep(withinRange(box.x, clamp01(x)), withinRange(box.y, clamp01(y)), withinRange(box.z, clamp01(z))))
	local slice = math.min(math.floor(t * #levels), #levels - 1)
	return levels[slice + 1]
end

-- 0 (fully rusted) .. 1 (fully pristine), counting every slice of every region.
function Restoration.Fraction(chassisId, levels)
	local restored, total = 0, 0
	for _, region in ipairs(Restoration.GetRegions(chassisId)) do
		local current = (levels and levels[region.category]) or 0
		for _, threshold in ipairs(region.levels or {}) do
			total = total + 1
			if current >= threshold then
				restored = restored + 1
			end
		end
	end
	return total > 0 and restored / total or 0
end

function Restoration.FareMultiplier(chassisId, levels)
	return 1 + RestorationConfig.MaxFareBonus * Restoration.Fraction(chassisId, levels)
end

return Restoration
