--[[
	GarageGuiBuilder.lua

	Builds the garage ScreenGui. Upgrade rows come purely from
	UpgradeConfig.Categories, so adding or removing a category
	automatically adds/removes its row — no manual GUI editing needed.

	Only BUILDS instances. GarageController fills in text and wires
	callbacks using the handles returned here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("GarageSystem").Config.UpgradeConfig)

local GarageGuiBuilder = {}

local PANEL_BG = Color3.fromRGB(25, 25, 30)
local ROW_BG = Color3.fromRGB(35, 35, 40)
local BUTTON_BG = Color3.fromRGB(45, 45, 52)
local MUTED_TEXT = Color3.fromRGB(170, 170, 180)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeButton(text, size, parent)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.BackgroundColor3 = BUTTON_BG
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = true
	button.Parent = parent
	corner(button, 6)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = button

	return button
end

local function makeLabel(text, size, position, parent, props)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	for key, value in pairs(props or {}) do
		label[key] = value
	end
	label.Parent = parent
	return label
end

function GarageGuiBuilder.Build(playerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GarageGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.Parent = playerGui

	-- Button that opens the garage — sits on the normal HUD.
	local openButton = makeButton("Garage", UDim2.fromOffset(120, 44), screenGui)
	openButton.Position = UDim2.new(0, 20, 0, 70)
	openButton.Name = "OpenGarageButton"

	-- Main panel ----------------------------------------------------------------
	local rowCount = #UpgradeConfig.Categories
	local panelHeight = 250 + rowCount * 58

	local panel = Instance.new("Frame")
	panel.Name = "GaragePanel"
	panel.Size = UDim2.fromOffset(380, panelHeight)
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -20, 0.5, 0)
	panel.BackgroundColor3 = PANEL_BG
	panel.Visible = false
	panel.Parent = screenGui
	corner(panel, 10)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(380, panelHeight)
	sizeConstraint.Parent = panel

	local scale = Instance.new("UIScale")
	scale.Parent = panel

	makeLabel("Garage", UDim2.new(1, -60, 0, 30), UDim2.fromOffset(14, 8), panel, {
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local closeButton = makeButton("X", UDim2.fromOffset(32, 32), panel)
	closeButton.Position = UDim2.new(1, -42, 0, 8)
	closeButton.Name = "CloseButton"

	local headerLabel = makeLabel("", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 44), panel, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(120, 220, 140),
	})
	local slotsLabel = makeLabel("", UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 66), panel, {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED_TEXT,
	})

	-- Chassis selector ------------------------------------------------------------
	local chassisRow = Instance.new("Frame")
	chassisRow.Name = "ChassisRow"
	chassisRow.Size = UDim2.new(1, -20, 0, 54)
	chassisRow.Position = UDim2.fromOffset(10, 90)
	chassisRow.BackgroundColor3 = ROW_BG
	chassisRow.Parent = panel
	corner(chassisRow, 6)

	local chassisPrev = makeButton("<", UDim2.fromOffset(36, 42), chassisRow)
	chassisPrev.Position = UDim2.new(0, 6, 0.5, -21)
	chassisPrev.Name = "PrevChassis"

	local chassisNext = makeButton(">", UDim2.fromOffset(36, 42), chassisRow)
	chassisNext.Position = UDim2.new(1, -42, 0.5, -21)
	chassisNext.Name = "NextChassis"

	local chassisName = makeLabel("", UDim2.new(1, -100, 0, 24), UDim2.fromOffset(50, 5), chassisRow, {
		Font = Enum.Font.GothamBold,
	})
	local chassisSub = makeLabel("", UDim2.new(1, -100, 0, 16), UDim2.fromOffset(50, 32), chassisRow, {
		TextColor3 = MUTED_TEXT,
	})

	-- Upgrade rows ----------------------------------------------------------------------
	local rowsHolder = Instance.new("Frame")
	rowsHolder.Name = "Rows"
	rowsHolder.Size = UDim2.new(1, -20, 0, rowCount * 58)
	rowsHolder.Position = UDim2.fromOffset(10, 152)
	rowsHolder.BackgroundTransparency = 1
	rowsHolder.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = rowsHolder

	local rows = {} -- category -> { minus, plus, levelLabel, statLabel, nameLabel }

	for i, category in ipairs(UpgradeConfig.Categories) do
		local row = Instance.new("Frame")
		row.Name = category .. "Row"
		row.Size = UDim2.new(1, 0, 0, 52)
		row.LayoutOrder = i
		row.BackgroundColor3 = ROW_BG
		row.Parent = rowsHolder
		corner(row, 6)

		local nameLabel = makeLabel(category, UDim2.new(0.5, -10, 0, 22), UDim2.fromOffset(10, 4), row, {
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local statLabel = makeLabel("", UDim2.new(0.55, -10, 0, 16), UDim2.fromOffset(10, 30), row, {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED_TEXT,
		})

		local minus = makeButton("-", UDim2.fromOffset(36, 36), row)
		minus.AnchorPoint = Vector2.new(1, 0.5)
		minus.Position = UDim2.new(1, -104, 0.5, 0)

		local levelLabel = makeLabel("0 / " .. UpgradeConfig.MaxLevel, UDim2.fromOffset(56, 30), UDim2.new(1, -100, 0.5, -15), row, {
			Name = "LevelLabel",
			Font = Enum.Font.GothamBold,
		})

		local plus = makeButton("+", UDim2.fromOffset(36, 36), row)
		plus.AnchorPoint = Vector2.new(1, 0.5)
		plus.Position = UDim2.new(1, -6, 0.5, 0)

		rows[category] = {
			minus = minus,
			plus = plus,
			levelLabel = levelLabel,
			statLabel = statLabel,
			nameLabel = nameLabel,
		}
	end

	-- Footer --------------------------------------------------------------------------
	local quoteLabel = makeLabel("", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 1, -86), panel, {
		TextColor3 = MUTED_TEXT,
	})

	local confirmButton = makeButton("Confirm", UDim2.new(1, -20, 0, 44), panel)
	confirmButton.Position = UDim2.new(0, 10, 1, -58)
	confirmButton.Name = "ConfirmButton"
	confirmButton.BackgroundColor3 = Color3.fromRGB(50, 140, 70)

	local toast = makeLabel("", UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, -38), panel, {
		Name = "Toast",
		BackgroundTransparency = 0.1,
		BackgroundColor3 = Color3.fromRGB(150, 45, 45),
		Font = Enum.Font.GothamBold,
		Visible = false,
	})
	corner(toast, 6)

	return {
		screenGui = screenGui,
		openButton = openButton,
		panel = panel,
		panelScale = scale,
		closeButton = closeButton,
		headerLabel = headerLabel,
		slotsLabel = slotsLabel,
		chassisPrev = chassisPrev,
		chassisNext = chassisNext,
		chassisName = chassisName,
		chassisSub = chassisSub,
		rows = rows,
		quoteLabel = quoteLabel,
		confirmButton = confirmButton,
		toast = toast,
	}
end

return GarageGuiBuilder
