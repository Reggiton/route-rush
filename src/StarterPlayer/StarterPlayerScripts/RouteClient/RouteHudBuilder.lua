--[[
	RouteHudBuilder.lua

	Builds the route HUD in the same plain style as the original garage
	(dark panels, Gotham, grey buttons, green action buttons). Only BUILDS
	instances (plus two tiny helpers: toast() and results rows);
	RouteClient fills everything in.

	  top-center     timer | cash | level + XP | rep (| fares) + toast
	  top-left       Leave race button (in a race)
	  bottom-left    Ready card (lobby) / bus panel (in a race)
	  bottom-center  boarding panel (inside a stop bay)
	  bottom-right   speedometer (mph dial, ticks banded by boarding tier)
	  center         countdown, results
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boarding = require(Shared.Modules.Boarding)

local RouteHudBuilder = {}

local PANEL_BG = Color3.fromRGB(25, 25, 30)
local ROW_BG = Color3.fromRGB(40, 40, 45)
local MUTED = Color3.fromRGB(170, 170, 180)
local GREEN = Color3.fromRGB(120, 220, 140)
local YELLOW = Color3.fromRGB(250, 210, 60)
local BLUE = Color3.fromRGB(90, 160, 240)
local RED = Color3.fromRGB(230, 90, 80)
local ORANGE = Color3.fromRGB(240, 160, 90)

local TONES = {
	Positive = GREEN,
	Negative = Color3.fromRGB(240, 120, 100),
	Warning = ORANGE,
	Accent = YELLOW,
	Mustard = YELLOW,
	Rep = YELLOW,
	Info = BLUE,
}

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

local function frame(parent, name, size, position, props)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = PANEL_BG
	f.BorderSizePixel = 0
	for key, value in pairs(props or {}) do
		f[key] = value
	end
	f.Parent = parent
	return f
end

local function label(parent, name, text, size, position, props)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for key, value in pairs(props or {}) do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function button(parent, name, text, size, position, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color or ROW_BG
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 6)
	b:GetPropertyChangedSignal("Interactable"):Connect(function()
		b.TextTransparency = b.Interactable and 0 or 0.5
		b.BackgroundTransparency = b.Interactable and 0 or 0.4
	end)
	return b
end

-- A background bar with a fill frame; returns (bar, fill).
local function bar(parent, name, size, position, fillColor)
	local back = frame(parent, name, size, position, { BackgroundColor3 = Color3.fromRGB(55, 55, 60) })
	corner(back, 4)
	local fill = frame(back, "Fill", UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), { BackgroundColor3 = fillColor })
	corner(fill, 4)
	return back, fill
end

function RouteHudBuilder.Build(playerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RouteHud"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local hud = { screenGui = screenGui }

	-- Top bar -------------------------------------------------------------------------
	do
		local topBar = frame(screenGui, "TopBar", UDim2.fromOffset(560, 46), UDim2.new(0.5, 0, 0, 8), {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 0.15,
		})
		corner(topBar)

		local phase = label(topBar, "Phase", "", UDim2.fromOffset(180, 20), UDim2.fromOffset(12, 4), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
		})
		local timer = label(topBar, "Timer", "", UDim2.fromOffset(180, 18), UDim2.fromOffset(12, 24), {
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local cash = label(topBar, "Cash", "$0", UDim2.fromOffset(130, 30), UDim2.fromOffset(200, 8), {
			TextColor3 = GREEN,
		})
		local level = label(topBar, "Level", "Lv 1", UDim2.fromOffset(90, 20), UDim2.fromOffset(345, 4))
		local _, xpFill = bar(topBar, "XPBar", UDim2.fromOffset(90, 8), UDim2.fromOffset(345, 28), BLUE)
		local rep = label(topBar, "Rep", "Rep 0", UDim2.fromOffset(110, 30), UDim2.fromOffset(445, 8), {
			TextColor3 = YELLOW,
		})
		local _, progress = bar(topBar, "PhaseProgress", UDim2.new(1, -16, 0, 3), UDim2.new(0, 8, 1, -4), YELLOW)

		-- Fares (only while racing), attached to the right of the bar
		local fares = frame(topBar, "Fares", UDim2.fromOffset(120, 46), UDim2.new(1, 8, 0, 0), {
			BackgroundTransparency = 0.15,
			Visible = false,
		})
		corner(fares)
		label(fares, "Caption", "Fares", UDim2.fromOffset(100, 16), UDim2.fromOffset(10, 4), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
		})
		local faresValue = label(fares, "Value", "$0", UDim2.fromOffset(100, 22), UDim2.fromOffset(10, 20), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = GREEN,
		})

		hud.profile = { panel = topBar, cash = cash, level = level, xpFill = xpFill, rep = rep }
		hud.status = { panel = topBar, phase = phase, timer = timer, fares = fares, faresValue = faresValue, progress = progress }
	end

	-- Toast -----------------------------------------------------------------------------------
	do
		local toast = label(screenGui, "Toast", "", UDim2.fromOffset(460, 34), UDim2.new(0.5, -230, 0, 64), {
			BackgroundTransparency = 0.2,
			BackgroundColor3 = PANEL_BG,
			Visible = false,
		})
		corner(toast, 6)

		local token = 0
		function hud.toast(text, tone)
			token = token + 1
			local myToken = token
			toast.Text = text
			toast.TextColor3 = TONES[tone] or Color3.new(1, 1, 1)
			toast.Visible = true
			task.delay(2.5, function()
				if token == myToken then
					toast.Visible = false
				end
			end)
		end
	end

	-- Leave race (top-left, same spot as the Garage button) ---------------------------------------
	hud.leaveButton = button(screenGui, "LeaveRace", "Leave race", UDim2.fromOffset(120, 44), UDim2.new(0, 20, 0, 20), Color3.fromRGB(150, 50, 45))
	hud.leaveButton.Visible = false

	-- Ready card (bottom-left, lobby) ------------------------------------------------------------
	do
		local panel = frame(screenGui, "Ready", UDim2.fromOffset(260, 120), UDim2.new(0, 20, 1, -140), {
			BackgroundTransparency = 0.15,
		})
		corner(panel)
		local title = label(panel, "Title", "Next race", UDim2.fromOffset(240, 24), UDim2.fromOffset(10, 8), {
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local status = label(panel, "Status", "", UDim2.fromOffset(240, 20), UDim2.fromOffset(10, 34), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
			Font = Enum.Font.Gotham,
		})
		local readyButton = button(panel, "ReadyButton", "Ready up", UDim2.fromOffset(240, 46), UDim2.fromOffset(10, 64), Color3.fromRGB(50, 140, 70))
		hud.ready = { panel = panel, title = title, status = status, button = readyButton }
	end

	-- Bus panel (bottom-left, in a race) --------------------------------------------------------------
	do
		local panel = frame(screenGui, "Bus", UDim2.fromOffset(310, 150), UDim2.new(0, 20, 1, -170), {
			BackgroundTransparency = 0.15,
			Visible = false,
		})
		corner(panel)

		local function meter(captionText, y, fillColor)
			label(panel, captionText .. "Caption", captionText, UDim2.fromOffset(140, 18), UDim2.fromOffset(12, y), {
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = MUTED,
			})
			local value = label(panel, captionText .. "Value", "", UDim2.fromOffset(140, 18), UDim2.fromOffset(158, y), {
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			local _, fill = bar(panel, captionText .. "Bar", UDim2.fromOffset(286, 8), UDim2.fromOffset(12, y + 22), fillColor)
			return value, fill
		end

		local passengers, loadFill = meter("Passengers", 10, GREEN)
		local health, healthFill = meter("Health", 48, RED)
		local stats = label(panel, "Stats", "", UDim2.fromOffset(286, 16), UDim2.fromOffset(12, 90), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
			Font = Enum.Font.Gotham,
		})
		local problem = label(panel, "Problem", "", UDim2.fromOffset(286, 16), UDim2.fromOffset(12, 114), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = ORANGE,
			Visible = false,
		})

		hud.bus = {
			panel = panel,
			passengers = passengers,
			loadFill = loadFill,
			health = health,
			healthFill = healthFill,
			stats = stats,
			problem = problem,
		}
	end

	-- Speedometer (bottom-right) ----------------------------------------------------------------------------
	-- A real dial in mph. The tick marks are coloured by the boarding tiers from
	-- RouteConfig, so the gauge shows at a glance how slow you need to be to pick
	-- up 2, 4, or the whole crowd.
	do
		local PANEL_W, PANEL_H = 190, 212
		local DIAL = 168
		local START_ANGLE, END_ANGLE = -125, 125
		local MAX_MPH = 100
		local TICK_STEP, LABEL_STEP = 10, 20
		local TICK_RADIUS, LABEL_RADIUS, NEEDLE_LENGTH = 74, 55, 48

		local panel = frame(screenGui, "Speed", UDim2.fromOffset(PANEL_W, PANEL_H), UDim2.new(1, -PANEL_W - 20, 1, -PANEL_H - 20), {
			BackgroundTransparency = 0.15,
			Visible = false,
		})
		corner(panel, 14)

		local dial = frame(panel, "Dial", UDim2.fromOffset(DIAL, DIAL), UDim2.new(0.5, 0, 0, 8), {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
		})

		local function angleFor(mph)
			return START_ANGLE + math.clamp(mph / MAX_MPH, 0, 1) * (END_ANGLE - START_ANGLE)
		end

		-- Sit a child on the dial face. Angle 0 is straight up and grows
		-- clockwise; the child is rotated to line up radially.
		local function place(instance, angle, radius)
			local radians = math.rad(angle - 90)
			instance.AnchorPoint = Vector2.new(0.5, 0.5)
			instance.Position = UDim2.new(0.5, math.cos(radians) * radius, 0.5, math.sin(radians) * radius)
			instance.Rotation = angle
		end

		local tiers = Boarding.TiersBySpeed() -- slowest (most generous) first
		local BANDS = { GREEN, YELLOW, ORANGE }
		local function tickColor(mph)
			for i, tier in ipairs(tiers) do
				if mph <= tier.mph then
					return BANDS[math.min(i, #BANDS)]
				end
			end
			return Color3.fromRGB(120, 120, 130)
		end

		for mph = 0, MAX_MPH, TICK_STEP do
			local major = mph % LABEL_STEP == 0
			local tick = frame(dial, "Tick" .. mph, UDim2.fromOffset(major and 3 or 2, major and 13 or 8), UDim2.new(), {
				BackgroundColor3 = tickColor(mph),
				BackgroundTransparency = major and 0 or 0.35,
			})
			place(tick, angleFor(mph), TICK_RADIUS)

			if major then
				local mark = label(dial, "Mark" .. mph, tostring(mph), UDim2.fromOffset(26, 13), UDim2.new(), {
					TextColor3 = MUTED,
					Font = Enum.Font.Gotham,
				})
				place(mark, angleFor(mph), LABEL_RADIUS)
				mark.Rotation = 0 -- numbers stay upright
			end
		end

		local needle = frame(dial, "Needle", UDim2.fromOffset(3, NEEDLE_LENGTH), UDim2.fromScale(0.5, 0.5), {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = RED,
		})
		corner(needle, 2)
		needle.Rotation = START_ANGLE

		local hub = frame(dial, "Hub", UDim2.fromOffset(14, 14), UDim2.fromScale(0.5, 0.5), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(70, 70, 78),
		})
		corner(hub, 7)

		local value = label(panel, "Value", "0", UDim2.fromOffset(70, 26), UDim2.new(0.5, -42, 0, 174), {
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBlack,
		})
		label(panel, "Unit", "MPH", UDim2.fromOffset(36, 14), UDim2.new(0.5, 32, 0, 182), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
			Font = Enum.Font.Gotham,
		})
		local sliding = label(panel, "Sliding", "SLIDING", UDim2.new(1, -20, 0, 13), UDim2.new(0, 10, 0, 194), {
			TextColor3 = ORANGE,
			Visible = false,
		})

		local speed = { panel = panel, needle = needle, value = value, sliding = sliding }

		function speed.set(mph)
			needle.Rotation = angleFor(mph)
			local rounded = tostring(math.floor(mph + 0.5))
			if value.Text ~= rounded then
				value.Text = rounded
			end
		end

		hud.speed = speed
	end

	-- Boarding panel (bottom-center) --------------------------------------------------------------------------
	do
		local panel = frame(screenGui, "BoardPanel", UDim2.fromOffset(380, 116), UDim2.new(0.5, -190, 1, -136), {
			BackgroundTransparency = 0.1,
			Visible = false,
		})
		corner(panel)
		local title = label(panel, "Title", "", UDim2.fromOffset(222, 24), UDim2.fromOffset(10, 8), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = YELLOW,
		})
		local subtitle = label(panel, "Subtitle", "", UDim2.fromOffset(222, 16), UDim2.fromOffset(10, 34), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
			Font = Enum.Font.Gotham,
		})
		label(panel, "RateCaption", "Room at this speed", UDim2.fromOffset(222, 14), UDim2.fromOffset(10, 54), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
			Font = Enum.Font.Gotham,
		})
		local _, rateFill = bar(panel, "RateBar", UDim2.fromOffset(222, 8), UDim2.fromOffset(10, 70), GREEN)
		local hint = label(panel, "Hint", "", UDim2.fromOffset(222, 18), UDim2.fromOffset(10, 86), {
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
		})

		local boardButton = button(panel, "Board", "", UDim2.fromOffset(128, 96), UDim2.fromOffset(242, 10), Color3.fromRGB(50, 140, 70))
		local buttonLabel = label(boardButton, "Label", "Board [E]", UDim2.new(1, -12, 0, 30), UDim2.new(0, 6, 0, 22))
		local boardedCount = label(boardButton, "Boarded", "", UDim2.new(1, -12, 0, 18), UDim2.new(0, 6, 0, 58), {
			Font = Enum.Font.Gotham,
		})

		hud.board = {
			panel = panel,
			title = title,
			subtitle = subtitle,
			rateFill = rateFill,
			hint = hint,
			button = boardButton,
			buttonLabel = buttonLabel,
			boardedCount = boardedCount,
		}
	end

	-- Countdown (center) ---------------------------------------------------------------------------------------
	do
		local countdownLabel = label(screenGui, "Countdown", "", UDim2.fromOffset(300, 140), UDim2.new(0.5, -150, 0.35, -70), {
			Font = Enum.Font.GothamBlack,
			TextStrokeTransparency = 0.3,
			Visible = false,
		})
		local pop = Instance.new("UIScale")
		pop.Parent = countdownLabel
		hud.countdown = { label = countdownLabel, pop = pop }
	end

	-- Results (center) -----------------------------------------------------------------------------------------
	do
		local panel = frame(screenGui, "Results", UDim2.fromOffset(420, 400), UDim2.new(0.5, 0, 0.5, 0), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 0.05,
			Visible = false,
		})
		corner(panel, 12)
		label(panel, "Title", "ROUTE COMPLETE", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 12), {
			Font = Enum.Font.GothamBlack,
			TextColor3 = YELLOW,
		})
		local total = label(panel, "Total", "", UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 56), {
			TextColor3 = GREEN,
		})
		local rows = frame(panel, "Rows", UDim2.new(1, -40, 0, 270), UDim2.fromOffset(20, 102), {
			BackgroundTransparency = 1,
		})
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 4)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = rows
		local footer = label(panel, "Footer", "Returning to lobby", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 1, -26), {
			TextColor3 = MUTED,
			Font = Enum.Font.Gotham,
		})

		local rowOrder = 0
		local results = { panel = panel, total = total, footer = footer }

		function results.clear()
			rowOrder = 0
			for _, child in ipairs(rows:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
		end

		function results.addRow(labelText, valueText, tone)
			rowOrder = rowOrder + 1
			local row = frame(rows, "Row", UDim2.new(1, 0, 0, 22), UDim2.new(), {
				BackgroundTransparency = 1,
				LayoutOrder = rowOrder,
			})
			label(row, "Label", labelText, UDim2.new(0.62, 0, 1, 0), UDim2.new(), {
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = TONES[tone] or MUTED,
				Font = tone and Enum.Font.GothamBold or Enum.Font.Gotham,
			})
			label(row, "Value", valueText or "", UDim2.new(0.38, 0, 1, 0), UDim2.fromScale(0.62, 0), {
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = TONES[tone] or Color3.new(1, 1, 1),
			})
		end

		hud.results = results
	end

	return hud
end

return RouteHudBuilder
