--[[
	UITheme.lua

	Design tokens for every Route Rush screen UI and in-world billboard.
	Change the look of the whole game here: colors, fonts, text sizes,
	corner radii, spacing. UIKit.lua builds components from these.
]]

local Theme = {}

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"

Theme.Fonts = {
	Regular = Font.new(FAMILY, Enum.FontWeight.Regular),
	Medium = Font.new(FAMILY, Enum.FontWeight.Medium),
	Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	Heavy = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
}

Theme.Colors = {
	-- Surfaces (dark glass)
	Surface = Color3.fromRGB(14, 16, 22),
	SurfaceAlt = Color3.fromRGB(22, 25, 33),
	SurfaceRaised = Color3.fromRGB(34, 38, 49),
	Track = Color3.fromRGB(44, 48, 60), -- empty part of progress bars
	Stroke = Color3.fromRGB(255, 255, 255),

	-- Text
	Text = Color3.fromRGB(242, 244, 248),
	TextMuted = Color3.fromRGB(154, 160, 176),
	TextDim = Color3.fromRGB(104, 110, 126),
	OnAccent = Color3.fromRGB(20, 18, 12), -- text on accent-colored buttons

	-- Brand + status
	Accent = Color3.fromRGB(255, 196, 64), -- Route Rush yellow (matches stop rings)
	Positive = Color3.fromRGB(70, 212, 140),
	Negative = Color3.fromRGB(255, 92, 92),
	Warning = Color3.fromRGB(255, 166, 64),
	Info = Color3.fromRGB(96, 166, 255),
}

Theme.SurfaceTransparency = 0.1 -- panels are slightly see-through
Theme.StrokeTransparency = 0.9 -- hairline borders

Theme.TextSize = {
	Caption = 12, -- small uppercase labels
	Small = 14,
	Body = 16,
	Title = 20,
	Stat = 24,
	Display = 36,
	Hero = 96,
}

Theme.Radius = {
	Small = 6,
	Medium = 10,
	Large = 14,
	Pill = 999,
}

Theme.Spacing = {
	XS = 4,
	S = 8,
	M = 12,
	L = 16,
	XL = 24,
}

-- Distance from the screen edges for HUD clusters.
Theme.ScreenMargin = 16

-- UI scales with the screen; this is the "100%" reference resolution.
Theme.ReferenceResolution = Vector2.new(1280, 760)
Theme.MinScale = 0.62
Theme.MaxScale = 1.15

return Theme
