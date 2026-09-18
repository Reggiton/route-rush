--[[
	StylePreview.client.lua

	STUDIO ONLY, and throwaway: a side-by-side of the two UI directions so
	the look can be chosen by eye before the HUD is ported onto UIKit.
	Press F4 to show/hide it. Delete this file once the choice is made.

	Both columns are built from the same UIKit components and UITheme
	tokens, inside Docks -- so this also previews the screen scaling. The
	only difference between them is which UIKit options are used:

	  PLAIN   flat code-drawn panels (tone "Row"), sans-serif headings,
	          straight solid buttons. Close to what the HUD looks like now.
	  GRUNGE  the art direction UITheme was built for: the 9-sliced panel
	          plate, masking tape, Kalam brush lettering, mustard paint
	          buttons. Uses the textures already uploaded in Theme.Images.

	Resize the Studio window while it's open -- that's the half of this
	that a screenshot can't show.
]]

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)
local Theme = UIKit.Theme

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TOGGLE_KEY = Enum.KeyCode.F4
local COLUMN_W, COLUMN_H = 320, 470

-- One column of sample HUD pieces in the given style ------------------------------------------

local function buildColumn(parent, style, xScale)
	local grunge = style == "grunge"

	-- Positioned by scale rather than a big pixel offset: a dock's own
	-- Position offsets are NOT scaled, so two columns pinned by offset
	-- would overlap once the dock scaled up on a large monitor.
	local dock = UIKit.Dock({
		Name = style,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(xScale, 0.5),
		Size = UDim2.fromOffset(COLUMN_W, COLUMN_H),
		fitHeight = 0.9,
		Parent = parent,
	})

	-- Heading for the column itself
	local heading = grunge
		and UIKit.Brush({ Text = "GRUNGE", size = "Title", color = "Mustard", Parent = dock })
		or UIKit.Text({ Text = "PLAIN", size = "Title", weight = "Heavy", color = "Text", Parent = dock })
	heading.Size = UDim2.new(1, 0, 0, 30)
	heading.TextXAlignment = Enum.TextXAlignment.Center

	-- Shared panel options per style. "Row" has no texture slot, so it
	-- falls back to the code-drawn corner + stroke + grime.
	local function panel(name, y, height)
		return UIKit.Panel({
			Name = name,
			Size = UDim2.fromOffset(COLUMN_W, height),
			Position = UDim2.fromOffset(0, y),
			tone = grunge and "Panel" or "Row",
			padding = Theme.Spacing.M,
			tape = grunge and { "TopLeft" } or nil,
			Parent = dock,
		})
	end

	local function title(parentPanel, text)
		if grunge then
			return UIKit.Brush({ Text = text, size = "Title", color = "Text", Parent = parentPanel })
		end
		return UIKit.Text({ Text = text, size = "Title", weight = "Heavy", color = "Text", Parent = parentPanel })
	end

	-- 1. Status pill: caption, timer, phase progress -------------------------------------
	do
		local card = panel("Status", 40, 96)
		UIKit.Caption({ Text = "Next route", Parent = card })
		UIKit.Text({
			Text = "1:24",
			size = "Display",
			weight = grunge and "Brush" or "Heavy",
			color = "Text",
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 34),
			Parent = card,
		})
		local _, fill = UIKit.Bar({
			Name = "Progress",
			Size = UDim2.new(1, 0, 0, 6),
			Position = UDim2.fromOffset(0, 58),
			color = Theme.Colors.Accent,
			Parent = card,
		})
		UIKit.SetFill(fill, 0.62)
	end

	-- 2. Ready card: heading, status line, action button --------------------------------
	do
		local card = panel("Ready", 150, 150)
		title(card, grunge and "NEXT RACE" or "Next race")
		UIKit.Text({
			Text = "3 of 5 players ready",
			size = "Small",
			weight = "Regular",
			color = "TextMuted",
			Position = UDim2.fromOffset(0, 30),
			Parent = card,
		})

		UIKit.Button({
			Text = "Ready up",
			Size = UDim2.new(1, 0, 0, 46),
			Position = UDim2.fromOffset(0, 60),
			variant = grunge and "primary" or "success",
			size = "Body",
			-- Plain keeps the sans face and sits square; the painted variant
			-- brings its own brush lettering and slight tilt.
			FontFace = (not grunge) and Theme.Fonts.Bold or nil,
			tilt = (not grunge) and 0 or nil,
			Parent = card,
		})

		UIKit.Button({
			Text = "Leave race",
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 112),
			variant = grunge and "danger" or "secondary",
			size = "Small",
			FontFace = (not grunge) and Theme.Fonts.Bold or nil,
			tilt = (not grunge) and 0 or nil,
			Parent = card,
		})
	end

	-- 3. Bus panel: two meters ------------------------------------------------------------
	do
		local card = panel("Bus", 314, 130)
		local function meter(caption, y, value, fraction, color)
			UIKit.Caption({ Text = caption, Position = UDim2.fromOffset(0, y), Parent = card })
			UIKit.Text({
				Text = value,
				size = "Small",
				color = "Text",
				Position = UDim2.fromOffset(0, y),
				Size = UDim2.new(1, 0, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = card,
			})
			local _, fill = UIKit.Bar({
				Size = UDim2.new(1, 0, 0, 8),
				Position = UDim2.fromOffset(0, y + 20),
				color = color,
				Parent = card,
			})
			UIKit.SetFill(fill, fraction)
		end

		meter("Passengers", 0, "18 / 30", 0.6, Theme.Colors.Positive)
		meter("Health", 46, "72 / 120", 0.6, Theme.Colors.Negative)
	end

	return dock
end

-- Screen ---------------------------------------------------------------------------------------

local screen = UIKit.Screen("StylePreview", playerGui, 100)
screen.Enabled = false

local backdrop = UIKit.Frame({
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 0.25,
	Parent = screen,
})
backdrop.BackgroundColor3 = Theme.Colors.Inset

buildColumn(backdrop, "plain", 0.28)
buildColumn(backdrop, "grunge", 0.72)

local hint = UIKit.Text({
	Name = "Hint",
	Text = "F4 closes · resize the window to see the scaling",
	size = "Small",
	weight = "Regular",
	color = "TextMuted",
	Size = UDim2.new(1, 0, 0, 20),
	Position = UDim2.new(0, 0, 1, -30),
	Parent = backdrop,
})
hint.TextXAlignment = Enum.TextXAlignment.Center

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == TOGGLE_KEY then
		screen.Enabled = not screen.Enabled
	end
end)

print("[StylePreview] Press F4 to compare the plain and grunge UI styles.")
