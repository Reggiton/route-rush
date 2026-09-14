--[[
	StopBillboards.lua

	A plain card above every stop on YOUR track, visible only to you:

	    STOP 3
	    Waiting: 9
	    Drop off 4 · 0:42

	The drop-off line appears when you're carrying passengers for that stop,
	with a live countdown to the soonest deadline (orange when close, red
	"LATE" when missed). Stops with drop-offs show through walls, and the
	most urgent one gets a yellow outline.

	Driven by RouteClient: SetTrack(trackId) when your bus appears,
	SetDrops(runState.drops, receivedAt) on every run-state update, Clear()
	when the race ends.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local UI = script.Parent.Parent:WaitForChild("UI")
local Format = require(UI:WaitForChild("Format"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StopBillboards = {}

local TAG = "StopMarker"
local URGENT_SECONDS = 15
local DARK = Color3.fromRGB(30, 30, 35)
local YELLOW = Color3.fromRGB(250, 210, 60)
local GREEN = Color3.fromRGB(50, 140, 70)
local ORANGE = Color3.fromRGB(200, 120, 40)
local RED = Color3.fromRGB(170, 50, 45)

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

local function makeLabel(parent, name, text, sizeY, posY, color, transparency, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1, 0, sizeY, 0)
	label.Position = UDim2.fromScale(0, posY)
	label.BackgroundColor3 = color
	label.BackgroundTransparency = transparency
	label.BorderSizePixel = 0
	label.Text = text
	label.TextScaled = true
	label.Font = font or Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = parent
	return label
end

local function buildCard(marker)
	local index = marker:GetAttribute("StopIndex") or 0

	local gui = Instance.new("BillboardGui")
	gui.Name = "StopCard_" .. index
	gui.Adornee = marker
	gui.ResetOnSpawn = false
	gui.Size = UDim2.fromOffset(170, 80)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
	gui.MaxDistance = 1400
	gui.Parent = playerGui

	local title = makeLabel(gui, "Title", "STOP " .. index, 0.4, 0, DARK, 0.2, Enum.Font.GothamBlack)
	title.TextColor3 = YELLOW
	local outline = Instance.new("UIStroke")
	outline.Color = YELLOW
	outline.Thickness = 2
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Enabled = false
	outline.Parent = title

	local waiting = makeLabel(gui, "Waiting", "Waiting: 0", 0.28, 0.4, DARK, 0.35)
	local drop = makeLabel(gui, "Drop", "", 0.32, 0.68, GREEN, 0.1)
	drop.Visible = false

	return {
		marker = marker,
		index = index,
		gui = gui,
		outline = outline,
		waiting = waiting,
		drop = drop,
	}
end

local function refreshCard(card, now)
	setText(card.waiting, "Waiting: " .. (card.marker:GetAttribute("Waiting") or 0))

	local drop = drops[card.index]
	card.drop.Visible = drop ~= nil
	card.gui.AlwaysOnTop = drop ~= nil
	card.outline.Enabled = card.index == urgentIndex

	if drop then
		local remaining = drop.deadlineAt - now
		if remaining > 0 then
			setText(card.drop, string.format("Drop off %d · %s", drop.count, Format.Time(remaining)))
			card.drop.BackgroundColor3 = remaining <= URGENT_SECONDS and ORANGE or GREEN
		else
			setText(card.drop, string.format("Drop off %d · LATE", drop.count))
			card.drop.BackgroundColor3 = RED
		end
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
