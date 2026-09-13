--[[
	UIKit.lua

	Component library for the Route Rush look (see UITheme.lua): worn
	panels, masking tape, marker-lettered headings, mustard paint buttons.

	Every constructor takes one props table:
	  - PascalCase keys are applied as Roblox properties (Size, Position,
	    AnchorPoint, Name, LayoutOrder, Visible, Text, ...). Parent is set last.
	  - lowercase keys are UIKit options (tone, tape, padding, size, weight,
	    color, variant, tilt, icon).

	SCALING: build each screen corner as one Dock. A dock scales with the
	screen around its anchor, and everything inside it scales together, so
	pieces never drift apart or overlap on big monitors.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.UITheme)

local UIKit = {}

UIKit.Theme = Theme

-- Helpers ------------------------------------------------------------------------------------

local function apply(instance, props)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		elseif string.match(key, "^%u") then
			instance[key] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function color(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	return Theme.Colors[value or fallback] or Theme.Colors[fallback]
end
UIKit.Color = color

local function paddingOf(padding)
	if type(padding) == "table" then
		return padding[1] or 0, padding[2] or 0, padding[3] or 0, padding[4] or 0
	end
	padding = padding or 0
	return padding, padding, padding, padding
end

local tweenInfos = {}
function UIKit.Tween(instance, goals, duration, style)
	duration = duration or 0.18
	style = style or Enum.EasingStyle.Quad
	local key = tostring(duration) .. style.Name
	local info = tweenInfos[key]
	if not info then
		info = TweenInfo.new(duration, style, Enum.EasingDirection.Out)
		tweenInfos[key] = info
	end
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

function UIKit.Corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.Radius.Medium)
	corner.Parent = parent
	return corner
end

function UIKit.Stroke(parent, props)
	props = props or {}
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color(props.color, "PanelEdge")
	stroke.Transparency = props.transparency or 0.2
	stroke.Thickness = props.thickness or 2
	stroke.Parent = parent
	return stroke
end

-- padding: number (all sides) or { top, right, bottom, left }
function UIKit.Padding(parent, padding)
	local top, right, bottom, left = paddingOf(padding)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, top)
	p.PaddingRight = UDim.new(0, right)
	p.PaddingBottom = UDim.new(0, bottom)
	p.PaddingLeft = UDim.new(0, left)
	p.Parent = parent
	return p
end

-- props: direction ("Vertical"/"Horizontal"), gap, align ("Left"/"Center"/"Right"), valign ("Top"/"Center"/"Bottom")
function UIKit.List(parent, props)
	props = props or {}
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection[props.direction or "Vertical"]
	list.Padding = UDim.new(0, props.gap or Theme.Spacing.S)
	list.HorizontalAlignment = Enum.HorizontalAlignment[props.align or "Left"]
	list.VerticalAlignment = Enum.VerticalAlignment[props.valign or "Top"]
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = parent
	return list
end

-- Vertical grime: slightly lighter at the top, dirtier at the bottom.
local function grime(parent, strength)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	local dark = 1 - (strength or 0.18)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.55, Color3.new(0.94, 0.94, 0.93)),
		ColorSequenceKeypoint.new(1, Color3.new(dark, dark * 0.98, dark * 0.95)),
	})
	gradient.Parent = parent
	return gradient
end

local function textureBehind(parent, imageId, padding)
	if not imageId or imageId == "" then
		return
	end
	local top, right, bottom, left = paddingOf(padding)
	local image = Instance.new("ImageLabel")
	image.Name = "Texture"
	image.BackgroundTransparency = 1
	image.Image = imageId
	image.ScaleType = Enum.ScaleType.Slice
	image.SliceCenter = Theme.Images.PanelSliceCenter
	image.Size = UDim2.new(1, left + right, 1, top + bottom)
	image.Position = UDim2.fromOffset(-left, -top)
	image.ZIndex = 0
	image.Parent = parent
end

-- Building blocks -------------------------------------------------------------------------------

-- Invisible container.
function UIKit.Frame(props)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	return apply(frame, props)
end

--[[
	A strip of masking tape over a panel corner.
	corner: "TopLeft" | "TopRight" | "BottomLeft" | "BottomRight"
	padding: the panel's padding (so the tape lands on the real corner)
]]
function UIKit.Tape(parent, corner, padding)
	local top, right, bottom, left = paddingOf(padding)
	local size = Theme.Tape.Size

	local tape
	if Theme.Images.Tape ~= "" then
		tape = Instance.new("ImageLabel")
		tape.BackgroundTransparency = 1
		tape.Image = Theme.Images.Tape
	else
		tape = Instance.new("Frame")
		tape.BorderSizePixel = 0
		tape.BackgroundColor3 = Theme.Colors.Tape
		tape.BackgroundTransparency = Theme.Tape.Transparency
		-- ragged, see-through ends
		local fray = Instance.new("UIGradient")
		fray.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.08, 0.05),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(0.92, 0.05),
			NumberSequenceKeypoint.new(1, 0.6),
		})
		fray.Parent = tape
	end
	tape.Name = "Tape"
	tape.AnchorPoint = Vector2.new(0.5, 0.5)
	tape.Size = UDim2.fromOffset(size.X, size.Y)
	tape.ZIndex = 10

	if corner == "TopLeft" then
		tape.Position = UDim2.new(0, -left + 8, 0, -top + 4)
		tape.Rotation = -36
	elseif corner == "TopRight" then
		tape.Position = UDim2.new(1, right - 8, 0, -top + 4)
		tape.Rotation = 36
	elseif corner == "BottomLeft" then
		tape.Position = UDim2.new(0, -left + 8, 1, bottom - 4)
		tape.Rotation = 36
	else
		tape.Position = UDim2.new(1, right - 8, 1, bottom - 4)
		tape.Rotation = -36
	end
	tape.Parent = parent
	return tape
end

--[[
	Worn charcoal panel: dark fill, scuffed edge, grime gradient, optional tape.
	options: tone ("Panel"/"Row"/"Inset"), padding, radius, stroke (false to disable),
	         tape ({ "TopLeft", "TopRight", ... })
]]
function UIKit.Panel(props)
	local panel = Instance.new("Frame")
	panel.BorderSizePixel = 0
	local tone = props.tone or "Panel"
	panel.BackgroundColor3 = color(tone, "Panel")
	panel.BackgroundTransparency = props.transparency or (tone == "Panel" and 0.04 or 0)
	apply(panel, props)

	UIKit.Corner(panel, props.radius or Theme.Radius.Large)
	if props.stroke ~= false then
		UIKit.Stroke(panel, {
			color = tone == "Row" and "RowEdge" or "PanelEdge",
			transparency = tone == "Row" and 0.35 or 0.15,
			thickness = tone == "Row" and 1 or 2,
		})
	end
	grime(panel, tone == "Panel" and 0.22 or 0.12)
	if props.padding then
		UIKit.Padding(panel, props.padding)
	end
	if tone == "Panel" then
		textureBehind(panel, Theme.Images.PanelTexture, props.padding)
	end
	for _, corner in ipairs(props.tape or {}) do
		UIKit.Tape(panel, corner, props.padding)
	end
	return panel
end

-- options: size (Theme.TextSize key or number), weight (Theme.Fonts key), color (Theme.Colors key or Color3)
function UIKit.Text(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = Theme.Fonts[props.weight or "Medium"]
	local textSize = type(props.size) == "number" and props.size or Theme.TextSize[props.size or "Body"]
	label.TextSize = textSize
	label.TextColor3 = color(props.color, "Text")
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Size = UDim2.new(1, 0, 0, textSize + 4)
	label.Text = ""
	return apply(label, props)
end

-- Hand-painted marker lettering (GARAGE, STOP 3, CONFIRM). options: tilt (degrees, default -2)
function UIKit.Brush(props)
	props.weight = "Brush"
	props.size = props.size or "Title"
	local label = UIKit.Text(props)
	label.TextTruncate = Enum.TextTruncate.None
	label.Rotation = props.tilt or -2
	return label
end

-- Small label above a value ("NEXT ROUTE", "BOARDING RATE").
function UIKit.Caption(props)
	props.size = props.size or "Caption"
	props.weight = props.weight or "Bold"
	props.color = props.color or "TextMuted"
	if props.Text then
		props.Text = string.upper(props.Text)
	end
	return UIKit.Text(props)
end

-- Optional icon (only if an image id is set in Theme.Icons). Returns the ImageLabel or nil.
function UIKit.Icon(props)
	local id = Theme.Icons[props.icon or ""]
	if not id or id == "" then
		return nil
	end
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = id
	image.ImageColor3 = color(props.color, "Text")
	image.ScaleType = Enum.ScaleType.Fit
	return apply(image, props)
end

local VARIANTS = {
	-- painted
	primary = { bg = "Mustard", text = "Ink", font = "Brush", paint = true },
	success = { bg = "Positive", text = "Ink", font = "Brush", paint = true },
	danger = { bg = "Negative", text = "Text", font = "Brush", paint = true },
	-- hardware
	secondary = { bg = "Row", text = "Text", font = "Bold", edge = "RowEdge" },
	ghost = { bg = "Inset", text = "Text", font = "Bold", edge = "PanelEdge" },
}

--[[
	options: variant ("primary"/"success"/"danger" = mustard/green/red paint with
	marker lettering; "secondary"/"ghost" = dark hardware keys), size, radius, tilt
	Hover brightens, press shrinks slightly, Interactable = false greys it out.
]]
function UIKit.Button(props)
	local variantName = props.variant or "secondary"
	local variant = VARIANTS[variantName] or VARIANTS.secondary

	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.FontFace = Theme.Fonts[variant.font]
	button.TextSize = type(props.size) == "number" and props.size or Theme.TextSize[props.size or "Body"]
	button.TextWrapped = true
	apply(button, props)
	UIKit.Corner(button, props.radius or Theme.Radius.Small)

	if variant.paint then
		button.Rotation = props.tilt or -0.8
		-- uneven brush streaks + frayed ends
		local streaks = Instance.new("UIGradient")
		streaks.Rotation = 4
		streaks.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0.8, 0.8, 0.8)),
			ColorSequenceKeypoint.new(0.05, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.35, Color3.new(0.93, 0.93, 0.93)),
			ColorSequenceKeypoint.new(0.62, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.9, Color3.new(0.9, 0.9, 0.9)),
			ColorSequenceKeypoint.new(1, Color3.new(0.78, 0.78, 0.78)),
		})
		streaks.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.025, 0),
			NumberSequenceKeypoint.new(0.975, 0),
			NumberSequenceKeypoint.new(1, 0.3),
		})
		streaks.Parent = button
		UIKit.Stroke(button, { color = "MustardDark", transparency = 0.45, thickness = 2 })
		if Theme.Images.Brush ~= "" then
			local brush = Instance.new("ImageLabel")
			brush.Name = "Brush"
			brush.BackgroundTransparency = 1
			brush.Image = Theme.Images.Brush
			brush.ScaleType = Enum.ScaleType.Stretch
			brush.Size = UDim2.fromScale(1, 1)
			brush.ZIndex = 0
			brush.Parent = button
			button.BackgroundTransparency = 1
		end
	else
		UIKit.Stroke(button, { color = variant.edge, transparency = 0.2, thickness = 1.5 })
	end

	local pressScale = Instance.new("UIScale")
	pressScale.Name = "PressScale"
	pressScale.Parent = button

	local hovered = false
	local function refresh(instant)
		local current = VARIANTS[button:GetAttribute("Variant")] or variant
		local base = Theme.Colors[current.bg]
		local enabled = button.Interactable
		local goals = {
			BackgroundColor3 = (enabled and hovered) and base:Lerp(Color3.new(1, 1, 1), 0.12) or base,
			TextColor3 = Theme.Colors[current.text],
			TextTransparency = enabled and 0 or 0.5,
		}
		if Theme.Images.Brush == "" or not current.paint then
			goals.BackgroundTransparency = enabled and 0 or 0.55
		end
		if instant then
			for key, value in pairs(goals) do
				button[key] = value
			end
		else
			UIKit.Tween(button, goals, 0.12)
		end
	end

	button:SetAttribute("Variant", variantName)
	refresh(true)

	button.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		refresh()
		UIKit.Tween(pressScale, { Scale = 1 }, 0.1)
	end)
	button.MouseButton1Down:Connect(function()
		if button.Interactable then
			UIKit.Tween(pressScale, { Scale = 0.95 }, 0.07)
		end
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(pressScale, { Scale = 1 }, 0.14, Enum.EasingStyle.Back)
	end)
	button:GetPropertyChangedSignal("Interactable"):Connect(function()
		refresh()
	end)
	button:GetAttributeChangedSignal("Variant"):Connect(function()
		refresh()
	end)

	return button
end

-- Switch between variants that share a style family (e.g. primary <-> secondary).
function UIKit.SetVariant(button, variant)
	if button:GetAttribute("Variant") ~= variant then
		button:SetAttribute("Variant", variant)
	end
end

-- Recessed gauge. Returns (track, fill). options: color
function UIKit.Bar(props)
	local track = Instance.new("Frame")
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Theme.Colors.Inset
	track.ClipsDescendants = true
	apply(track, props)
	UIKit.Corner(track, Theme.Radius.Small)
	UIKit.Stroke(track, { color = "PanelEdge", transparency = 0.5, thickness = 1 })

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = color(props.color, "Mustard")
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	UIKit.Corner(fill, Theme.Radius.Small)
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.72, 0.72, 0.72))
	shine.Parent = fill

	return track, fill
end

-- Smoothly sets a bar's fill (0..1) and optionally its color.
function UIKit.SetFill(fill, fraction, fillColor)
	fraction = math.clamp(fraction or 0, 0, 1)
	local current = fill.Size.X.Scale
	if math.abs(current - fraction) > 0.02 then
		UIKit.Tween(fill, { Size = UDim2.fromScale(fraction, 1) }, 0.2)
	elseif current ~= fraction then
		fill.Size = UDim2.fromScale(fraction, 1)
	end
	if fillColor and fill.BackgroundColor3 ~= fillColor then
		fill.BackgroundColor3 = fillColor
	end
end

-- Caption above a value, e.g. CASH / $1,250. Returns (container, valueLabel, captionLabel).
-- options: caption, value, color, valueSize, brush (marker lettering for the value), align
function UIKit.Stat(props)
	local container = UIKit.Frame({
		Name = props.Name or "Stat",
		Size = props.Size or UDim2.fromOffset(100, 44),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	local align = props.align or Enum.TextXAlignment.Left
	local caption = UIKit.Caption({ Text = props.caption or "", Size = UDim2.new(1, 0, 0, 14), TextXAlignment = align, Parent = container })
	local value = UIKit.Text({
		Name = "Value",
		Text = props.value or "",
		size = props.valueSize or "Stat",
		weight = props.brush and "Brush" or "Heavy",
		color = props.color or "Text",
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 1, -14),
		TextXAlignment = align,
		Parent = container,
	})
	return container, value, caption
end

-- Screens & scaling ---------------------------------------------------------------------------------

local scales = setmetatable({}, { __mode = "k" }) -- [UIScale] = options or true
local currentScale = 1
local currentViewport

UIKit.ScaleChanged = Instance.new("BindableEvent")

local function computeScale(viewport)
	local reference = Theme.ReferenceResolution
	local ratio = math.min(viewport.X / reference.X, viewport.Y / reference.Y)
	return math.clamp(ratio * Theme.UIScale, Theme.MinScale, Theme.MaxScale)
end

-- The global scale, reduced for tall elements that must fit the screen height.
local function scaleFor(options)
	local scale = currentScale
	if type(options) == "table" and options.fitHeight and options.designHeight and currentViewport then
		scale = math.min(scale, currentViewport.Y * options.fitHeight / options.designHeight)
	end
	return math.max(scale, 0.3)
end

local function refreshScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
	if not viewport or viewport.X < 50 or viewport.Y < 50 then
		return -- camera not ready yet
	end
	if currentViewport == viewport then
		return
	end
	currentViewport = viewport
	currentScale = computeScale(viewport)
	for uiScale, options in pairs(scales) do
		uiScale.Scale = scaleFor(options)
	end
	UIKit.ScaleChanged:Fire(currentScale)
end

local watchedCamera
local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera and camera ~= watchedCamera then
		watchedCamera = camera
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
	end
	refreshScale()
end
watchCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
-- Safety net: resolution/window changes are cheap to re-check.
task.spawn(function()
	while true do
		task.wait(1)
		refreshScale()
	end
end)

function UIKit.GetScale()
	return currentScale
end

--[[
	Makes a GuiObject scale with the screen (around its AnchorPoint).
	options (optional): { fitHeight = 0.8, designHeight = 600 } never lets the
	scaled object be taller than fitHeight of the screen.
]]
function UIKit.AutoScale(guiObject, options)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ScreenScale"
	uiScale.Scale = scaleFor(options)
	uiScale.Parent = guiObject
	scales[uiScale] = options or true
	return uiScale
end

--[[
	A scaled screen-corner container. Build everything for one corner inside it.
	props: AnchorPoint, Position (use small offsets -- they are NOT scaled), Size
	(the design size of the contents), Name, Parent.
	options: fitHeight (0..1) -- cap the scale so the dock never exceeds that
	fraction of the screen height (for tall panels).
]]
function UIKit.Dock(props)
	local dock = UIKit.Frame(props)
	local options
	if props.fitHeight and props.Size then
		options = { fitHeight = props.fitHeight, designHeight = props.Size.Y.Offset }
	end
	UIKit.AutoScale(dock, options)
	return dock
end

-- A full-screen ScreenGui that draws under the Roblox top bar area too.
function UIKit.Screen(name, parent, displayOrder)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = displayOrder or 0
	screenGui.Parent = parent
	return screenGui
end

-- Keeps RunService referenced for components that animate per frame.
UIKit.RunService = RunService

return UIKit
