--[[
	BusPassengerVisuals.client.lua

	Makes a bus's load visible: noob figures appear in the windows as it
	fills up, and once it's nearly full the overflow ends up clinging to
	the roof, dragged backwards by the wind at speed. Someone boarding or
	getting off hops at the door.

	Runs locally on each player's screen from attributes the server already
	replicates (Passengers, Capacity), so nothing here costs network
	traffic -- the same approach BusDamageEffects.client.lua uses for smoke
	and flames. Figures are anchored, collisionless props positioned by
	CFrame, so they cannot affect the bus's physics or its collision checks.

	Bus geometry is read from the Root part's size rather than from the
	placeholder body parts, so this keeps working when real bus models
	replace the procedural ones. The bus faces -Z in Root space.

	Tuning lives in Shared/Config/PassengerVisualsConfig.lua.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PassengerVisualsConfig)
local PassengerFigure = require(script.Parent.PassengerFigure)

local BUS = Config.Bus

local tracked = {} -- [bus] = record

local sceneFolder = Instance.new("Folder")
sceneFolder.Name = "PassengerVisuals"
sceneFolder.Parent = workspace

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z).Magnitude
end

-- 0 below `from`, 1 at or above `to`.
local function ramp(value, from, to)
	if to <= from then
		return value >= to and 1 or 0
	end
	return math.clamp((value - from) / (to - from), 0, 1)
end

-- Seat and slot layout, derived from the Root's dimensions ------------------------------

local function layoutFor(root)
	local size = root.Size
	local width, height, length = size.X, size.Y, size.Z

	local seats = {}
	local perSide = BUS.WindowSeatsPerSide
	-- Window line: just inside each flank, a little above the body's middle,
	-- spread along the glazed section (about the middle 78% of the bus).
	local windowY = height * 0.12 + BUS.SeatHeightOffset
	local seatX = width / 2 - 0.4
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, perSide do
			local t = perSide == 1 and 0.5 or (i - 1) / (perSide - 1)
			local z = (t - 0.5) * length * 0.66
			-- Turned to face out of their own window and tipped forward,
			-- so they read as people leaning on the glass rather than
			-- upright mannequins floating in the middle of the bus.
			local rng = Random.new(i * 31 + (side + 1) * 977)
			local yaw = side * math.pi / 2 + math.rad(rng:NextNumber(-14, 14))
			local lean = math.rad(BUS.SeatLeanDegrees + rng:NextNumber(-5, 5))
			table.insert(
				seats,
				CFrame.new(side * seatX, windowY, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, 0)
			)
		end
	end

	local roof = {}
	local slots = BUS.RoofSlots
	-- They lie ON the roof surface, so this is the top of the body.
	local roofY = height / 2 + 0.2
	for i = 1, slots do
		local t = slots == 1 and 0.5 or (i - 1) / (slots - 1)
		-- Staggered across the roof so they don't line up like fence posts.
		local x = ((i % 2 == 0) and 1 or -1) * width * 0.18
		local z = (t - 0.5) * length * 0.62
		table.insert(roof, CFrame.new(x, roofY, z))
	end

	return { seats = seats, roof = roof, width = width, height = height, length = length }
end

-- Building / discovery -------------------------------------------------------------------

local function untrack(bus)
	local record = tracked[bus]
	if not record then
		return
	end
	tracked[bus] = nil
	for _, connection in ipairs(record.connections) do
		connection:Disconnect()
	end
	record.container:Destroy()
end

local function trackBus(bus)
	if tracked[bus] or not bus:IsA("Model") then
		return
	end
	local root = bus.PrimaryPart or bus:WaitForChild("Root", 10)
	if not root or tracked[bus] or not bus:IsDescendantOf(workspace) then
		return
	end

	local container = Instance.new("Model")
	container.Name = "Riders_" .. bus.Name
	container.Parent = sceneFolder

	local layout = layoutFor(root)

	-- Built once, up front, and then only shown or hidden. Creating and
	-- destroying figures as people board would be the expensive mistake --
	-- this fires every time a passenger gets on or off.
	local windows = {}
	for _ = 1, #layout.seats do
		local figure = PassengerFigure.New("upper", container)
		PassengerFigure.SetVisible(figure, false)
		table.insert(windows, figure)
	end

	local roof = {}
	for _ = 1, #layout.roof do
		local figure = PassengerFigure.New("full", container)
		PassengerFigure.SetVisible(figure, false)
		table.insert(roof, figure)
	end

	PassengerFigure.Outline(container)

	local record = {
		bus = bus,
		root = root,
		container = container,
		layout = layout,
		windows = windows,
		roof = roof,
		hops = {},
		lastPassengers = bus:GetAttribute("Passengers") or 0,
		visible = true,
		connections = {},
	}
	tracked[bus] = record

	-- A passenger count that moved is the only signal needed for the hop,
	-- and unlike the StopEvent remote (which only reaches the bus's own
	-- driver) it works for every bus on the track.
	table.insert(record.connections, bus:GetAttributeChangedSignal("Passengers"):Connect(function()
		local now = bus:GetAttribute("Passengers") or 0
		local delta = now - record.lastPassengers
		record.lastPassengers = now
		-- A breakdown also drops the count, but those passengers are being
		-- flung out by BusBreakdownEffects -- they shouldn't also be
		-- politely hopping down at the door.
		if bus:GetAttribute("BrokenDown") then
			return
		end
		if delta ~= 0 then
			-- A single press can board several people (RouteConfig
			-- MaxBoardPerPress / the speed tiers), and a drop-off can empty
			-- a whole group. Stagger a few hops so a crowd reads as a
			-- crowd, capped so a big delivery doesn't spray figures.
			local clock = os.clock()
			for i = 1, math.min(math.abs(delta), BUS.MaxHopsPerEvent) do
				table.insert(record.hops, {
					boarding = delta > 0,
					startedAt = clock + (i - 1) * BUS.HopStagger,
					figure = nil,
				})
			end
		end
	end))

	table.insert(record.connections, bus.AncestryChanged:Connect(function()
		if not bus:IsDescendantOf(workspace) then
			untrack(bus)
		end
	end))
end

local function watchTrack(track)
	local buses = track:WaitForChild("Buses", 10)
	if not buses then
		return
	end
	for _, bus in ipairs(buses:GetChildren()) do
		task.spawn(trackBus, bus)
	end
	buses.ChildAdded:Connect(function(bus)
		task.spawn(trackBus, bus)
	end)
end

local function watchInstances(folder)
	for _, track in ipairs(folder:GetChildren()) do
		task.spawn(watchTrack, track)
	end
	folder.ChildAdded:Connect(function(track)
		task.spawn(watchTrack, track)
	end)
end

local existing = workspace:FindFirstChild("RouteInstances")
if existing then
	watchInstances(existing)
end
workspace.ChildAdded:Connect(function(child)
	if child.Name == "RouteInstances" then
		watchInstances(child)
	end
end)

-- Per-frame ---------------------------------------------------------------------------------

local function setContainerVisible(record, visible)
	if record.visible == visible then
		return
	end
	record.visible = visible
	if not visible then
		for _, figure in ipairs(record.windows) do
			PassengerFigure.SetVisible(figure, false)
		end
		for _, figure in ipairs(record.roof) do
			PassengerFigure.SetVisible(figure, false)
		end
		for _, hop in ipairs(record.hops) do
			if hop.figure then
				hop.figure:Destroy()
			end
		end
		table.clear(record.hops)
	end
end

local function updateHops(record, rootCF, now)
	local layout = record.layout
	-- The door is on the bus's left flank, the kerb side for odd stops.
	local doorX = -(layout.width / 2 + 0.6)
	local doorZ = layout.length * 0.12

	for i = #record.hops, 1, -1 do
		local hop = record.hops[i]
		local elapsed = now - hop.startedAt
		local t = elapsed / BUS.HopSeconds

		if t >= 1 then
			if hop.figure then
				hop.figure:Destroy()
			end
			table.remove(record.hops, i)
		elseif t >= 0 then -- staggered hops wait their turn
			if not hop.figure then
				hop.figure = PassengerFigure.New("full", record.container)
				-- Nudge each one along the bus so a group doesn't stack up
				-- in exactly the same spot.
				hop.lane = (i % 3 - 1) * 1.1
			end
			-- Boarding runs the arc inwards and up; getting off reverses it.
			local progress = hop.boarding and t or (1 - t)
			local outward = 1 - progress -- 1 = out at the kerb, 0 = at the door
			local lift = math.sin(progress * math.pi) * BUS.HopHeight

			local offset = Vector3.new(
				doorX - outward * 1.8,
				-layout.height / 2 + lift,
				doorZ + (hop.lane or 0)
			)
			local cframe = rootCF * CFrame.new(offset)
			PassengerFigure.Place(hop.figure, cframe)
			PassengerFigure.SetArms(hop.figure, cframe, math.sin(progress * math.pi) * 0.8)
			-- Fade out as they disappear inside / walk away.
			local fade = hop.boarding and t or (1 - t)
			for _, part in ipairs(hop.figure:GetChildren()) do
				if part:IsA("BasePart") then
					part.Transparency = math.clamp(fade * fade, 0, 1)
				end
			end
		end
	end
end

local function update(record, now, cameraPosition)
	local bus = record.bus
	local root = bus.PrimaryPart
	if not root or not root.Parent then
		return
	end

	local rootCF = root.CFrame
	if (rootCF.Position - cameraPosition).Magnitude > BUS.RenderDistance then
		setContainerVisible(record, false)
		return
	end
	setContainerVisible(record, true)

	local capacity = math.max(bus:GetAttribute("Capacity") or 1, 1)
	local passengers = bus:GetAttribute("Passengers") or 0
	local load = math.clamp(passengers / capacity, 0, 1)
	local layout = record.layout

	-- Window seats fill in as the load climbs from WindowStartLoad.
	local seatsShown = math.floor(ramp(load, BUS.WindowStartLoad, BUS.WindowFullLoad) * #layout.seats + 0.5)
	-- Never show more figures than there are actual passengers aboard.
	seatsShown = math.min(seatsShown, passengers)
	for index, figure in ipairs(record.windows) do
		local visible = index <= seatsShown
		PassengerFigure.SetVisible(figure, visible)
		if visible then
			local seat = rootCF * layout.seats[index]
			PassengerFigure.Place(figure, seat)
		end
	end

	-- Roof clingers: only once there is genuinely no room left inside.
	local roofShown = 0
	if load >= BUS.RoofStartLoad then
		roofShown = math.floor(ramp(load, BUS.RoofStartLoad, 1) * #layout.roof + 0.5)
	end
	local speed = horizontal(root.AssemblyLinearVelocity)
	local windFactor = math.clamp(speed / BUS.WindReferenceSpeed, 0, 1)

	for index, figure in ipairs(record.roof) do
		local visible = index <= roofShown
		PassengerFigure.SetVisible(figure, visible)
		if visible then
			-- Face down, hands gripping the roof, legs flung up behind them.
			-- The struggle rises with speed: at a crawl they just lie there,
			-- at full pelt they're kicking and sliding.
			local cframe = rootCF * layout.roof[index]
			local struggle = BUS.StruggleFloor + (1 - BUS.StruggleFloor) * windFactor
			PassengerFigure.PoseCling(figure, cframe, now, struggle, index * 1.7)
		end
	end

	updateHops(record, rootCF, now)
end

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position or Vector3.zero
	local now = os.clock()
	for _, record in pairs(tracked) do
		update(record, now, cameraPosition)
	end
end)
