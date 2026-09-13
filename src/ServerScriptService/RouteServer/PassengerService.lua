--[[
	PassengerService.lua

	Waiting passengers at stops, boarding, drop-offs, and fares.

	  - Each stop has a queue of passengers, each headed 1-4 stops ahead.
	    Queues refill over time. Stops are shared on a track: whoever
	    gets there first gets first pick.
	  - A bus counts as "at a stop" when inside StopRadius and slower than
	    BoardMaxSpeed. While there, passengers for that stop get off
	    automatically and pay (plus an on-time bonus if before deadline).
	  - Boarding is the player's choice (RequestBoard remote): how many to
	    cram aboard, validated here against seats and the queue.

	Bus attributes kept in sync: Passengers, AtStop (0 = not at a stop).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RouteConfig = require(ReplicatedStorage.Shared.Config.RouteConfig)
local Progression = require(ReplicatedStorage.Shared.Modules.Progression)
local Restoration = require(ReplicatedStorage.Shared.Modules.Restoration)
local BusSpawner = require(script.Parent.BusSpawner)
local TrackBuilder = require(script.Parent.TrackBuilder)
local RunScoring = require(script.Parent.RunScoring)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestBoard = Remotes:WaitForChild("RequestBoard")
local StopEvent = Remotes:WaitForChild("StopEvent")
local RunStateUpdated = Remotes:WaitForChild("RunStateUpdated")

local PassengerService = {}

local SCAN_INTERVAL = 0.2
local STATE_PUSH_INTERVAL = 0.5

local running = false
local rng = Random.new()
local trackStates = {} -- [trackId] = { track, stops = { [index] = { waiting = {passenger} } } }
local onboard = {} -- [Player] = { passenger }
local atStop = {} -- [Player] = stop index or nil
local connections = {}

-- Helpers ----------------------------------------------------------------------------------

local function makePassenger(stopCount, fromIndex)
	local ahead = rng:NextInteger(RouteConfig.DestinationMinAhead, math.min(RouteConfig.DestinationMaxAhead, stopCount - 1))
	return { destination = (fromIndex - 1 + ahead) % stopCount + 1 }
end

local function updateStopLabel(trackState, index)
	local stop = trackState.track.stops[index]
	if stop and stop.label then
		stop.label.Text = "Waiting: " .. #trackState.stops[index].waiting
	end
end

local function addWaiting(trackState, index, amount)
	local queue = trackState.stops[index].waiting
	local stopCount = #trackState.track.stops
	for _ = 1, amount do
		if #queue >= RouteConfig.WaitingCap then
			break
		end
		table.insert(queue, makePassenger(stopCount, index))
	end
	updateStopLabel(trackState, index)
end

local function horizontalDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function pushState(player)
	local record = BusSpawner.GetRecord(player)
	if not record then
		return
	end
	local trackState = trackStates[record.track.id]
	local list = onboard[player] or {}
	local now = os.clock()

	local drops = {}
	for _, passenger in ipairs(list) do
		local entry = drops[passenger.destination]
		if not entry then
			entry = {
				index = passenger.destination,
				position = record.track.stops[passenger.destination].position,
				count = 0,
				soonestDeadline = math.huge,
			}
			drops[passenger.destination] = entry
		end
		entry.count = entry.count + 1
		entry.soonestDeadline = math.min(entry.soonestDeadline, passenger.deadline - now)
	end
	local dropList = {}
	for _, entry in pairs(drops) do
		entry.soonestDeadline = math.floor(entry.soonestDeadline)
		table.insert(dropList, entry)
	end
	table.sort(dropList, function(a, b)
		return a.soonestDeadline < b.soonestDeadline
	end)

	local stopIndex = atStop[player]
	local capacity = record.bus:GetAttribute("Capacity") or 0
	local stats = RunScoring.Get(player) or {}

	RunStateUpdated:FireClient(player, {
		passengers = #list,
		capacity = capacity,
		drops = dropList,
		atStop = stopIndex or 0,
		waitingAtStop = stopIndex and trackState and #trackState.stops[stopIndex].waiting or 0,
		seatsLeft = math.max(0, capacity - #list),
		fares = stats.fares or 0,
		deliveries = stats.deliveries or 0,
		collisions = stats.collisions or 0,
		cleanStreak = stats.cleanStreak or 0,
	})
end

local function setPassengerCount(player, record)
	record.bus:SetAttribute("Passengers", #(onboard[player] or {}))
end

-- Drop-offs ----------------------------------------------------------------------------------

local function deliverAt(player, record, stopIndex)
	local list = onboard[player]
	if not list or #list == 0 then
		return
	end

	local now = os.clock()
	local delivered, onTimeCount, earned = 0, 0, 0
	-- A more restored (less rusty) bus earns higher fares.
	local fareMultiplier = Restoration.FareMultiplier(record.chassisId, record.levels)
	for i = #list, 1, -1 do
		local passenger = list[i]
		if passenger.destination == stopIndex then
			table.remove(list, i)
			local fare = math.floor(Progression.Fare(passenger.stopsTravelled) * fareMultiplier + 0.5)
			local onTime = now <= passenger.deadline
			if onTime then
				fare = fare + Progression.OnTimeBonus(fare)
				onTimeCount = onTimeCount + 1
			end
			RunScoring.AddDelivery(player, fare, onTime)
			delivered = delivered + 1
			earned = earned + fare
		end
	end

	if delivered > 0 then
		setPassengerCount(player, record)
		StopEvent:FireClient(player, {
			kind = "delivered",
			stop = stopIndex,
			count = delivered,
			onTime = onTimeCount,
			earned = earned,
		})
		pushState(player)
	end
end

-- Scan loop: who is at which stop -----------------------------------------------------------

local function scan()
	for player, record in pairs(BusSpawner.All()) do
		local root = record.bus.PrimaryPart
		if record.released and root and player.Parent == Players then
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

			local found
			if speed <= RouteConfig.BoardMaxSpeed and not record.bus:GetAttribute("BrokenDown") then
				for _, stop in ipairs(record.track.stops) do
					if horizontalDistance(root.Position, stop.position) <= RouteConfig.StopRadius then
						found = stop.index
						break
					end
				end
			end

			if atStop[player] ~= found then
				atStop[player] = found
				record.bus:SetAttribute("AtStop", found or 0)
				pushState(player)
			end
			if found then
				deliverAt(player, record, found)
			end
		end
	end
end

-- Boarding -------------------------------------------------------------------------------------

local function handleBoard(player, stopIndex, count)
	if not running or type(stopIndex) ~= "number" or type(count) ~= "number" or count ~= count then
		return
	end
	local record = BusSpawner.GetRecord(player)
	if not record or atStop[player] ~= stopIndex then
		return
	end
	local trackState = trackStates[record.track.id]
	local stopState = trackState and trackState.stops[stopIndex]
	if not stopState then
		return
	end

	local list = onboard[player]
	local capacity = record.bus:GetAttribute("Capacity") or 0
	local boarding = math.min(math.floor(count), capacity - #list, #stopState.waiting)
	if boarding <= 0 then
		return
	end

	local now = os.clock()
	local stopCount = #record.track.stops
	for _ = 1, boarding do
		local passenger = table.remove(stopState.waiting, 1)
		local distance = TrackBuilder.DistanceBetween(record.track, stopIndex, passenger.destination)
		passenger.stopsTravelled = (passenger.destination - stopIndex) % stopCount
		passenger.deadline = now + distance / RouteConfig.ReferenceSpeed * RouteConfig.DeadlineSlack + RouteConfig.DeadlineFlatSeconds
		table.insert(list, passenger)
	end

	setPassengerCount(player, record)
	updateStopLabel(trackState, stopIndex)
	StopEvent:FireClient(player, { kind = "boarded", stop = stopIndex, count = boarding })

	-- Everyone else parked at this stop sees the queue shrink.
	for otherPlayer in pairs(BusSpawner.All()) do
		if atStop[otherPlayer] == stopIndex then
			pushState(otherPlayer)
		end
	end
end

RequestBoard.OnServerEvent:Connect(handleBoard)

-- Public API -------------------------------------------------------------------------------------

function PassengerService.Start(tracks)
	PassengerService.Stop()
	running = true

	for _, track in ipairs(tracks) do
		local trackState = { track = track, stops = {} }
		trackStates[track.id] = trackState
		for index in ipairs(track.stops) do
			trackState.stops[index] = { waiting = {} }
			addWaiting(trackState, index, RouteConfig.WaitingInitial)
		end
	end
	for player in pairs(BusSpawner.All()) do
		onboard[player] = {}
	end

	local scanTimer, pushTimer, refillTimer = 0, 0, 0
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		scanTimer = scanTimer + dt
		pushTimer = pushTimer + dt
		refillTimer = refillTimer + dt

		if scanTimer >= SCAN_INTERVAL then
			scanTimer = 0
			scan()
		end
		if refillTimer >= RouteConfig.RefillInterval then
			refillTimer = 0
			for _, trackState in pairs(trackStates) do
				for index in ipairs(trackState.stops) do
					addWaiting(trackState, index, RouteConfig.RefillAmount)
				end
			end
		end
		if pushTimer >= STATE_PUSH_INTERVAL then
			pushTimer = 0
			for player in pairs(onboard) do
				pushState(player)
			end
		end
	end))
end

function PassengerService.Stop()
	running = false
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}
	trackStates = {}
	onboard = {}
	atStop = {}
end

-- Breakdown: a fraction of onboard passengers give up and leave. Returns count lost.
function PassengerService.LoseFraction(player, fraction)
	local list = onboard[player]
	local record = BusSpawner.GetRecord(player)
	if not list or #list == 0 or not record then
		return 0
	end
	local lost = math.max(1, math.floor(#list * fraction))
	for _ = 1, lost do
		table.remove(list, rng:NextInteger(1, #list))
	end
	setPassengerCount(player, record)
	RunScoring.AddLost(player, lost)
	StopEvent:FireClient(player, { kind = "lost", count = lost })
	pushState(player)
	return lost
end

function PassengerService.RemovePlayer(player)
	onboard[player] = nil
	atStop[player] = nil
end

return PassengerService
