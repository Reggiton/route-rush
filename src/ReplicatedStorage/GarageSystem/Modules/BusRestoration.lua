--[[
	BusRestoration.lua

	Visual side of rusted → pristine. A bus built from two models (see
	BusBuilder) carries BOTH the rusted and the pristine parts, overlaid.

	  Tag()   (once, at build time) records on every part which variant it
	          belongs to and the category/level that restores it.
	  Apply() (whenever levels change) shows the pristine part and hides
	          its rusted counterpart for everything that's been restored.

	Which parts restore when is decided by RestorationConfig.lua (via the
	pure Restoration module).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Restoration = require(ReplicatedStorage:WaitForChild("Shared").Modules.Restoration)

local BusRestoration = {}

local ATTR_VARIANT = "RR_Variant"
local ATTR_CATEGORY = "RR_Category"
local ATTR_LEVEL = "RR_Level"
local ATTR_BASE_TRANSPARENCY = "RR_BaseTransparency"
local ATTR_BASE_ENABLED = "RR_BaseEnabled"

local TOGGLEABLE = { "ParticleEmitter", "Light", "Beam", "Trail", "Fire", "Smoke", "Sparkles", "SurfaceGui", "BillboardGui" }

-- Looks for an attribute on the part, then on its ancestors up to (and including) `stopAt`.
local function inheritedAttribute(instance, stopAt, name)
	while instance do
		local value = instance:GetAttribute(name)
		if value ~= nil then
			return value
		end
		if instance == stopAt then
			return nil
		end
		instance = instance.Parent
	end
	return nil
end

--[[
	Tags every part of one variant model. Call before the parts are welded.
	boxMin / boxSize: the bus's bounding box in the same space as the parts.
]]
function BusRestoration.Tag(chassisId, model, variant, boxMin, boxSize)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local relative = part.Position - boxMin
			local x = boxSize.X > 0 and relative.X / boxSize.X or 0.5
			local y = boxSize.Y > 0 and relative.Y / boxSize.Y or 0.5
			local z = boxSize.Z > 0 and relative.Z / boxSize.Z or 0.5
			local region = Restoration.RegionFor(chassisId, x, y, z)

			local category = inheritedAttribute(part, model, "RestoreCategory")
			local level = inheritedAttribute(part, model, "RestoreLevel")
			if type(category) ~= "string" then
				category = region.category
			end
			if type(level) ~= "number" then
				level = Restoration.ThresholdFor(region, x, y, z)
			end

			part:SetAttribute(ATTR_VARIANT, variant)
			part:SetAttribute(ATTR_CATEGORY, category)
			part:SetAttribute(ATTR_LEVEL, level)
			part:SetAttribute(ATTR_BASE_TRANSPARENCY, part.Transparency)
		end
	end
end

local function setVisible(part, visible)
	local base = part:GetAttribute(ATTR_BASE_TRANSPARENCY) or 0
	part.Transparency = visible and base or 1

	for _, item in ipairs(part:GetDescendants()) do
		if item:IsA("Decal") then -- includes Texture
			if item:GetAttribute(ATTR_BASE_TRANSPARENCY) == nil then
				item:SetAttribute(ATTR_BASE_TRANSPARENCY, item.Transparency)
			end
			item.Transparency = visible and item:GetAttribute(ATTR_BASE_TRANSPARENCY) or 1
		else
			for _, className in ipairs(TOGGLEABLE) do
				if item:IsA(className) then
					if item:GetAttribute(ATTR_BASE_ENABLED) == nil then
						item:SetAttribute(ATTR_BASE_ENABLED, item.Enabled)
					end
					item.Enabled = visible and item:GetAttribute(ATTR_BASE_ENABLED)
					break
				end
			end
		end
	end
end

-- Shows/hides rusted vs pristine parts for an upgrade-state table.
function BusRestoration.Apply(bus, levels)
	if not bus:GetAttribute("HasRestoration") then
		return
	end
	levels = levels or {}

	for _, part in ipairs(bus:GetDescendants()) do
		if part:IsA("BasePart") then
			local variant = part:GetAttribute(ATTR_VARIANT)
			if variant then
				local restored = (levels[part:GetAttribute(ATTR_CATEGORY)] or 0) >= (part:GetAttribute(ATTR_LEVEL) or math.huge)
				setVisible(part, (variant == "Pristine") == restored)
			end
		end
	end

	bus:SetAttribute("Restored", Restoration.Fraction(bus:GetAttribute("ChassisId"), levels))
end

return BusRestoration
