--[[
	UITheme.lua

	The Route Rush look: a grimy roadside garage. Worn charcoal panels,
	masking tape, hand-painted marker lettering, mustard paint buttons.
	Change the whole game's UI here -- UIKit.lua builds every component
	from these tokens.

	IMAGES (assets/ui in the repo)
	  The rugged textures and icons were made to match the garage concept
	  art. Upload the PNGs to Roblox (Studio: View > Asset Manager > Bulk
	  Import, or Creator Hub) and paste each "rbxassetid://..." below.
	  Anything left "" falls back to a code-drawn version of the same look.
	  Full steps: assets/ui/README.md
]]

local Theme = {}

-- Kalam Bold is the closest Roblox font to the concept art's slanted, condensed brush lettering.
local BRUSH = "rbxasset://fonts/families/Kalam.json"
local SANS = "rbxasset://fonts/families/SourceSansPro.json"

Theme.Fonts = {
	Brush = Font.new(BRUSH, Enum.FontWeight.Bold), -- hand-painted headings, buttons, big labels
	Regular = Font.new(SANS, Enum.FontWeight.Regular),
	Medium = Font.new(SANS, Enum.FontWeight.SemiBold),
	Bold = Font.new(SANS, Enum.FontWeight.Bold),
	BoldItalic = Font.new(SANS, Enum.FontWeight.Bold, Enum.FontStyle.Italic),
	Heavy = Font.new(SANS, Enum.FontWeight.Heavy),
}

local C = Color3.fromRGB
Theme.Colors = {
	-- Surfaces: warm, oily charcoal
	Panel = C(22, 21, 20),
	PanelEdge = C(74, 66, 54),
	Row = C(21, 21, 21),
	RowEdge = C(40, 39, 38),
	Plate = C(26, 27, 26), -- chassis selector, "No changes" strip
	PlateEdge = C(36, 36, 36),
	Key = C(30, 30, 32), -- small hardware keys (-, +, <, >, X)
	KeyEdge = C(44, 44, 46),
	Inset = C(14, 13, 12),
	TrackGrey = C(55, 55, 55),

	-- Paint & tape
	Mustard = C(124, 97, 42),
	MustardDark = C(90, 70, 30),
	Tape = C(113, 76, 14),
	Rust = C(166, 88, 42),

	-- Text
	Text = C(225, 222, 215),
	TextMuted = C(150, 150, 150),
	TextDim = C(125, 125, 125),
	Ink = C(28, 24, 16), -- dark text on paint

	-- Stats & status
	Cash = C(101, 209, 118),
	Level = C(46, 95, 142),
	Rep = C(231, 183, 72),
	Positive = C(101, 209, 118),
	Negative = C(200, 76, 58),
	Warning = C(226, 150, 58),
}

-- Aliases used by components.
Theme.Colors.Accent = Theme.Colors.Rep
Theme.Colors.OnAccent = Theme.Colors.Ink
Theme.Colors.Info = Theme.Colors.Level
Theme.Colors.Track = Theme.Colors.Inset
Theme.Colors.Stroke = Theme.Colors.PanelEdge
Theme.Colors.Surface = Theme.Colors.Panel
Theme.Colors.SurfaceAlt = Theme.Colors.Row
Theme.Colors.SurfaceRaised = Theme.Colors.Row

Theme.TextSize = {
	Caption = 12,
	Small = 13,
	Body = 16,
	Title = 22,
	Stat = 22,
	Display = 30,
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

-- Masking tape stuck over panel corners (design size of the tape image).
Theme.Tape = {
	Size = Vector2.new(60, 20),
	Transparency = 0.26,
}

-- SCALING: the UI is designed at ReferenceResolution and scales with the
-- screen (bigger monitors = bigger UI). UIScale multiplies everything.
Theme.ReferenceResolution = Vector2.new(1280, 720)
Theme.UIScale = 1.1
Theme.MinScale = 0.6
Theme.MaxScale = 3

-- Uploaded image ids. File names are relative to assets/ui/.
Theme.Images = {
	PanelFrame = "rbxassetid://130494582405364", -- textures/panel.png
	PaintButton = "rbxassetid://95411330679656", -- textures/button_paint.png
	Tape = "rbxassetid://84532661008683", -- textures/tape.png
	BrushStrip = "rbxassetid://134489831688997", -- textures/brush_strip.png
	TopBar = "rbxassetid://118198796171574", -- textures/topbar.png
}

-- How each texture is 9-sliced, in design pixels (the PNGs are rendered at ImageScale x).
Theme.ImageScale = 3
Theme.Slices = {
	PanelFrame = Rect.new(14, 14, 66, 66),
	PaintButton = Rect.new(24, 12, 276, 42),
	BrushStrip = Rect.new(70, 22, 330, 58),
	TopBar = Rect.new(24, 8, 536, 34),
}

Theme.Icons = {
	Garage = "rbxassetid://94048184605412", -- icons/garage.png
	Timer = "rbxassetid://76574063948559", -- icons/timer.png
	Map = "rbxassetid://123116659137042", -- icons/map.png
	Missions = "rbxassetid://97106781665277", -- icons/missions.png
	Settings = "rbxassetid://133417638626148", -- icons/settings.png
	Engine = "rbxassetid://88075541460027", -- icons/engine.png
	Accel = "rbxassetid://134002457454580", -- icons/accel.png
	Brakes = "rbxassetid://112414306592379", -- icons/brakes.png
	Handles = "rbxassetid://123072122836008", -- icons/handles.png
	Health = "rbxassetid://103905979104482", -- icons/health.png
	Wrench = "rbxassetid://121219263663002", -- icons/wrench.png
	Crown = "rbxassetid://79188763787140", -- icons/crown.png
}

return Theme
