--[[
	UpgradeModelProvider.lua

	The ONLY place that decides what model represents a given
	(category, level) upgrade. Everything else just calls GetModel().

	RIGHT NOW: generates a placeholder colored block with a floating
	label showing the upgrade's name from UpgradeCatalog (generated from
	the Equipment List spreadsheet), since we don't have real assets yet.

	LATER: when real models exist (e.g. under
	ReplicatedStorage.GarageAssets.Upgrades[chassisId][category][level]),
	replace the body of GetModel() with a :Clone() of the real asset.
	Nothing outside this file needs to change. The "visual" text in
	UpgradeCatalog describes what each model should look like.
]]

local UpgradeCatalog = require(script.Parent.Parent.Config.UpgradeCatalog)

local UpgradeModelProvider = {}

local CATEGORY_COLORS = {
	Engine = Color3.fromRGB(200, 60, 60),
	Accel = Color3.fromRGB(60, 140, 200),
	Brakes = Color3.fromRGB(230, 200, 40),
	Handles = Color3.fromRGB(80, 200, 100),
	Health = Color3.fromRGB(160, 160, 160),
}

-- Returns a Model for this upgrade, or nil if level is 0 (nothing installed).
-- The returned model always has PrimaryPart set.
function UpgradeModelProvider.GetModel(category, level, chassisId)
	if level <= 0 then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = string.format("%s_Lv%d", category, level)

	local part = Instance.new("Part")
	part.Name = "PlaceholderBlock"
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Size = Vector3.new(1.5, 1.5, 1.5) + Vector3.new(1, 1, 1) * (level * 0.15)
	part.Color = CATEGORY_COLORS[category] or Color3.fromRGB(255, 255, 255)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model

	local entry = chassisId and UpgradeCatalog.Get(chassisId, category, level)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(190, 30)
	billboard.StudsOffset = Vector3.new(0, 1.4, 0)
	billboard.MaxDistance = 80
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = entry and string.format("Lv%d · %s", level, entry.name) or string.format("%s Lv%d", category, level)
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Font = Enum.Font.GothamBold
	text.Parent = billboard

	model.PrimaryPart = part
	return model
end

return UpgradeModelProvider
