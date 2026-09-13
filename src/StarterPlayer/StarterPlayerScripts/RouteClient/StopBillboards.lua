--[[
	StopBillboards.lua

	A floating card above every stop on YOUR track, visible only to you:

	    STOP 3                  9 waiting
	    [ DROP OFF 4 ]               0:42

	The drop-off row appears when you're carrying passengers for that stop,
	with a live countdown to the soonest deadline (amber when close, red
	"LATE" when missed). Stops with drop-offs show through walls, and the
	most urgent one gets an accent border.

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

local function buildCard(marker)
	local index = marker:GetAttribute("StopIndex") or 0

	local gui = Instance.new("BillboardGui")
	gui.Name = "StopCard_" .. index
	gui.Adornee = marker
	gui.ResetOnSpawn = false
	gui.Size = UDim2.fromOffset(230, 96)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 18, 0)
	gui.MaxDistance = 1500
	gui.LightInfluence = 0
	gui.Parent = playerGui

	local panel = UIKit.Panel({ Size = UDim2.fromScale(1, 1), Parent = gui, stroke = false })
	local stroke = UIKit.Stroke(panel)
	UIKit.Padding(panel, { 12, 16, 12, 16 })

	UIKit.Text({
		Text = "STOP " .. index,
		size = "Title",
		weight = "Heavy",
		color = "Accent",
		Size = UDim2.new(0.5, 0, 0, 24),
		Parent = panel,
	})
	local waiting = UIKit.Text({
		size = "Small",
		weight = "Medium",
		color = "TextMuted",
		Size = UDim2.new(0.5, 0, 0, 24),
		Position = UDim2.fromScale(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})

	local row = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 38), Parent = panel })
	local chip = UIKit.Frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.Positive,
		Size = UDim2.new(0, 124, 1, 0),
		Parent = row,
	})
	UIKit.Corner(chip, Theme.Radius.Pill)
	local chipText = UIKit.Text({
		size = "Small",
		weight = "Heavy",
		color = "OnAccent",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = chip,
	})
	local timer = UIKit.Text({
		size = "Title",
		weight = "Heavy",
		Size = UDim2.new(1, -132, 1, 0),
		Position = UDim2.fromOffset(132, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	local empty = UIKit.Text({
		Text = "No drop-offs here",
		size = "Small",
		color = "TextDim",
		Size = UDim2.fromScale(1, 1),
		Parent = row,
	})

	return {
		marker = marker,
		index = index,
		gui = gui,
		stroke = stroke,
		waiting = waiting,
		chip = chip,
		chipText = chipText,
		timer = timer,
		empty = empty,
	}
end

local function refreshCard(card, now)
	setText(card.waiting, string.format("%d waiting", card.marker:GetAttribute("Waiting") or 0))

	local drop = drops[card.index]
	card.chip.Visible = drop ~= nil
	card.timer.Visible = drop ~= nil
	card.empty.Visible = drop == nil
	card.gui.AlwaysOnTop = drop ~= nil

	if drop then
		setText(card.chipText, "DROP OFF " .. drop.count)
		local remaining = drop.deadlineAt - now
		if remaining > 0 then
			setText(card.timer, Format.Time(remaining))
			card.timer.TextColor3 = remaining <= URGENT_SECONDS and Theme.Colors.Warning or Theme.Colors.Text
		else
			setText(card.timer, "LATE")
			card.timer.TextColor3 = Theme.Colors.Negative
		end
	end

	local urgent = card.index == urgentIndex
	card.stroke.Color = urgent and Theme.Colors.Accent or Theme.Colors.Stroke
	card.stroke.Transparency = urgent and 0 or Theme.StrokeTransparency
	card.stroke.Thickness = urgent and 2 or 1
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
