--[[
	UITheme.lua

	The Route Rush look: a grimy roadside garage. Worn charcoal panels,
	masking tape, hand-painted marker lettering, mustard paint buttons.
	Change the whole game's UI here -- UIKit.lua builds every component
	from these tokens.

	TEXTURES & ICONS (optional)
	  Everything renders without images. To get the full hand-made look,
	  upload images to Roblox and paste their ids ("rbxassetid://123...")
	  into Theme.Images / Theme.Icons below:
	    Images.PanelTexture  a dark grunge/scratched texture, used as a
	                         9-slice behind every panel (PanelSliceCenter)
	    Images.Tape          a torn masking-tape strip (PNG with alpha)
	    Images.Brush         a mustard brush stroke for primary buttons
	    Icons.*              white glyphs on transparent backgrounds
]]

local Theme = {}

local MARKER = "rbxasset://fonts/families/PermanentMarker.json"
local SANS = "rbxasset://fonts/families/SourceSansPro.json"

Theme.Fonts = {
	Brush = Font.new(MARKER, Enum.FontWeight.Regular), -- hand-painted headings, buttons, big labels
	Regular = Font.new(SANS, Enum.FontWeight.Regular),
	Medium = Font.new(SANS, Enum.FontWeight.SemiBold),
	Bold = Font.new(SANS, Enum.FontWeight.Bold),
	Heavy = Font.new(SANS, Enum.FontWeight.Heavy),
}

local C = Color3.fromRGB
Theme.Colors = {
	-- Surfaces: warm, oily charcoal
	Panel = C(24, 22, 20),
	PanelEdge = C(74, 66, 56),
	Row = C(38, 35, 31),
	RowEdge = C(60, 55, 47),
	Inset = C(14, 13, 12),

	-- Paint & tape
	Mustard = C(220, 180, 70),
	MustardDark = C(150, 116, 38),
	Tape = C(206, 180, 112),
	Rust = C(166, 88, 42),

	-- Text
	Text = C(238, 232, 218),
	TextMuted = C(172, 162, 144),
	TextDim = C(120, 112, 98),
	Ink = C(30, 24, 14), -- dark text on paint

	-- Stats & status
	Cash = C(112, 208, 110),
	Level = C(88, 152, 232),
	Rep = C(238, 198, 72),
	Positive = C(112, 208, 110),
	Negative = C(214, 82, 60),
	Warning = C(234, 152, 58),
}

-- Aliases used by components.
Theme.Colors.Accent = Theme.Colors.Mustard
Theme.Colors.OnAccent = Theme.Colors.Ink
Theme.Colors.Info = Theme.Colors.Level
Theme.Colors.Track = Theme.Colors.Inset
Theme.Colors.Stroke = Theme.Colors.PanelEdge
Theme.Colors.Surface = Theme.Colors.Panel
Theme.Colors.SurfaceAlt = Theme.Colors.Row
Theme.Colors.SurfaceRaised = Theme.Colors.Row

Theme.TextSize = {
	Caption = 12,
	Small = 14,
	Body = 16,
	Title = 22,
	Stat = 24,
	Display = 34,
	Hero = 120,
}

Theme.Radius = {
	Small = 3,
	Medium = 4,
	Large = 6,
	Pill = 999,
}

Theme.Spacing = { XS = 4, S = 8, M = 12, L = 16, XL = 24 }

Theme.ScreenMargin = 12

-- Masking tape stuck over panel corners.
Theme.Tape = {
	Size = Vector2.new(58, 18),
	Transparency = 0.1,
}

-- SCALING: the UI is designed at ReferenceResolution and scales with the
-- screen (bigger monitors = bigger UI). UIScale multiplies everything.
Theme.ReferenceResolution = Vector2.new(1280, 720)
Theme.UIScale = 1.1
Theme.MinScale = 0.6
Theme.MaxScale = 3

Theme.Images = {
	PanelTexture = "",
	PanelSliceCenter = Rect.new(32, 32, 480, 480),
	Tape = "",
	Brush = "",
}

Theme.Icons = {
	Garage = "",
	Timer = "",
	Close = "",
	Confirm = "",
	Engine = "",
	Accel = "",
	Brakes = "",
	Handles = "",
	Health = "",
}

return Theme
