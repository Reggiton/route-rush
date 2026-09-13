--[[
	GarageGuiBuilder.lua

	Builds the garage ScreenGui purely from UpgradeConfig.Categories,
	so adding or removing a category automatically adds/removes its
	row — no manual GUI editing needed.

	Returns the instances + a `rows` table the controller hooks
	callbacks onto.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("GarageSystem").Config.UpgradeConfig)

local GarageGuiBuilder = {}

local function makeButton(text, size, parent)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	return button
end

function GarageGuiBuilder.Build(playerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GarageGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = true
	screenGui.Parent = playerGui

	-- Button that opens the garage — sits on the normal HUD.
	local openButton = makeButton("Garage", UDim2.fromOffset(120, 44), screenGui)
	openButton.Position = UDim2.new(0, 20, 0, 20)
	openButton.Name = "OpenGarageButton"

	-- Main upgrade panel, hidden until the garage is opened.
	local panel = Instance.new("Frame")
	panel.Name = "GaragePanel"
	panel.Size = UDim2.fromOffset(360, 420)
	panel.Position = UDim2.new(1, -380, 0.5, -210)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	panel.Visible = false
	panel.Parent = screenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "Upgrades"
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = panel

	local closeButton = makeButton("X", UDim2.fromOffset(32, 32), panel)
	closeButton.Position = UDim2.new(1, -40, 0, 6)
	closeButton.Name = "CloseButton"

	local rowsHolder = Instance.new("Frame")
	rowsHolder.Name = "Rows"
	rowsHolder.Size = UDim2.new(1, -20, 1, -110)
	rowsHolder.Position = UDim2.new(0, 10, 0, 50)
	rowsHolder.BackgroundTransparency = 1
	rowsHolder.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = rowsHolder

	local rows = {} -- category -> { minus, plus, levelLabel }

	for i, category in ipairs(UpgradeConfig.Categories) do
		local row = Instance.new("Frame")
		row.Name = category .. "Row"
		row.Size = UDim2.new(1, 0, 0, 44)
		row.LayoutOrder = i
		row.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		row.Parent = rowsHolder

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.4, 0, 1, 0)
		label.Position = UDim2.new(0, 10, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = category
		label.Font = Enum.Font.Gotham
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = row

		local minus = makeButton("-", UDim2.fromOffset(36, 36), row)
		minus.Position = UDim2.new(0.45, 0, 0.5, -18)

		local levelLabel = Instance.new("TextLabel")
		levelLabel.Name = "LevelLabel"
		levelLabel.Size = UDim2.fromOffset(50, 36)
		levelLabel.Position = UDim2.new(0.45, 42, 0.5, -18)
		levelLabel.BackgroundTransparency = 1
		levelLabel.Text = "0 / " .. UpgradeConfig.MaxLevel
		levelLabel.Font = Enum.Font.GothamBold
		levelLabel.TextScaled = true
		levelLabel.TextColor3 = Color3.new(1, 1, 1)
		levelLabel.Parent = row

		local plus = makeButton("+", UDim2.fromOffset(36, 36), row)
		plus.Position = UDim2.new(0.45, 96, 0.5, -18)

		rows[category] = { minus = minus, plus = plus, levelLabel = levelLabel }
	end

	local confirmButton = makeButton("Confirm", UDim2.new(1, -20, 0, 44), panel)
	confirmButton.Position = UDim2.new(0, 10, 1, -54)
	confirmButton.Name = "ConfirmButton"
	confirmButton.BackgroundColor3 = Color3.fromRGB(50, 140, 70)

	return {
		screenGui = screenGui,
		openButton = openButton,
		panel = panel,
		closeButton = closeButton,
		confirmButton = confirmButton,
		rows = rows,
	}
end

return GarageGuiBuilder
