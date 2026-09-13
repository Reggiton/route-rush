--[[
	UIKit.lua

	Small component library so every screen looks consistent. All styling
	comes from UITheme.lua.

	Every constructor takes one props table:
	  - PascalCase keys are applied as Roblox properties (Size, Position,
	    AnchorPoint, Name, LayoutOrder, Visible, Text, ...). Parent is set last.
	  - lowercase keys are UIKit options (radius, stroke, size, weight,
	    color, variant, padding).
]]

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
	stroke.Color = color(props.color, "Stroke")
	stroke.Transparency = props.transparency or Theme.StrokeTransparency
	stroke.Thickness = props.thickness or 1
	stroke.Parent = parent
	return stroke
end

-- padding: number (all sides) or { top, right, bottom, left }
function UIKit.Padding(parent, padding)
	local p = Instance.new("UIPadding")
	local top, right, bottom, left
	if type(padding) == "table" then
		top, right, bottom, left = padding[1], padding[2], padding[3], padding[4]
	else
		top, right, bottom, left = padding, padding, padding, padding
	end
	p.PaddingTop = UDim.new(0, top or 0)
	p.PaddingRight = UDim.new(0, right or 0)
	p.PaddingBottom = UDim.new(0, bottom or 0)
	p.PaddingLeft = UDim.new(0, left or 0)
	p.Parent = parent
	return p
end

-- props: direction ("Vertical"/"Horizontal"), gap, align ("Left"/"Center"/"Right"), valign
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

-- Building blocks -------------------------------------------------------------------------------

-- Invisible container.
function UIKit.Frame(props)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	return apply(frame, props)
end

-- Dark glass surface with rounded corners and a hairline border.
-- options: radius, padding, stroke (false to disable), tone ("Surface"/"SurfaceAlt"/"SurfaceRaised")
function UIKit.Panel(props)
	local panel = Instance.new("Frame")
	panel.BorderSizePixel = 0
	panel.BackgroundColor3 = color(props.tone, "Surface")
	panel.BackgroundTransparency = props.tone == "SurfaceRaised" and 0 or Theme.SurfaceTransparency
	apply(panel, props)
	UIKit.Corner(panel, props.radius or Theme.Radius.Large)
	if props.stroke ~= false then
		UIKit.Stroke(panel)
	end
	if props.padding then
		UIKit.Padding(panel, props.padding)
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

-- Small uppercase caption ("CASH", "BOARDING RATE").
function UIKit.Caption(props)
	props.size = props.size or "Caption"
	props.weight = props.weight or "Bold"
	props.color = props.color or "TextMuted"
	if props.Text then
		props.Text = string.upper(props.Text)
	end
	return UIKit.Text(props)
end

local VARIANTS = {
	primary = { bg = "Accent", text = "OnAccent" },
	success = { bg = "Positive", text = "OnAccent" },
	danger = { bg = "Negative", text = "Text" },
	secondary = { bg = "SurfaceRaised", text = "Text" },
	ghost = { bg = "SurfaceRaised", text = "TextMuted", transparency = 0.6 },
}

-- options: variant ("primary"/"success"/"danger"/"secondary"/"ghost"), radius, size
-- Hover lightens, press shrinks slightly, Interactable = false dims it.
function UIKit.Button(props)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.FontFace = Theme.Fonts.Bold
	button.TextSize = type(props.size) == "number" and props.size or Theme.TextSize[props.size or "Body"]
	apply(button, props)
	UIKit.Corner(button, props.radius or Theme.Radius.Medium)

	local pressScale = Instance.new("UIScale")
	pressScale.Name = "PressScale"
	pressScale.Parent = button

	local hovered = false
	local function refresh(instant)
		local variant = VARIANTS[button:GetAttribute("Variant")] or VARIANTS.secondary
		local base = Theme.Colors[variant.bg]
		local enabled = button.Interactable
		local goals = {
			BackgroundColor3 = (enabled and hovered) and base:Lerp(Color3.new(1, 1, 1), 0.14) or base,
			BackgroundTransparency = enabled and (variant.transparency or 0) or 0.6,
			TextColor3 = Theme.Colors[variant.text],
			TextTransparency = enabled and 0 or 0.45,
		}
		if instant then
			for key, value in pairs(goals) do
				button[key] = value
			end
		else
			UIKit.Tween(button, goals, 0.12)
		end
	end

	button:SetAttribute("Variant", props.variant or "secondary")
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
			UIKit.Tween(pressScale, { Scale = 0.96 }, 0.08)
		end
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(pressScale, { Scale = 1 }, 0.12, Enum.EasingStyle.Back)
	end)
	button:GetPropertyChangedSignal("Interactable"):Connect(function()
		refresh()
	end)
	button:GetAttributeChangedSignal("Variant"):Connect(function()
		refresh()
	end)

	return button
end

function UIKit.SetVariant(button, variant)
	if button:GetAttribute("Variant") ~= variant then
		button:SetAttribute("Variant", variant)
	end
end

-- Rounded progress bar. Returns (track, fill). options: color
function UIKit.Bar(props)
	local track = Instance.new("Frame")
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Theme.Colors.Track
	track.ClipsDescendants = true
	apply(track, props)
	UIKit.Corner(track, Theme.Radius.Pill)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = color(props.color, "Accent")
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	UIKit.Corner(fill, Theme.Radius.Pill)

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

-- A caption above a big value, e.g. CASH / $1,250. Returns (container, valueLabel, captionLabel).
function UIKit.Stat(props)
	local container = UIKit.Frame({
		Name = props.Name or "Stat",
		Size = props.Size or UDim2.fromOffset(100, 42),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	local caption = UIKit.Caption({ Text = props.caption or "", Size = UDim2.new(1, 0, 0, 14), Parent = container })
	local value = UIKit.Text({
		Name = "Value",
		Text = props.value or "",
		size = props.valueSize or "Stat",
		weight = "Heavy",
		color = props.color or "Text",
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 1, -14),
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		Parent = container,
	})
	caption.TextXAlignment = props.align or Enum.TextXAlignment.Left
	return container, value, caption
end

-- Screen scaling ------------------------------------------------------------------------------------

local scales = setmetatable({}, { __mode = "k" })

local function currentScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Theme.ReferenceResolution
	local ratio = math.min(viewport.X / Theme.ReferenceResolution.X, viewport.Y / Theme.ReferenceResolution.Y)
	return math.clamp(ratio, Theme.MinScale, Theme.MaxScale)
end

local function watchCamera(camera)
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local scale = currentScale()
			for uiScale in pairs(scales) do
				uiScale.Scale = scale
			end
		end)
	end
end
watchCamera(workspace.CurrentCamera)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera(workspace.CurrentCamera)
end)

-- Makes a HUD cluster scale with the screen size (around its AnchorPoint).
function UIKit.AutoScale(guiObject)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ScreenScale"
	uiScale.Scale = currentScale()
	uiScale.Parent = guiObject
	scales[uiScale] = true
	return uiScale
end

-- A full-screen ScreenGui.
function UIKit.Screen(name, parent, displayOrder)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = displayOrder or 0
	screenGui.Parent = parent
	return screenGui
end

return UIKit
