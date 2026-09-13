--[[
	GarageGuiBuilder.lua

	Builds the garage ScreenGui from UIKit components. Upgrade rows come
	purely from UpgradeConfig.Categories, so adding or removing a category
	automatically adds/removes its row — no manual GUI editing needed.

	Only BUILDS instances. GarageController fills in text and wires
	callbacks using the handles returned here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("GarageSystem").Config.UpgradeConfig)

local UI = script.Parent.Parent:WaitForChild("UI")
local UIKit = require(UI:WaitForChild("UIKit"))
local Theme = UIKit.Theme

local GarageGuiBuilder = {}

local ROW_HEIGHT = 56
local ROW_GAP = 8
local PADDING = 18

function GarageGuiBuilder.Build(playerGui)
	local screenGui = UIKit.Screen("GarageGui", playerGui, 10)

	-- Button that opens the garage — sits under the profile card on the HUD.
	local openButton = UIKit.Button({
		Name = "OpenGarageButton",
		Text = "Garage",
		variant = "primary",
		Size = UDim2.fromOffset(132, 40),
		Position = UDim2.fromOffset(Theme.ScreenMargin, 86),
		Parent = screenGui,
	})
	UIKit.AutoScale(openButton)

	-- Main panel ----------------------------------------------------------------------------
	local rowCount = #UpgradeConfig.Categories
	local rowsTop = 144
	local rowsHeight = rowCount * ROW_HEIGHT + (rowCount - 1) * ROW_GAP
	local innerHeight = rowsTop + rowsHeight + 112

	local panel = UIKit.Panel({
		Name = "GaragePanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Theme.ScreenMargin, 0.5, 0),
		Size = UDim2.fromOffset(410, innerHeight + PADDING * 2),
		padding = PADDING,
		Visible = false,
		Parent = screenGui,
	})
	UIKit.AutoScale(panel)

	-- Header
	UIKit.Caption({ Text = "Garage", color = "Accent", Size = UDim2.new(1, -40, 0, 14), Parent = panel })
	local headerLabel = UIKit.Text({
		size = "Title",
		weight = "Heavy",
		Size = UDim2.new(1, -44, 0, 26),
		Position = UDim2.fromOffset(0, 16),
		Parent = panel,
	})
	local slotsLabel = UIKit.Text({
		size = "Small",
		color = "TextMuted",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 44),
		Parent = panel,
	})
	local closeButton = UIKit.Button({
		Name = "CloseButton",
		Text = "✕",
		variant = "ghost",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(34, 34),
		radius = Theme.Radius.Pill,
		Parent = panel,
	})

	-- Chassis selector
	local chassisCard = UIKit.Panel({
		Name = "ChassisRow",
		tone = "SurfaceAlt",
		stroke = false,
		Size = UDim2.new(1, 0, 0, 62),
		Position = UDim2.fromOffset(0, 72),
		radius = Theme.Radius.Medium,
		Parent = panel,
	})
	local chassisPrev = UIKit.Button({
		Name = "PrevChassis",
		Text = "‹",
		size = "Display",
		variant = "ghost",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(38, 46),
		Parent = chassisCard,
	})
	local chassisNext = UIKit.Button({
		Name = "NextChassis",
		Text = "›",
		size = "Display",
		variant = "ghost",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(38, 46),
		Parent = chassisCard,
	})
	local chassisName = UIKit.Text({
		size = "Body",
		weight = "Heavy",
		Size = UDim2.new(1, -110, 0, 22),
		Position = UDim2.fromOffset(55, 9),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = chassisCard,
	})
	local chassisSub = UIKit.Text({
		size = "Small",
		color = "TextMuted",
		Size = UDim2.new(1, -110, 0, 18),
		Position = UDim2.fromOffset(55, 33),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = chassisCard,
	})

	-- Upgrade rows
	local rowsHolder = UIKit.Frame({
		Name = "Rows",
		Size = UDim2.new(1, 0, 0, rowsHeight),
		Position = UDim2.fromOffset(0, rowsTop),
		Parent = panel,
	})
	UIKit.List(rowsHolder, { gap = ROW_GAP })

	local rows = {} -- category -> { minus, plus, levelLabel, statLabel, nameLabel }
	for i, category in ipairs(UpgradeConfig.Categories) do
		local row = UIKit.Panel({
			Name = category .. "Row",
			tone = "SurfaceAlt",
			stroke = false,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			LayoutOrder = i,
			radius = Theme.Radius.Medium,
			padding = { 8, 10, 8, 14 },
			Parent = rowsHolder,
		})

		local nameLabel = UIKit.Text({
			Text = category,
			weight = "Bold",
			Size = UDim2.new(1, -150, 0, 20),
			Parent = row,
		})
		local statLabel = UIKit.Text({
			size = "Small",
			color = "TextMuted",
			Size = UDim2.new(1, -150, 0, 18),
			Position = UDim2.fromOffset(0, 21),
			Parent = row,
		})

		local plus = UIKit.Button({
			Text = "+",
			size = "Title",
			variant = "secondary",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(36, 36),
			Parent = row,
		})
		local levelLabel = UIKit.Text({
			Name = "LevelLabel",
			Text = "0 / " .. UpgradeConfig.MaxLevel,
			size = "Body",
			weight = "Heavy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -40, 0.5, 0),
			Size = UDim2.fromOffset(60, 24),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = row,
		})
		local minus = UIKit.Button({
			Text = "−",
			size = "Title",
			variant = "secondary",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -104, 0.5, 0),
			Size = UDim2.fromOffset(36, 36),
			Parent = row,
		})

		rows[category] = {
			minus = minus,
			plus = plus,
			levelLabel = levelLabel,
			statLabel = statLabel,
			nameLabel = nameLabel,
		}
	end

	-- Footer
	local quoteLabel = UIKit.Text({
		size = "Small",
		color = "TextMuted",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -60),
		Size = UDim2.new(1, 0, 0, 36),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel,
	})
	local confirmButton = UIKit.Button({
		Name = "ConfirmButton",
		Text = "Confirm",
		variant = "primary",
		size = "Title",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 50),
		Parent = panel,
	})

	-- Error toast (floats just above the panel)
	local toast = UIKit.Text({
		Name = "Toast",
		weight = "Bold",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.Negative,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -PADDING - 10),
		Size = UDim2.new(1, 0, 0, 36),
		Visible = false,
		Parent = panel,
	})
	UIKit.Corner(toast, Theme.Radius.Pill)

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
		toast = toast,
	}
end

return GarageGuiBuilder
