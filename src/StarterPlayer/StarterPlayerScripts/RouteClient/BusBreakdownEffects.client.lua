--[[
	BusBreakdownEffects.client.lua

	A breakdown throws people and pieces of the bus everywhere, instead of
	passengers quietly leaving the way they do at a stop.

	Triggered by the bus's BrokenDown attribute going true. A tow-back sets
	the same attribute (BusMonitor reuses the freeze for it), so Towing is
	checked too -- being winched back onto the road shouldn't blow the bus
	apart.

	Everything is cosmetic and client-local: ejected passengers and debris
	are ANCHORED parts moved along a hand-simulated arc. Real unanchored
	debris would be simulated locally and could shove the driver's own
	client-owned bus, turning a visual effect into a gameplay one.

	Tuning lives in Shared/Config/PassengerVisualsConfig.lua.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PassengerVisualsConfig)
local PassengerFigure = require(script.Parent.PassengerFigure)

local BREAK = Config.Breakdown

local sceneFolder = Instance.new("Folder")
sceneFolder.Name = "BreakdownDebris"
sceneFolder.Parent = workspace

local tracked = {} -- [bus] = { connections }
local flying = {} -- active pieces being simulated

local rng = Random.new()

-- Launching ---------------------------------------------------------------------------------

local function launchVelocity(rootCF, inherited)
	-- Outward from the bus in a random direction, mostly upward.
	local angle = rng:NextNumber(0, math.pi * 2)
	local out = (rootCF.RightVector * math.cos(angle) + rootCF.LookVector * math.sin(angle))
	return out * BREAK.LaunchOut * rng:NextNumber(0.6, 1.4)
		+ Vector3.yAxis * BREAK.LaunchUp * rng:NextNumber(0.7, 1.3)
		+ inherited * BREAK.InheritSpeed
end

local function addFlying(instance, isModel, startCF, velocity)
	table.insert(flying, {
		instance = instance,
		isModel = isModel,
		cframe = startCF,
		velocity = velocity,
		spin = Vector3.new(
			rng:NextNumber(-1, 1),
			rng:NextNumber(-1, 1),
			rng:NextNumber(-1, 1)
		).Unit * math.rad(BREAK.SpinDegrees) * rng:NextNumber(0.5, 1.2),
		bornAt = os.clock(),
	})
end

local function ejectPassengers(bus, root)
	local aboard = bus:GetAttribute("Passengers") or 0
	if aboard <= 0 then
		return
	end
	local count = math.min(aboard, rng:NextInteger(BREAK.EjectMin, BREAK.EjectMax))
	local rootCF = root.CFrame
	local inherited = root.AssemblyLinearVelocity

	for _ = 1, count do
		local figure = PassengerFigure.New("full", sceneFolder)
		PassengerFigure.Outline(figure)
		local start = rootCF * CFrame.new(
			rng:NextNumber(-root.Size.X / 2, root.Size.X / 2),
			rng:NextNumber(0, root.Size.Y / 2),
			rng:NextNumber(-root.Size.Z / 3, root.Size.Z / 3)
		)
		PassengerFigure.Place(figure, start)
		addFlying(figure, true, start, launchVelocity(rootCF, inherited))
	end
end

local function throwDebris(bus, root)
	-- Clone actual pieces of this bus, so the debris matches whatever it's
	-- built from -- placeholder blocks now, real models later.
	local candidates = {}
	for _, part in ipairs(bus:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root and part.Transparency < 1 and part.Name ~= "DriverSeat" then
			table.insert(candidates, part)
		end
	end
	if #candidates == 0 then
		return
	end

	local rootCF = root.CFrame
	local inherited = root.AssemblyLinearVelocity
	for _ = 1, BREAK.DebrisCount do
		local source = candidates[rng:NextInteger(1, #candidates)]
		local chunk = source:Clone()
		-- Strip anything that could tie the clone back to the real bus.
		chunk:ClearAllChildren()
		chunk.Name = "Debris"
		chunk.Anchored = true
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.CastShadow = false
		chunk.Massless = true
		-- Shrink the bigger panels so the bus doesn't appear to shed
		-- whole walls of itself.
		chunk.Size = source.Size * rng:NextNumber(0.3, 0.55)
		chunk.Parent = sceneFolder

		local start = CFrame.new(source.Position) * CFrame.Angles(
			rng:NextNumber(0, math.pi),
			rng:NextNumber(0, math.pi),
			rng:NextNumber(0, math.pi)
		)
		chunk.CFrame = start
		addFlying(chunk, false, start, launchVelocity(rootCF, inherited))
	end
end

local function blowUp(bus)
	local root = bus.PrimaryPart
	if not root or not root.Parent then
		return
	end
	ejectPassengers(bus, root)
	throwDebris(bus, root)
end

-- Discovery -----------------------------------------------------------------------------------

local function untrack(bus)
	local record = tracked[bus]
	if not record then
		return
	end
	tracked[bus] = nil
	for _, connection in ipairs(record.connections) do
		connection:Disconnect()
	end
end

local function trackBus(bus)
	if tracked[bus] or not bus:IsA("Model") then
		return
	end
	local record = { connections = {} }
	tracked[bus] = record

	table.insert(record.connections, bus:GetAttributeChangedSignal("BrokenDown"):Connect(function()
		-- Towing sets BrokenDown as well; that's a winch, not a wreck.
		if bus:GetAttribute("BrokenDown") and not bus:GetAttribute("Towing") then
			blowUp(bus)
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

-- Flight ----------------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for i = #flying, 1, -1 do
		local piece = flying[i]
		local age = now - piece.bornAt

		if age >= BREAK.LifeSeconds or not piece.instance.Parent then
			piece.instance:Destroy()
			table.remove(flying, i)
		else
			piece.velocity = piece.velocity - Vector3.yAxis * BREAK.Gravity * dt
			piece.cframe = CFrame.new(piece.cframe.Position + piece.velocity * dt)
				* (piece.cframe - piece.cframe.Position)
				* CFrame.Angles(piece.spin.X * dt, piece.spin.Y * dt, piece.spin.Z * dt)

			local fade = math.clamp((age / BREAK.LifeSeconds - BREAK.FadeAfter) / (1 - BREAK.FadeAfter), 0, 1)
			if piece.isModel then
				PassengerFigure.Place(piece.instance, piece.cframe)
				for _, part in ipairs(piece.instance:GetChildren()) do
					if part:IsA("BasePart") then
						part.Transparency = fade
					end
				end
			else
				piece.instance.CFrame = piece.cframe
				piece.instance.Transparency = fade
			end
		end
	end
end)
