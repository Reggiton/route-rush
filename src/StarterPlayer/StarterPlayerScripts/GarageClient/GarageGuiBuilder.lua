--[[
	GarageGuiBuilder.lua

<<<<<<< HEAD
	Builds the garage ScreenGui. Upgrade rows come purely from
	UpgradeConfig.Categories, so adding or removing a category
	automatically adds/removes its row — no manual GUI editing needed.

	Only BUILDS instances. GarageController fills in text and wires
	callbacks using the handles returned here.
=======
	Builds the garage ScreenGui purely from UpgradeConfig.Categories,
	so adding or removing a category automatically adds/removes its
	row — no manual GUI editing needed.

	Returns the instances + a `rows` table the controller hooks
	callbacks onto.
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("GarageSystem").Config.UpgradeConfig)

local GarageGuiBuilder = {}

<<<<<<< HEAD
local PANEL_BG = Color3.fromRGB(25, 25, 30)
local ROW_BG = Color3.fromRGB(35, 35, 40)
local BUTTON_BG = Color3.fromRGB(45, 45, 52)
local MUTED_TEXT = Color3.fromRGB(170, 170, 180)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

=======
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
local function makeButton(text, size, parent)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
<<<<<<< HEAD
	button.BackgroundColor3 = BUTTON_BG
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = true
	button.Parent = parent
	corner(button, 6)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = button
=======
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642

	return button
end

<<<<<<< HEAD
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

=======
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
function GarageGuiBuilder.Build(playerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GarageGui"
	screenGui.ResetOnSpawn = false
<<<<<<< HEAD
	screenGui.IgnoreGuiInset = false
=======
	screenGui.Enabled = true
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
	screenGui.Parent = playerGui

	-- Button that opens the garage — sits on the normal HUD.
	local openButton = makeButton("Garage", UDim2.fromOffset(120, 44), screenGui)
<<<<<<< HEAD
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
=======
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
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
	rowsHolder.BackgroundTransparency = 1
	rowsHolder.Parent = panel

	local listLayout = Instance.new("UIListLayout")
<<<<<<< HEAD
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = rowsHolder

	local rows = {} -- category -> { minus, plus, levelLabel, statLabel, nameLabel }
=======
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = rowsHolder

	local rows = {} -- category -> { minus, plus, levelLabel }
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642

	for i, category in ipairs(UpgradeConfig.Categories) do
		local row = Instance.new("Frame")
		row.Name = category .. "Row"
<<<<<<< HEAD
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

=======
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

>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
	return {
		screenGui = screenGui,
		openButton = openButton,
		panel = panel,
<<<<<<< HEAD
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
=======
		closeButton = closeButton,
		confirmButton = confirmButton,
		rows = rows,
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
	}
end

return GarageGuiBuilder
