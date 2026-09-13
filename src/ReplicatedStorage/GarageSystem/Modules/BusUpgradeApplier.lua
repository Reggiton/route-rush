--[[
	BusUpgradeApplier.lua

	Given a bus model (from BusBuilder) and an upgrade-state table of
	the form { [category] = level }, updates how the bus looks:
	  - buses with rusted/pristine models: unrusts parts (BusRestoration)
	  - placeholder buses: attaches/detaches an upgrade block per category

	Used by BOTH the garage preview bus AND the live in-world bus, so
	upgraded buses look the same everywhere without duplicating logic.
]]

local UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)
local RestorationConfig = require(script.Parent.Parent.Config.RestorationConfig)
local UpgradeModelProvider = require(script.Parent.UpgradeModelProvider)
local BusRestoration = require(script.Parent.BusRestoration)

local BusUpgradeApplier = {}

-- Removes whatever model is currently installed for this category, if any.
local function clearCategory(bus, category)
	local old = bus:FindFirstChild(category .. "_Installed")
	if old then
		old:Destroy()
	end
end

-- Applies a single category's level, unloading whatever was there before.
function BusUpgradeApplier.ApplyCategory(bus, category, level)
	clearCategory(bus, category)

	if bus:GetAttribute("HasRestoration") and RestorationConfig.HideUpgradeBlocksOnRealModels then
		return -- the unrusting is the visual upgrade
	end

	local model = UpgradeModelProvider.GetModel(category, level, bus:GetAttribute("ChassisId"))
	if not model then
		return -- level 0: nothing to attach
	end
	model.Name = category .. "_Installed"

	local body = bus.PrimaryPart
	local attachment = body and body:FindFirstChild(category)
	if not attachment then
		warn("BusUpgradeApplier: bus is missing an attachment for category '" .. category .. "'")
		model:Destroy()
		return
	end

	model:PivotTo(attachment.WorldCFrame)
	model.Parent = bus

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
end

-- Applies a full upgrade-state table in one call.
function BusUpgradeApplier.ApplyState(bus, upgradeState)
	for _, category in ipairs(UpgradeConfig.Categories) do
		BusUpgradeApplier.ApplyCategory(bus, category, upgradeState[category] or 0)
	end
	BusRestoration.Apply(bus, upgradeState)
end

return BusUpgradeApplier
