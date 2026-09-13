--[[
	StopBillboards.lua

	A small taped card above every stop on YOUR track, visible only to you:

	    STOP 3                  9 waiting
	    [ DROP OFF 4 ]               0:42

	The drop-off row appears when you're carrying passengers for that stop,
	with a live countdown to the soonest deadline (amber when close, red
	"LATE" when missed). Stops with drop-offs show through walls, and the
	most urgent one gets a mustard border. Cards scale with the screen
	like the rest of the UI (Theme.BillboardScale shrinks or grows them).

	Driven by RouteClient: SetTrack(trackId) when your bus appears,
	SetDrops(runState.drops, receivedAt) on every run-state update, Clear()
	when the race ends.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local UI = script.Parent.Parent:WaitForChild("UI")
local UIKit = require(UI:WaitForChild("UIKit"))
local Format = require(UI:WaitForChild("Format"))
local Theme = UIKit.Theme

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StopBillboards = {}

local TAG = "StopMarker"
local URGENT_SECONDS = 15
local BASE_SIZE = Vector2.new(190, 78)
local SIZE_FACTOR = 0.75 -- billboards read fine a bit smaller than HUD panels

local activeTrackId
local cards = {} -- [marker] = card
local drops = {} -- [stopIndex] = { count, deadlineAt }
local urgentIndex
local connections = {}

local function setText(label, text)
	if label.Text ~= text then
		label.Text = text
	end
end

local function applyScale(card)
	local scale = UIKit.GetScale() * SIZE_FACTOR
	card.gui.Size = UDim2.fromOffset(BASE_SIZE.X * scale, BASE_SIZE.Y * scale)
	card.scale.Scale = scale
end

local function buildCard(marker)
	local index = marker:GetAttribute("StopIndex") or 0

	local gui = Instance.new("BillboardGui")
	gui.Name = "StopCard_" .. index
	gui.Adornee = marker
	gui.ResetOnSpawn = false
	gui.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
	gui.MaxDistance = 1400
	gui.LightInfluence = 0
	gui.ClipsDescendants = false
	gui.Parent = playerGui

	local holder = UIKit.Frame({ Size = UDim2.fromOffset(BASE_SIZE.X, BASE_SIZE.Y), Parent = gui })
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	local panel = UIKit.Panel({
		Size = UDim2.fromScale(1, 1),
		padding = { 8, 12, 8, 14 },
		tape = { "TopLeft" },
		Parent = holder,
	})
	local stroke = panel:FindFirstChildOfClass("UIStroke")

	UIKit.Brush({
		Text = "Stop " .. index,
		size = 22,
		color = "Mustard",
		Size = UDim2.new(0.55, 0, 0, 26),
		Parent = panel,
	})
	local waiting = UIKit.Text({
		size = "Small",
		weight = "Bold",
		color = "TextMuted",
		Size = UDim2.new(0.45, 0, 0, 26),
		Position = UDim2.fromScale(0.55, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})

	local row = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 32), Parent = panel })
	local chip = UIKit.Frame({
		BackgroundTransparency = 0.05,
		BackgroundColor3 = Theme.Colors.Tape,
		Size = UDim2.new(0, 104, 1, 0),
		Rotation = -2,
		Parent = row,
	})
	local chipText = UIKit.Brush({
		size = 15,
		color = "Ink",
		tilt = 0,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = chip,
	})
	local timer = UIKit.Text({
		size = 22,
		weight = "Heavy",
		Size = UDim2.new(1, -110, 1, 0),
		Position = UDim2.fromOffset(110, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	local empty = UIKit.Text({
		Text = "No drop-offs",
		size = "Small",
		color = "TextDim",
		Size = UDim2.fromScale(1, 1),
		Parent = row,
	})

	local card = {
		marker = marker,
		index = index,
		gui = gui,
		scale = scale,
		stroke = stroke,
		waiting = waiting,
		chip = chip,
		chipText = chipText,
		timer = timer,
		empty = empty,
	}
	applyScale(card)
	return card
end

local function refreshCard(card, now)
	setText(card.waiting, string.format("%d waiting", card.marker:GetAttribute("Waiting") or 0))

	local drop = drops[card.index]
	card.chip.Visible = drop ~= nil
	card.timer.Visible = drop ~= nil
	card.empty.Visible = drop == nil
	card.gui.AlwaysOnTop = drop ~= nil

	if drop then
		setText(card.chipText, "Drop off " .. drop.count)
		local remaining = drop.deadlineAt - now
		if remaining > 0 then
			setText(card.timer, Format.Time(remaining))
			card.timer.TextColor3 = remaining <= URGENT_SECONDS and Theme.Colors.Warning or Theme.Colors.Text
		else
			setText(card.timer, "LATE")
			card.timer.TextColor3 = Theme.Colors.Negative
		end
	end

	if card.stroke then
		local urgent = card.index == urgentIndex
		card.stroke.Color = urgent and Theme.Colors.Mustard or Theme.Colors.PanelEdge
		card.stroke.Transparency = urgent and 0 or 0.15
		card.stroke.Thickness = urgent and 3 or 2
	end
end

local function addMarker(marker)
	if cards[marker] or not activeTrackId or marker:GetAttribute("TrackId") ~= activeTrackId then
		return
	end
	if not marker:IsDescendantOf(workspace) then
		return
	end
	cards[marker] = buildCard(marker)
end

local function removeMarker(marker)
	local card = cards[marker]
	if card then
		card.gui:Destroy()
		cards[marker] = nil
	end
end

-- Show cards for the stops of one track (nil clears).
function StopBillboards.SetTrack(trackId)
	if trackId == activeTrackId then
		return
	end
	StopBillboards.Clear()
	activeTrackId = trackId
	if not trackId then
		return
	end

	for _, marker in ipairs(CollectionService:GetTagged(TAG)) do
		addMarker(marker)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(TAG):Connect(addMarker))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeMarker))
	table.insert(connections, UIKit.ScaleChanged.Event:Connect(function()
		for _, card in pairs(cards) do
			applyScale(card)
		end
	end))
	table.insert(connections, RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, card in pairs(cards) do
			refreshCard(card, now)
		end
	end))
end

-- dropList: runState.drops ({ index, count, soonestDeadline (seconds) }), receivedAt: os.clock()
function StopBillboards.SetDrops(dropList, receivedAt)
	drops = {}
	urgentIndex = nil
	local soonest = math.huge
	for _, drop in ipairs(dropList or {}) do
		local deadlineAt = receivedAt + drop.soonestDeadline
		drops[drop.index] = { count = drop.count, deadlineAt = deadlineAt }
		if deadlineAt < soonest then
			soonest = deadlineAt
			urgentIndex = drop.index
		end
	end
end

function StopBillboards.Clear()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}
	for marker in pairs(cards) do
		removeMarker(marker)
	end
	drops = {}
	urgentIndex = nil
	activeTrackId = nil
end

return StopBillboards
