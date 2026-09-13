--[[
	GarageGuiBuilder.lua

	Builds the garage screen from UIKit components. Upgrade rows come purely
	from UpgradeConfig.Categories, so adding or removing a category
	automatically adds/removes its row — no manual GUI editing needed.

	Layout (each piece is a scaled dock):
	  top-left      GARAGE button (closed) / screen title (open)
	  right         taped upgrade panel with paint CONFIRM button
	  bottom-right  "BETTER BUSES. FARTHER ROADS." tagline (open)

	Only BUILDS instances. GarageController fills in text and wires
	callbacks using the handles returned here. `panel` is the whole open
	garage screen (title + upgrade panel + tagline) so toggling its
	Visible opens/closes everything.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("GarageSystem").Config.UpgradeConfig)

local UI = script.Parent.Parent:WaitForChild("UI")
local UIKit = require(UI:WaitForChild("UIKit"))
local Theme = UIKit.Theme

local GarageGuiBuilder = {}

local M = Theme.ScreenMargin
local ROW_HEIGHT = 54
local ROW_GAP = 7
local PADDING = 18
local CARD_WIDTH = 400

function GarageGuiBuilder.Build(playerGui)
	local screenGui = UIKit.Screen("GarageGui", playerGui, 10)

	-- GARAGE button (top-left, under the Roblox menu buttons) ---------------------------------
	local buttonDock = UIKit.Dock({
		Name = "OpenDock",
		Position = UDim2.fromOffset(M, 64),
		Size = UDim2.fromOffset(170, 56),
		Parent = screenGui,
	})
	local openButton = UIKit.Button({
		Name = "OpenGarageButton",
		Text = "Garage",
		variant = "primary",
		size = 24,
		Size = UDim2.fromOffset(150, 48),
		Parent = buttonDock,
	})

	-- The open garage screen ---------------------------------------------------------------------
	local screen = UIKit.Frame({ Name = "GarageScreen", Size = UDim2.fromScale(1, 1), Visible = false, Parent = screenGui })

	-- Screen title (top-left)
	do
		local dock = UIKit.Dock({ Name = "TitleDock", Position = UDim2.fromOffset(M, 60), Size = UDim2.fromOffset(460, 96), Parent = screen })
		local icon = UIKit.Icon({ icon = "Garage", Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, 8), Parent = dock })
		local textX = icon and 76 or 0
		UIKit.Brush({
			Text = "Garage",
			size = 48,
			tilt = -3,
			Size = UDim2.new(1, -textX, 0, 56),
			Position = UDim2.fromOffset(textX, 0),
			Parent = dock,
		})
		UIKit.Brush({
			Text = "The only place that feels like home.",
			size = 16,
			color = "TextMuted",
			tilt = -3,
			Size = UDim2.new(1, -textX, 0, 22),
			Position = UDim2.fromOffset(textX + 4, 58),
			Parent = dock,
		})
	end

	-- Tagline (bottom-right)
	do
		local dock = UIKit.Dock({
			Name = "TaglineDock",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -M, 1, -M),
			Size = UDim2.fromOffset(360, 56),
			Parent = screen,
		})
		local strip = UIKit.Panel({
			Size = UDim2.fromScale(1, 1),
			Rotation = -3,
			padding = { 0, 16, 0, 16 },
			tape = { "TopLeft" },
			Parent = dock,
		})
		UIKit.Brush({
			Text = "Better buses. Farther roads.",
			size = 22,
			color = "Text",
			tilt = 0,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = strip,
		})
	end

	-- Upgrade panel (right) ------------------------------------------------------------------------
	local rowCount = #UpgradeConfig.Categories
	local rowsTop = 158
	local rowsHeight = rowCount * ROW_HEIGHT + (rowCount - 1) * ROW_GAP
	local innerHeight = rowsTop + rowsHeight + 118
	local cardHeight = innerHeight + PADDING * 2

	local cardDock = UIKit.Dock({
		Name = "PanelDock",
		fitHeight = 0.78, -- never taller than 78% of the screen
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -M, 0.5, 0),
		Size = UDim2.fromOffset(CARD_WIDTH, cardHeight),
		Parent = screen,
	})
	local card = UIKit.Panel({
		Name = "GaragePanel",
		Size = UDim2.fromScale(1, 1),
		padding = PADDING,
		tape = { "TopRight" },
		Parent = cardDock,
	})

	-- Header
	UIKit.Brush({ Text = "Garage", size = 36, tilt = -2, Size = UDim2.new(1, -52, 0, 42), Parent = card })
	local headerLabel = UIKit.Text({
		size = 18,
		weight = "Bold",
		RichText = true,
		Size = UDim2.new(1, -52, 0, 22),
		Position = UDim2.fromOffset(0, 44),
		Parent = card,
	})
	local slotsLabel = UIKit.Text({
		size = "Small",
		color = "TextMuted",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 66),
		Parent = card,
	})
	local closeButton = UIKit.Button({
		Name = "CloseButton",
		Text = "✕",
		size = 22,
		variant = "ghost",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(42, 42),
		Parent = card,
	})

	-- Chassis selector
	local chassisCard = UIKit.Panel({
		Name = "ChassisRow",
		tone = "Row",
		Size = UDim2.new(1, 0, 0, 58),
		Position = UDim2.fromOffset(0, 92),
		radius = Theme.Radius.Medium,
		Parent = card,
	})
	local chassisPrev = UIKit.Button({
		Name = "PrevChassis",
		Text = "<",
		size = 26,
		variant = "ghost",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(38, 42),
		Parent = chassisCard,
	})
	local chassisNext = UIKit.Button({
		Name = "NextChassis",
		Text = ">",
		size = 26,
		variant = "ghost",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(38, 42),
		Parent = chassisCard,
	})
	local chassisName = UIKit.Text({
		size = 18,
		weight = "Bold",
		Size = UDim2.new(1, -108, 0, 22),
		Position = UDim2.fromOffset(54, 8),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = chassisCard,
	})
	local chassisSub = UIKit.Text({
		size = 13,
		color = "TextMuted",
		Size = UDim2.new(1, -108, 0, 18),
		Position = UDim2.fromOffset(54, 31),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = chassisCard,
	})

	-- Upgrade rows
	local rowsHolder = UIKit.Frame({
		Name = "Rows",
		Size = UDim2.new(1, 0, 0, rowsHeight),
		Position = UDim2.fromOffset(0, rowsTop),
		Parent = card,
	})
	UIKit.List(rowsHolder, { gap = ROW_GAP })

	local rows = {} -- category -> { minus, plus, levelLabel, statLabel, nameLabel }
	for i, category in ipairs(UpgradeConfig.Categories) do
		local row = UIKit.Panel({
			Name = category .. "Row",
			tone = "Row",
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			LayoutOrder = i,
			radius = Theme.Radius.Medium,
			padding = { 6, 10, 6, 10 },
			Parent = rowsHolder,
		})

		local textX = 0
		local iconBadge = UIKit.Icon({ icon = category, Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(4, 6) })
		if iconBadge then
			local badge = UIKit.Frame({
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.Colors.Inset,
				Size = UDim2.fromOffset(40, 40),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Parent = row,
			})
			UIKit.Corner(badge, Theme.Radius.Pill)
			iconBadge.Position = UDim2.fromOffset(5, 5)
			iconBadge.Parent = badge
			textX = 50
		end

		local nameLabel = UIKit.Text({
			Text = category,
			size = 15,
			weight = "Bold",
			Size = UDim2.new(1, -(140 + textX), 0, 20),
			Position = UDim2.fromOffset(textX, 1),
			Parent = row,
		})
		local statLabel = UIKit.Text({
			size = 14,
			color = "TextMuted",
			Size = UDim2.new(1, -(140 + textX), 0, 18),
			Position = UDim2.fromOffset(textX, 21),
			Parent = row,
		})

		local plus = UIKit.Button({
			Text = "+",
			size = 20,
			variant = "ghost",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			Parent = row,
		})
		local levelLabel = UIKit.Text({
			Name = "LevelLabel",
			Text = "0/" .. UpgradeConfig.MaxLevel,
			size = 22,
			weight = "Heavy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -36, 0.5, 0),
			Size = UDim2.fromOffset(62, 26),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = row,
		})
		local minus = UIKit.Button({
			Text = "−",
			size = 20,
			variant = "ghost",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -102, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
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
		size = 14,
		color = "TextMuted",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -70),
		Size = UDim2.new(1, 0, 0, 36),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	local confirmButton = UIKit.Button({
		Name = "ConfirmButton",
		Text = "Confirm",
		variant = "primary",
		size = 30,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 60),
		Parent = card,
	})

	-- Error toast (floats just above the panel)
	local toast = UIKit.Text({
		Name = "Toast",
		size = 16,
		weight = "Bold",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.Negative,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -PADDING - 12),
		Size = UDim2.new(1, 0, 0, 36),
		Visible = false,
		Parent = card,
	})
	UIKit.Corner(toast, Theme.Radius.Small)

	return {
		screenGui = screenGui,
		openButton = openButton,
		panel = screen,
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
