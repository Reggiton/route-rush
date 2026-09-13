--[[
	RouteHudBuilder.lua

	Builds the always-on HUD (phase timer, cash, level/XP, reputation)
	and the in-route panels (bus status, boarding, countdown, results).
	Only BUILDS instances; RouteClient fills them in.
]]

local RouteHudBuilder = {}

local PANEL_BG = Color3.fromRGB(25, 25, 30)
local ROW_BG = Color3.fromRGB(45, 45, 52)
local MUTED = Color3.fromRGB(170, 170, 180)

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
	b.Parent = parent
	corner(b, 6)
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

	-- Top bar -------------------------------------------------------------------------
	local topBar = frame(screenGui, "TopBar", UDim2.fromOffset(560, 46), UDim2.new(0.5, 0, 0, 8), {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0.15,
	})
	corner(topBar)
	local phaseLabel = label(topBar, "Phase", "", UDim2.fromOffset(180, 20), UDim2.fromOffset(12, 4), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED,
	})
	local timerLabel = label(topBar, "Timer", "", UDim2.fromOffset(180, 18), UDim2.fromOffset(12, 24), {
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local cashLabel = label(topBar, "Cash", "$0", UDim2.fromOffset(130, 30), UDim2.fromOffset(200, 8), {
		TextColor3 = Color3.fromRGB(120, 220, 140),
	})
	local levelLabel = label(topBar, "Level", "Lv 1", UDim2.fromOffset(90, 20), UDim2.fromOffset(345, 4))
	local _, xpFill = bar(topBar, "XPBar", UDim2.fromOffset(90, 8), UDim2.fromOffset(345, 28), Color3.fromRGB(90, 160, 240))
	local repLabel = label(topBar, "Rep", "Rep 0", UDim2.fromOffset(110, 30), UDim2.fromOffset(445, 8), {
		TextColor3 = Color3.fromRGB(250, 210, 60),
	})

	-- Run panel (bottom-left) --------------------------------------------------------------
	local runPanel = frame(screenGui, "RunPanel", UDim2.fromOffset(310, 176), UDim2.new(0, 20, 1, -196), {
		BackgroundTransparency = 0.15,
		Visible = false,
	})
	corner(runPanel)
	local speedLabel = label(runPanel, "Speed", "0", UDim2.fromOffset(120, 34), UDim2.fromOffset(12, 8), {
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local faresLabel = label(runPanel, "Fares", "$0", UDim2.fromOffset(160, 24), UDim2.fromOffset(140, 12), {
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(120, 220, 140),
	})
	local passengersLabel = label(runPanel, "Passengers", "Passengers 0/0", UDim2.fromOffset(286, 18), UDim2.fromOffset(12, 48), {
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local _, loadFill = bar(runPanel, "LoadBar", UDim2.fromOffset(286, 8), UDim2.fromOffset(12, 70), Color3.fromRGB(120, 220, 140))
	local healthLabel = label(runPanel, "Health", "Health", UDim2.fromOffset(286, 18), UDim2.fromOffset(12, 84), {
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local _, healthFill = bar(runPanel, "HealthBar", UDim2.fromOffset(286, 8), UDim2.fromOffset(12, 106), Color3.fromRGB(230, 90, 80))
	local streakLabel = label(runPanel, "Streak", "", UDim2.fromOffset(286, 16), UDim2.fromOffset(12, 120), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED,
		Font = Enum.Font.Gotham,
	})
	local dropArrow = label(runPanel, "DropArrow", "▲", UDim2.fromOffset(30, 30), UDim2.fromOffset(12, 140), {
		TextColor3 = Color3.fromRGB(250, 210, 60),
	})
	local dropLabel = label(runPanel, "Drop", "", UDim2.fromOffset(250, 18), UDim2.fromOffset(48, 146), {
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
	})

	-- Boarding panel (bottom-centre) -----------------------------------------------------------
	local boardPanel = frame(screenGui, "BoardPanel", UDim2.fromOffset(380, 116), UDim2.new(0.5, 0, 1, -136), {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	corner(boardPanel)
	local boardTitle = label(boardPanel, "Title", "", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 8))
	local boardMinus = button(boardPanel, "Minus", "−  [Z]", UDim2.fromOffset(80, 36), UDim2.fromOffset(10, 38))
	local boardCount = label(boardPanel, "Count", "0", UDim2.fromOffset(60, 36), UDim2.fromOffset(96, 38))
	local boardPlus = button(boardPanel, "Plus", "+  [X]", UDim2.fromOffset(80, 36), UDim2.fromOffset(162, 38))
	local boardButton = button(boardPanel, "Board", "Board [E]", UDim2.fromOffset(118, 36), UDim2.fromOffset(252, 38), Color3.fromRGB(50, 140, 70))
	local boardHint = label(boardPanel, "Hint", "", UDim2.new(1, -20, 0, 16), UDim2.fromOffset(10, 88), {
		Font = Enum.Font.Gotham,
		TextColor3 = MUTED,
	})

	-- Countdown / toast ---------------------------------------------------------------------------
	local countdownLabel = label(screenGui, "Countdown", "", UDim2.fromOffset(300, 140), UDim2.new(0.5, -150, 0.35, -70), {
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.3,
		Visible = false,
	})
	local toast = label(screenGui, "Toast", "", UDim2.fromOffset(460, 34), UDim2.new(0.5, -230, 0, 64), {
		BackgroundTransparency = 0.2,
		BackgroundColor3 = PANEL_BG,
		Visible = false,
	})
	corner(toast, 6)

	-- Results -----------------------------------------------------------------------------------------
	local resultsFrame = frame(screenGui, "Results", UDim2.fromOffset(420, 380), UDim2.new(0.5, 0, 0.5, 0), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	corner(resultsFrame, 12)
	label(resultsFrame, "Title", "ROUTE COMPLETE", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 12), {
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(250, 210, 60),
	})
	local resultsBody = label(resultsFrame, "Body", "", UDim2.new(1, -40, 1, -110), UDim2.fromOffset(20, 64), {
		TextScaled = false,
		TextSize = 20,
		Font = Enum.Font.Gotham,
		RichText = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local resultsTotal = label(resultsFrame, "Total", "", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 1, -46), {
		TextColor3 = Color3.fromRGB(120, 220, 140),
	})

	return {
		screenGui = screenGui,
		phaseLabel = phaseLabel,
		timerLabel = timerLabel,
		cashLabel = cashLabel,
		levelLabel = levelLabel,
		xpFill = xpFill,
		repLabel = repLabel,

		runPanel = runPanel,
		speedLabel = speedLabel,
		faresLabel = faresLabel,
		passengersLabel = passengersLabel,
		loadFill = loadFill,
		healthLabel = healthLabel,
		healthFill = healthFill,
		streakLabel = streakLabel,
		dropArrow = dropArrow,
		dropLabel = dropLabel,

		boardPanel = boardPanel,
		boardTitle = boardTitle,
		boardMinus = boardMinus,
		boardCount = boardCount,
		boardPlus = boardPlus,
		boardButton = boardButton,
		boardHint = boardHint,

		countdownLabel = countdownLabel,
		toast = toast,

		resultsFrame = resultsFrame,
		resultsBody = resultsBody,
		resultsTotal = resultsTotal,
	}
end

return RouteHudBuilder
