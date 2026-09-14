--[[
	StopPanel.lua

	The stops on YOUR track, listed down the left edge of the screen instead
	of floating on top of the stops themselves:

	    NEXT STOPS
	    STOP 3               120 studs
	    8 waiting                 LEFT
	    Drop off 2 · 0:19

	Rows are the stops ahead of the bus, nearest first, plus any stop you are
	carrying passengers for -- those have a deadline, so they stay listed even
	once they are behind you. The bay you are parked in is pinned to the top.

	The drop-off line counts down to the soonest deadline (orange when close,
	red "LATE" when missed) and the most urgent stop keeps a yellow outline.

	Driven by RouteClient: SetTrack(trackId, bus) when your bus appears,
	SetRunState(runState, receivedAt) on every run-state update, Clear() when
	the race ends.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local UI = script.Parent.Parent:WaitForChild("UI")
local Format = require(UI:WaitForChild("Format"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StopPanel = {}

local TAG = "StopMarker"
local URGENT_SECONDS = 15
local MAX_ROWS = 4
local REFRESH_SECONDS = 0.1
-- A stop counts as "ahead" until it is this far behind the bus, so the bay you
-- are pulling out of does not vanish the instant you clear it.
local BEHIND_TOLERANCE = 30

local PANEL_WIDTH = 250
local ROW_TALL = 60 -- with a drop-off line
local ROW_SHORT = 40 -- without

local PANEL_BG = Color3.fromRGB(25, 25, 30)
local ROW_BG = Color3.fromRGB(40, 40, 45)
local MUTED = Color3.fromRGB(170, 170, 180)
local YELLOW = Color3.fromRGB(250, 210, 60)
local GREEN = Color3.fromRGB(50, 140, 70)
local ORANGE = Color3.fromRGB(200, 120, 40)
local RED = Color3.fromRGB(170, 50, 45)

local activeTrackId
local activeBus
local markers = {} -- [marker] = stopIndex
local drops = {} -- [stopIndex] = { count, deadlineAt }
local urgentIndex
local atStopIndex = 0
local connections = {}
local screenGui, listFrame, emptyLabel
local rows = {} -- pooled row widgets, rows[1] is the top of the list
local sinceRefresh = 0

local function setText(label, text)
	if label.Text ~= text then
		label.Text = text
	end
end

local function label(parent, name, text, size, position, props)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for key, value in pairs(props or {}) do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = instance
end

local function buildRow(order)
	local row = Instance.new("Frame")
	row.Name = "Row" .. order
	row.Size = UDim2.new(1, 0, 0, ROW_SHORT)
	row.BackgroundColor3 = ROW_BG
	row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Visible = false
	row.Parent = listFrame
	corner(row)

	local outline = Instance.new("UIStroke")
	outline.Color = YELLOW
	outline.Thickness = 2
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Enabled = false
	outline.Parent = row

	local title = label(row, "Title", "STOP 0", UDim2.fromOffset(110, 17), UDim2.fromOffset(10, 6), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = YELLOW,
		Font = Enum.Font.GothamBlack,
	})
	local distance = label(row, "Distance", "", UDim2.fromOffset(94, 13), UDim2.fromOffset(PANEL_WIDTH - 124, 8), {
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = MUTED,
		Font = Enum.Font.Gotham,
	})
	local waiting = label(row, "Waiting", "0 waiting", UDim2.fromOffset(120, 13), UDim2.fromOffset(10, 23), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED,
		Font = Enum.Font.Gotham,
	})
	-- Which kerb the bay is against. Stops alternate, so this is the difference
	-- between pulling in and driving straight past.
	local side = label(row, "Side", "", UDim2.fromOffset(94, 13), UDim2.fromOffset(PANEL_WIDTH - 124, 23), {
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = YELLOW,
		Font = Enum.Font.GothamBold,
	})

	local drop = label(row, "Drop", "", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 38), {
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 0.1,
		BackgroundColor3 = GREEN,
		Visible = false,
	})
	corner(drop, 4)
	local dropPadding = Instance.new("UIPadding")
	dropPadding.PaddingLeft = UDim.new(0, 6)
	dropPadding.PaddingRight = UDim.new(0, 6)
	dropPadding.Parent = drop

	return {
		row = row,
		outline = outline,
		title = title,
		distance = distance,
		waiting = waiting,
		side = side,
		drop = drop,
	}
end

local function build()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StopPanel"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 20, 0.5, 0)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = PANEL_BG
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	corner(panel, 8)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	label(panel, "Header", "NEXT STOPS", UDim2.new(1, 0, 0, 16), UDim2.new(), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED,
		LayoutOrder = 0,
	})

	listFrame = Instance.new("Frame")
	listFrame.Name = "Rows"
	listFrame.Size = UDim2.new(1, 0, 0, 0)
	listFrame.AutomaticSize = Enum.AutomaticSize.Y
	listFrame.BackgroundTransparency = 1
	listFrame.LayoutOrder = 1
	listFrame.Parent = panel

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = listFrame

	for order = 1, MAX_ROWS do
		rows[order] = buildRow(order)
	end

	emptyLabel = label(panel, "Empty", "No stops ahead", UDim2.new(1, 0, 0, 16), UDim2.new(), {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED,
		Font = Enum.Font.Gotham,
		LayoutOrder = 2,
		Visible = false,
	})
end

-- The stops worth listing, nearest first: everything in front of the bus, plus
-- any stop you owe a drop-off to, plus the bay you are parked in.
local function orderStops()
	local busPart = activeBus and activeBus.Parent and activeBus.PrimaryPart
	local busPosition = busPart and busPart.Position
	local look = busPart and busPart.CFrame.LookVector

	local ordered = {}
	local anyAhead = false

	for marker, index in pairs(markers) do
		if marker:IsDescendantOf(workspace) then
			local distance, ahead = 0, true
			if busPosition then
				local offset = marker.Position - busPosition
				distance = offset.Magnitude
				ahead = offset:Dot(look) > -BEHIND_TOLERANCE
			end
			anyAhead = anyAhead or ahead
			if ahead or drops[index] or index == atStopIndex then
				table.insert(ordered, { marker = marker, index = index, distance = distance })
			end
		end
	end

	-- Turned around with nothing in front of you: list everything instead.
	if not anyAhead then
		ordered = {}
		for marker, index in pairs(markers) do
			if marker:IsDescendantOf(workspace) then
				local distance = busPosition and (marker.Position - busPosition).Magnitude or 0
				table.insert(ordered, { marker = marker, index = index, distance = distance })
			end
		end
	end

	table.sort(ordered, function(a, b)
		-- The bay you are parked in always leads the list.
		if (a.index == atStopIndex) ~= (b.index == atStopIndex) then
			return a.index == atStopIndex
		end
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.index < b.index
	end)

	return ordered
end

local function refresh(now)
	local ordered = orderStops()

	for order, widgets in ipairs(rows) do
		local entry = ordered[order]
		if not entry then
			widgets.row.Visible = false
		else
			widgets.row.Visible = true
			-- Stops alternate kerbs, so which side this one is on matters as much
			-- as how far away it is: you have to be in that lane to pull in.
			local side = (entry.marker:GetAttribute("Side") or -1) >= 0 and "RIGHT" or "LEFT"
			setText(widgets.title, "STOP " .. entry.index)
			setText(widgets.side, side)
			setText(widgets.waiting, (entry.marker:GetAttribute("Waiting") or 0) .. " waiting")
			setText(widgets.distance, entry.index == atStopIndex and "here" or string.format("%d studs", entry.distance))
			widgets.outline.Enabled = entry.index == urgentIndex

			local drop = drops[entry.index]
			widgets.drop.Visible = drop ~= nil
			widgets.row.Size = UDim2.new(1, 0, 0, drop and ROW_TALL or ROW_SHORT)

			if drop then
				local remaining = drop.deadlineAt - now
				if remaining > 0 then
					setText(widgets.drop, string.format("Drop off %d · %s", drop.count, Format.Time(remaining)))
					widgets.drop.BackgroundColor3 = remaining <= URGENT_SECONDS and ORANGE or GREEN
				else
					setText(widgets.drop, string.format("Drop off %d · LATE", drop.count))
					widgets.drop.BackgroundColor3 = RED
				end
			end
		end
	end

	emptyLabel.Visible = #ordered == 0
end

local function addMarker(marker)
	if markers[marker] or not activeTrackId or marker:GetAttribute("TrackId") ~= activeTrackId then
		return
	end
	if not marker:IsDescendantOf(workspace) then
		return
	end
	markers[marker] = marker:GetAttribute("StopIndex") or 0
end

local function removeMarker(marker)
	markers[marker] = nil
end

-- List the stops of one track (nil clears). bus is your bus model, used to work
-- out which stops are ahead of you and how far away they are.
function StopPanel.SetTrack(trackId, bus)
	if trackId == activeTrackId and bus == activeBus then
		return
	end
	StopPanel.Clear()
	activeTrackId = trackId
	activeBus = bus
	if not trackId then
		return
	end

	if not screenGui then
		build()
	end
	screenGui.Enabled = true

	for _, marker in ipairs(CollectionService:GetTagged(TAG)) do
		addMarker(marker)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(TAG):Connect(addMarker))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeMarker))
	table.insert(connections, RunService.RenderStepped:Connect(function(delta)
		sinceRefresh = sinceRefresh + delta
		if sinceRefresh < REFRESH_SECONDS then
			return
		end
		sinceRefresh = 0
		refresh(os.clock())
	end))

	refresh(os.clock())
end

-- state: the RunStateUpdated payload, receivedAt: os.clock() when it arrived.
function StopPanel.SetRunState(state, receivedAt)
	drops = {}
	urgentIndex = nil
	atStopIndex = state and state.atStop or 0

	local soonest = math.huge
	for _, drop in ipairs(state and state.drops or {}) do
		local deadlineAt = receivedAt + drop.soonestDeadline
		drops[drop.index] = { count = drop.count, deadlineAt = deadlineAt }
		if deadlineAt < soonest then
			soonest = deadlineAt
			urgentIndex = drop.index
		end
	end
end

function StopPanel.Clear()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}
	markers = {}
	drops = {}
	urgentIndex = nil
	atStopIndex = 0
	activeTrackId = nil
	activeBus = nil
	sinceRefresh = 0
	if screenGui then
		screenGui.Enabled = false
		for _, widgets in ipairs(rows) do
			widgets.row.Visible = false
		end
	end
end

return StopPanel
