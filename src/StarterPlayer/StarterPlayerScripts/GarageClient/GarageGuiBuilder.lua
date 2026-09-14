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

local MUTED = Color3.fromRGB(170, 170, 180)

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

	-- Grey out when the controller disables the button.
	button:GetPropertyChangedSignal("Interactable"):Connect(function()
		button.TextTransparency = button.Interactable and 0 or 0.5
		button.BackgroundTransparency = button.Interactable and 0 or 0.4
	end)

	return button
end

local function makeLabel(text, size, position, parent, font)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = font or Enum.Font.Gotham
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
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
	local rowCount = #UpgradeConfig.Categories
	local rowsTop = 142
	local rowsHeight = rowCount * 44 + (rowCount - 1) * 8
	local panelHeight = rowsTop + rowsHeight + 96

	local panel = Instance.new("Frame")
	panel.Name = "GaragePanel"
	panel.Size = UDim2.fromOffset(360, panelHeight)
	panel.Position = UDim2.new(1, -380, 0.5, -panelHeight / 2)
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

	-- Cash / level / rep and slots
	local headerLabel = makeLabel("", UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 44), panel)
	headerLabel.TextColor3 = Color3.fromRGB(120, 220, 140)
	local slotsLabel = makeLabel("", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 66), panel)
	slotsLabel.TextColor3 = MUTED

	-- Chassis picker
	local chassisRow = Instance.new("Frame")
	chassisRow.Name = "ChassisRow"
	chassisRow.Size = UDim2.new(1, -20, 0, 48)
	chassisRow.Position = UDim2.new(0, 10, 0, 88)
	chassisRow.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	chassisRow.Parent = panel

	local chassisCorner = Instance.new("UICorner")
	chassisCorner.CornerRadius = UDim.new(0, 6)
	chassisCorner.Parent = chassisRow

	local chassisPrev = makeButton("<", UDim2.fromOffset(36, 36), chassisRow)
	chassisPrev.Position = UDim2.new(0, 6, 0.5, -18)
	chassisPrev.Name = "PrevChassis"

	local chassisNext = makeButton(">", UDim2.fromOffset(36, 36), chassisRow)
	chassisNext.Position = UDim2.new(1, -42, 0.5, -18)
	chassisNext.Name = "NextChassis"

	local chassisName = makeLabel("", UDim2.new(1, -96, 0, 22), UDim2.new(0, 48, 0, 4), chassisRow, Enum.Font.GothamBold)
	chassisName.TextXAlignment = Enum.TextXAlignment.Center
	local chassisSub = makeLabel("", UDim2.new(1, -96, 0, 16), UDim2.new(0, 48, 0, 27), chassisRow)
	chassisSub.TextXAlignment = Enum.TextXAlignment.Center
	chassisSub.TextColor3 = MUTED

	local rowsHolder = Instance.new("Frame")
	rowsHolder.Name = "Rows"
	rowsHolder.Size = UDim2.new(1, -20, 0, rowsHeight)
	rowsHolder.Position = UDim2.new(0, 10, 0, rowsTop)
	rowsHolder.BackgroundTransparency = 1
	rowsHolder.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = rowsHolder

	local rows = {} -- category -> { minus, plus, levelLabel, statLabel, nameLabel }

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

		local nameLabel = makeLabel(category, UDim2.new(0.45, -12, 0, 22), UDim2.new(0, 10, 0, 2), row)
		local statLabel = makeLabel("", UDim2.new(0.45, -12, 0, 16), UDim2.new(0, 10, 0, 25), row)
		statLabel.TextColor3 = MUTED

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

		rows[category] = {
			minus = minus,
			plus = plus,
			levelLabel = levelLabel,
			statLabel = statLabel,
			nameLabel = nameLabel,
		}
	end

	-- Cost / refund line
	local quoteLabel = makeLabel("", UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 1, -84), panel)
	quoteLabel.TextXAlignment = Enum.TextXAlignment.Center
	quoteLabel.TextColor3 = MUTED

	local confirmButton = makeButton("Confirm", UDim2.new(1, -20, 0, 44), panel)
	confirmButton.Position = UDim2.new(0, 10, 1, -54)
	confirmButton.Name = "ConfirmButton"
	confirmButton.BackgroundColor3 = Color3.fromRGB(50, 140, 70)

	-- Error message, just above the panel
	local toast = makeLabel("", UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, -40), panel, Enum.Font.GothamBold)
	toast.Name = "Toast"
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.BackgroundTransparency = 0.1
	toast.BackgroundColor3 = Color3.fromRGB(150, 45, 45)
	toast.Visible = false
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 6)
	toastCorner.Parent = toast

	return {
		screenGui = screenGui,
		openButton = openButton,
		panel = panel,
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
		confirmLabel = confirmButton, -- the button's own text
		navButtons = {},
		toast = toast,
	}
end

return GarageGuiBuilder
