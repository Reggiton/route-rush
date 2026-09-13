--[[
	BusBuilder.lua

	Builds a bus model with one Attachment per upgrade category, so
	BusUpgradeApplier knows where to weld each upgrade's model.

	RIGHT NOW: the "bus" is a single placeholder block, per the brief.

	LATER: replace the body of BuildBaseBus() with code that clones a
	real bus asset for the given chassisId (e.g. from
	ReplicatedStorage.GarageAssets.Chassis[chassisId].BusTemplate).
	The only requirement is that the returned model still has:
	  - a PrimaryPart
	  - one Attachment per UpgradeConfig.Categories entry, parented to
	    the PrimaryPart (or wherever you want upgrades to weld to)
	Nothing else in the codebase needs to change.
]]

local UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)

local BusBuilder = {}

function BusBuilder.BuildBaseBus(chassisId)
	chassisId = chassisId or UpgradeConfig.DefaultChassisId

	local bus = Instance.new("Model")
	bus.Name = "Bus_" .. chassisId

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(8, 6, 20)
	body.Color = Color3.fromRGB(255, 200, 0)
	body.Anchored = true
	body.CanCollide = true
	body.Parent = bus
	bus.PrimaryPart = body

	-- One attachment per category, spaced along the roof so placeholder
	-- blocks don't overlap. Positions are purely cosmetic for now.
	for i, category in ipairs(UpgradeConfig.Categories) do
		local attachment = Instance.new("Attachment")
		attachment.Name = category
		attachment.Position = Vector3.new(0, 3.5, -8 + (i - 1) * 4)
		attachment.Parent = body
	end

	return bus
end

return BusBuilder
