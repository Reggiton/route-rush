--[[
	GarageGuiBuilder.lua

	Builds the garage screen to match the garage concept art
	(bbd_ui_ref.png). Every position and size below is in the art's own
	pixels (the UI scales with the screen from there):

	  top-left      torn brush strip: garage icon, GARAGE, tagline line
	  bottom-left   MAP / MISSIONS / SETTINGS plates with brush labels
	  right         taped charcoal panel: GARAGE, cash/level/rep, slots,
	                chassis selector, five upgrade rows, note strip, paint CONFIRM
	  bottom-right  rotated brush strip: BETTER BUSES. FARTHER ROADS. + crown

	Textures and icons come from UITheme.Images / UITheme.Icons (upload the
	PNGs in assets/ui). Until they're uploaded, code-drawn fallbacks are used.

	Only BUILDS instances. GarageController fills in text and wires callbacks.
	`panel` is the whole open garage screen so toggling Visible opens/closes it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("GarageSystem").Config.UpgradeConfig)

local UI = script.Parent.Parent:WaitForChild("UI")
local UIKit = require(UI:WaitForChild("UIKit"))
local Theme = UIKit.Theme

local GarageGuiBuilder = {}

local ROW_TOP = 147
local ROW_PITCH = 52
local SOFT_TEXT = Color3.fromRGB(200, 196, 188)
local CROWN = Color3.fromRGB(190, 170, 130)

-- Flat plate with a hairline edge (chassis selector, upgrade rows, note strip).
local function plate(parent, position, size, fill, edge)
	local frame = UIKit.Frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors[fill],
		Position = position,
		Size = size,
		Parent = parent,
	})
	UIKit.Corner(frame, Theme.Radius.Medium)
	UIKit.Stroke(frame, { color = edge, transparency = 0, thickness = 1 })
	return frame
end

-- A piece of masking tape centered at `position`.
local function tapeAt(parent, position, width, height, rotation)
	local tape = UIKit.Tape(parent, "TopLeft")
	tape.Position = position
	tape.Size = UDim2.fromOffset(width, height)
	tape.Rotation = rotation
	return tape
end

-- An icon from Theme.Icons, or (if not uploaded yet) its first letter in marker.
local function iconOrLetter(parent, iconName, letter, position, size, color)
	local icon = UIKit.Icon({ icon = iconName, color = color, Position = position, Size = size, Parent = parent })
	if icon then
		return icon
	end
	return UIKit.Brush({
		Text = letter,
		size = math.floor(size.Y.Offset * 0.7),
		tilt = 0,
		color = color,
		Position = position,
		Size = size,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = parent,
	})
end

-- Let long text shrink to fit instead of cutting off.
local function shrinkToFit(label, maxSize, minSize)
	label.TextScaled = true
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.MinTextSize = minSize
	constraint.Parent = label
end

function GarageGuiBuilder.Build(playerGui)
	local screenGui = UIKit.Screen("GarageGui", playerGui, 10)

	-- GARAGE button (top-left, under the Roblox menu buttons) ---------------------------------
	local buttonDock = UIKit.Dock({
		Name = "OpenDock",
		Position = UDim2.fromOffset(Theme.ScreenMargin, 64),
		Size = UDim2.fromOffset(170, 56),
		Parent = screenGui,
	})
	local openButton = UIKit.Button({
		Name = "OpenGarageButton",
		Text = "GARAGE",
		variant = "primary",
		size = 22,
		Size = UDim2.fromOffset(150, 46),
		Parent = buttonDock,
	})

	-- The open garage screen ---------------------------------------------------------------------
	local screen = UIKit.Frame({ Name = "GarageScreen", Size = UDim2.fromScale(1, 1), Visible = false, Parent = screenGui })

	-- Title strip (top-left). Sits just under Roblox's own top-left buttons.
	do
		local dock = UIKit.Dock({ Name = "TitleDock", Position = UDim2.fromOffset(8, 56), Size = UDim2.fromOffset(256, 72), Parent = screen })
		UIKit.Panel({ image = "BrushStrip", Size = UDim2.fromScale(1, 1), Parent = dock })
		local icon = UIKit.Icon({
			icon = "Garage",
			color = Theme.Colors.Text,
			Position = UDim2.fromOffset(11, 6),
			Size = UDim2.fromOffset(52, 48),
			Parent = dock,
		})
		local textX = icon and 72 or 18
		UIKit.Brush({
			Text = "GARAGE",
			size = 24,
			tilt = -2,
			Position = UDim2.fromOffset(textX, 2),
			Size = UDim2.fromOffset(180, 32),
			Parent = dock,
		})
		local subtitle = UIKit.Brush({
			Text = "THE ONLY PLACE THAT FEELS LIKE HOME.",
			size = 9,
			tilt = -3,
			color = SOFT_TEXT,
			Position = UDim2.fromOffset(textX + 1, 37),
			Size = UDim2.fromOffset(176, 16),
			Parent = dock,
		})
		shrinkToFit(subtitle, 9, 7)
	end

	-- Nav rail (bottom-left) ----------------------------------------------------------------------
	local navButtons = {}
	do
		local dock = UIKit.Dock({
			Name = "NavDock",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -29),
			Size = UDim2.fromOffset(140, 170),
			Parent = screen,
		})
		local items = {
			{ key = "Map", label = "MAP", y = 0, stripWidth = 68 },
			{ key = "Missions", label = "MISSIONS", y = 60, stripWidth = 83 },
			{ key = "Settings", label = "SETTINGS", y = 118, stripWidth = 87 },
		}
		for _, item in ipairs(items) do
			local strip = UIKit.Panel({
				Name = item.key .. "Label",
				image = "BrushStrip",
				sliceScale = 0.35,
				radius = Theme.Radius.Small,
				Position = UDim2.fromOffset(42, item.y + 11),
				Size = UDim2.fromOffset(item.stripWidth, 30),
				ZIndex = 1,
				Parent = dock,
			})
			UIKit.Brush({
				Text = item.label,
				size = 12,
				tilt = 0,
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -16, 1, 0),
				Parent = strip,
			})

			local iconPlate = UIKit.Panel({
				Name = item.key .. "Plate",
				radius = Theme.Radius.Medium,
				Position = UDim2.fromOffset(0, item.y),
				Size = UDim2.fromOffset(52, 51),
				ZIndex = 2,
				Parent = dock,
			})
			iconOrLetter(iconPlate, item.key, string.sub(item.label, 1, 1), UDim2.fromOffset(9, 8), UDim2.fromOffset(35, 35), Theme.Colors.Text)

			local hit = Instance.new("TextButton")
			hit.Name = item.key .. "Button"
			hit.Text = ""
			hit.BackgroundTransparency = 1
			hit.Position = UDim2.fromOffset(0, item.y)
			hit.Size = UDim2.fromOffset(42 + item.stripWidth, 51)
			hit.ZIndex = 3
			hit.Parent = dock
			navButtons[item.key] = hit
		end
	end

	-- Upgrade panel (right) --------------------------------------------------------------------------
	local panelDock = UIKit.Dock({
		Name = "PanelDock",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -15, 0.5, -13),
		Size = UDim2.fromOffset(348, 495),
		fitHeight = 0.82,
		Parent = screen,
	})
	local card = UIKit.Panel({ Name = "GaragePanel", Size = UDim2.fromScale(1, 1), Parent = panelDock })

	-- Tape over the top edge
	tapeAt(card, UDim2.fromOffset(222, -9), 50, 20, 4)
	tapeAt(card, UDim2.fromOffset(242, -5), 44, 16, -3)

	-- Header
	UIKit.Brush({ Text = "GARAGE", size = 27, tilt = 0, Position = UDim2.fromOffset(18, 11), Size = UDim2.fromOffset(200, 32), Parent = card })
	local closeButton = UIKit.Button({
		Name = "CloseButton",
		Text = "✕",
		size = 20,
		variant = "key",
		Position = UDim2.fromOffset(290, -3),
		Size = UDim2.fromOffset(38, 38),
		Parent = card,
	})
	local headerLabel = UIKit.Text({
		weight = "Bold",
		size = 17,
		RichText = true,
		Position = UDim2.fromOffset(17, 45),
		Size = UDim2.fromOffset(268, 20),
		Parent = card,
	})
	local slotsLabel = UIKit.Text({
		weight = "Regular",
		size = 13,
		color = "TextMuted",
		Position = UDim2.fromOffset(17, 65),
		Size = UDim2.fromOffset(314, 15),
		Parent = card,
	})
	shrinkToFit(slotsLabel, 13, 9)

	-- Chassis selector
	local chassisPlate = plate(card, UDim2.fromOffset(15, 82), UDim2.fromOffset(318, 55), "Plate", "PlateEdge")
	local chassisPrev = UIKit.Button({
		Name = "PrevChassis",
		Text = "<",
		size = 28,
		variant = "key",
		Position = UDim2.fromOffset(4, 7),
		Size = UDim2.fromOffset(35, 41),
		Parent = chassisPlate,
	})
	local chassisNext = UIKit.Button({
		Name = "NextChassis",
		Text = ">",
		size = 28,
		variant = "key",
		Position = UDim2.fromOffset(279, 7),
		Size = UDim2.fromOffset(35, 41),
		Parent = chassisPlate,
	})
	local chassisName = UIKit.Text({
		weight = "Bold",
		size = 16,
		Position = UDim2.fromOffset(43, 9),
		Size = UDim2.fromOffset(232, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = chassisPlate,
	})
	shrinkToFit(chassisName, 16, 11)
	local chassisSub = UIKit.Text({
		weight = "Regular",
		size = 11,
		color = "TextMuted",
		Position = UDim2.fromOffset(43, 31),
		Size = UDim2.fromOffset(232, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = chassisPlate,
	})
	shrinkToFit(chassisSub, 11, 8)

	-- Upgrade rows
	local rows = {} -- category -> { minus, plus, levelLabel, statLabel, nameLabel }
	for i, category in ipairs(UpgradeConfig.Categories) do
		local row = plate(card, UDim2.fromOffset(12, ROW_TOP + (i - 1) * ROW_PITCH), UDim2.fromOffset(322, 48), "Row", "RowEdge")
		row.Name = category .. "Row"

		iconOrLetter(row, category, string.sub(category, 1, 1), UDim2.fromOffset(6, 5), UDim2.fromOffset(38, 38), Theme.Colors.Text)

		local nameLabel = UIKit.Text({
			Text = category,
			weight = "Bold",
			size = 16,
			Position = UDim2.fromOffset(60, 5),
			Size = UDim2.fromOffset(156, 19),
			Parent = row,
		})
		shrinkToFit(nameLabel, 16, 10)
		local statLabel = UIKit.Text({
			weight = "Regular",
			size = 15,
			color = "TextDim",
			Position = UDim2.fromOffset(60, 25),
			Size = UDim2.fromOffset(156, 18),
			Parent = row,
		})
		shrinkToFit(statLabel, 15, 10)

		local minus = UIKit.Button({
			Text = "–",
			size = 18,
			variant = "key",
			Position = UDim2.fromOffset(220, 7),
			Size = UDim2.fromOffset(26, 34),
			Parent = row,
		})
		local levelLabel = UIKit.Text({
			Name = "LevelLabel",
			Text = "0/" .. UpgradeConfig.MaxLevel,
			weight = "Bold",
			size = 24,
			Position = UDim2.fromOffset(247, 0),
			Size = UDim2.fromOffset(44, 48),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = row,
		})
		local plus = UIKit.Button({
			Text = "+",
			size = 18,
			variant = "key",
			Position = UDim2.fromOffset(291, 7),
			Size = UDim2.fromOffset(27, 34),
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

	-- Note strip ("No changes" / cost quote)
	local notePlate = plate(card, UDim2.fromOffset(24, 410), UDim2.fromOffset(295, 22), "Plate", "PlateEdge")
	local quoteLabel = UIKit.Text({
		weight = "Regular",
		size = 13,
		color = "TextDim",
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -12, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = notePlate,
	})
	shrinkToFit(quoteLabel, 13, 8)

	-- Paint CONFIRM button: wrench + marker lettering, centered together
	local confirmButton = UIKit.Button({
		Name = "ConfirmButton",
		Text = "",
		variant = "primary",
		tilt = 0,
		Position = UDim2.fromOffset(24, 430),
		Size = UDim2.fromOffset(295, 52),
		Parent = card,
	})
	local confirmContent = UIKit.Frame({
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = confirmButton,
	})
	UIKit.List(confirmContent, { direction = "Horizontal", gap = 10, valign = "Center" })
	UIKit.Icon({ icon = "Wrench", color = Theme.Colors.Ink, Size = UDim2.fromOffset(29, 32), LayoutOrder = 1, Parent = confirmContent })
	local confirmLabel = UIKit.Brush({
		Text = "CONFIRM",
		size = 22,
		tilt = 0,
		color = "Ink",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = confirmContent,
	})

	-- Tape over the button's corners
	tapeAt(card, UDim2.fromOffset(30, 435), 40, 20, -35)
	tapeAt(card, UDim2.fromOffset(306, 474), 36, 18, -35)

	-- Error toast (just above the panel)
	local toast = UIKit.Text({
		Name = "Toast",
		weight = "Bold",
		size = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.Negative,
		Position = UDim2.fromOffset(0, -44),
		Size = UDim2.fromOffset(348, 28),
		Visible = false,
		Parent = card,
	})
	UIKit.Corner(toast, Theme.Radius.Small)

	-- Tagline (bottom-right) ---------------------------------------------------------------------------
	do
		local dock = UIKit.Dock({
			Name = "TaglineDock",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -11, 1, -13),
			Size = UDim2.fromOffset(273, 73),
			Parent = screen,
		})
		local strip = UIKit.Panel({
			image = "BrushStrip",
			sliceScale = 0.6,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(268, 46),
			Rotation = -9,
			Parent = dock,
		})
		UIKit.Brush({
			Text = "BETTER BUSES. FARTHER ROADS.",
			size = 13,
			tilt = 0,
			color = SOFT_TEXT,
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -70, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = strip,
		})
		UIKit.Icon({
			icon = "Crown",
			color = CROWN,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -16, 0.5, -2),
			Size = UDim2.fromOffset(22, 20),
			Parent = strip,
		})
	end

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
		confirmLabel = confirmLabel,
		navButtons = navButtons,
		toast = toast,
	}
end

return GarageGuiBuilder
