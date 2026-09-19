--[[
	StopCrowdVisuals.client.lua

	Puts the waiting passengers on the platform: the queue you can see is
	the queue you're about to pick up, and it visibly shrinks as you board
	people.

	Unlike the bus (where a maxed Tier 4 seats 72), a stop queue is capped
	at RouteConfig.WaitingCap -- 12 -- so this draws the REAL number
	waiting rather than a representative handful.

	Driven entirely from the stop markers the server already maintains:
	parts tagged "StopMarker" carrying TrackId, StopIndex, Side and a live
	Waiting count (PassengerService keeps it up to date). Same discovery
	pattern as StopPanel.lua. Nothing here replicates or affects gameplay.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PassengerVisualsConfig)
local PassengerFigure = require(script.Parent.PassengerFigure)

local STOP = Config.Stop
local TAG = "StopMarker"
local MAX_FIGURES = 12 -- RouteConfig.WaitingCap; more than this never waits

local tracked = {} -- [marker] = record

local sceneFolder = Instance.new("Folder")
sceneFolder.Name = "StopCrowdVisuals"
sceneFolder.Parent = workspace

--[[
	The marker sits over the boarding bay on the road, with no rotation, so
	it can't tell us which way the stop faces. The platform can: it's built
	from the same lane CFrame, so its orientation follows the road. Find it
	through the track folder by stop index.

	With StreamingEnabled the stop model may not be loaded yet while the
	marker (which is Persistent) already is, so this is retried until it
	resolves rather than resolved once up front.
]]
local function findPlatform(marker)
	local trackFolder = marker.Parent and marker.Parent.Parent
	local stops = trackFolder and trackFolder:FindFirstChild("Stops")
	local stopModel = stops and stops:FindFirstChild("Stop_" .. tostring(marker:GetAttribute("StopIndex")))
	local platform = stopModel and stopModel:FindFirstChild("Platform")
	if platform and platform:IsA("BasePart") then
		return platform
	end
	return nil
end

-- Where each waiting figure stands, in the platform's own space: rows
-- across the shelter, filled front row first so the queue grows backwards.
local function slotFor(index, platform, side)
	local row = math.floor((index - 1) / STOP.PerRow)
	local column = (index - 1) % STOP.PerRow

	local x = (column - (STOP.PerRow - 1) / 2) * STOP.ColumnGap
	local z = (row - 1) * STOP.RowGap

	-- A little deterministic scatter, so a queue reads as people rather
	-- than a grid of clones. Seeded by index so they don't jitter about.
	local rng = Random.new(index * 7349)
	x = x + rng:NextNumber(-STOP.Jitter, STOP.Jitter)
	z = z + rng:NextNumber(-STOP.Jitter, STOP.Jitter)

	-- Stand on top of the platform slab, turned to face the road.
	local top = platform.Size.Y / 2
	local yaw = side * math.pi / 2
	return CFrame.new(x, top, z) * CFrame.Angles(0, yaw, 0)
end

local function untrack(marker)
	local record = tracked[marker]
	if not record then
		return
	end
	tracked[marker] = nil
	if record.container then
		record.container:Destroy()
	end
end

local function build(record)
	local container = Instance.new("Model")
	container.Name = "Crowd_" .. tostring(record.marker:GetAttribute("StopIndex"))
	container.Parent = sceneFolder

	local figures = {}
	for _ = 1, MAX_FIGURES do
		local figure = PassengerFigure.New("full", container)
		PassengerFigure.SetVisible(figure, false)
		table.insert(figures, figure)
	end
	PassengerFigure.Outline(container)

	record.container = container
	record.figures = figures
end

local function addMarker(marker)
	if tracked[marker] or not marker:IsA("BasePart") then
		return
	end
	tracked[marker] = {
		marker = marker,
		platform = nil,
		container = nil,
		figures = nil,
		placed = false,
	}
end

local function update(record, cameraPosition)
	local marker = record.marker
	if not marker:IsDescendantOf(workspace) then
		untrack(marker)
		return
	end

	-- Hysteresis: drop the crowd a little further out than the distance it
	-- builds at, so hovering right on the boundary doesn't rebuild 72
	-- parts every tick.
	local distance = (marker.Position - cameraPosition).Magnitude
	local limit = record.container and STOP.RenderDistance * 1.15 or STOP.RenderDistance
	if distance > limit then
		-- Build nothing until a stop is actually worth drawing, and drop
		-- the figures again once it's behind you: a full track is 8 stops
		-- x 12 people, which is not worth keeping on screen at once.
		if record.container then
			record.container:Destroy()
			record.container = nil
			record.figures = nil
			record.placed = false
		end
		return
	end

	record.platform = record.platform or findPlatform(marker)
	if not record.platform or not record.platform.Parent then
		record.platform = nil
		return -- stop model not streamed in yet
	end

	if not record.container then
		build(record)
	end

	-- The platform never moves, so the figures only need placing once.
	if not record.placed then
		local side = marker:GetAttribute("Side") or -1
		local platformCF = record.platform.CFrame
		for index, figure in ipairs(record.figures) do
			PassengerFigure.Place(figure, platformCF * slotFor(index, record.platform, side))
		end
		record.placed = true
	end

	local waiting = math.clamp(marker:GetAttribute("Waiting") or 0, 0, MAX_FIGURES)
	for index, figure in ipairs(record.figures) do
		PassengerFigure.SetVisible(figure, index <= waiting)
	end
end

for _, marker in ipairs(CollectionService:GetTagged(TAG)) do
	addMarker(marker)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(addMarker)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)

-- Crowds only change when someone boards or a refill lands, so this runs
-- well below frame rate.
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator = accumulator + dt
	if accumulator < 0.2 then
		return
	end
	accumulator = 0

	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position or Vector3.zero
	for _, record in pairs(tracked) do
		update(record, cameraPosition)
	end
end)
