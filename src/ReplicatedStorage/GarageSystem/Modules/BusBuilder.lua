--[[
	BusBuilder.lua

	Builds a bus model for a chassis tier, with one Attachment per upgrade
	category so BusUpgradeApplier knows where to weld each upgrade.

	REAL MODELS: if ReplicatedStorage.GarageAssets.Buses has a Model named
	after the chassis id ("Tier1", "Tier2", ...), that model is used. It
	can be any bus model built in Studio -- this file wraps it:
	  - centers it, turns it to face -Z, and fits an invisible collision
	    box ("Root") around it
	  - makes every part welded, massless, and non-colliding
	  - removes scripts, disables seats/constraints inside it
	Optional attributes on the template Model:
	  FrontAxis   "-Z" (default) | "+Z" | "+X" | "-X": which way the bus's
	              front points in the model as built
	  Scale       number, default 1
	  RideHeight  studs of wheel clearance under the collision box
	              (default 15% of the model's height)
	Optional children anywhere inside the template:
	  Attachments named Engine / Accel / Brakes / Handles / Health
	  -> where upgrade models attach (otherwise placed automatically)
	  A Seat named "DriverSeat" -> where the driver sits

	PLACEHOLDERS: tiers without a model get a block bus built from parts,
	shaped by UpgradeConfig.ChassisTiers[i].body.

	Every returned bus has:
	  - PrimaryPart = invisible collision box named "Root"
	  - one Attachment per UpgradeConfig.Categories entry, parented to Root
	  - attributes ChassisId, RootHeight (ground -> Root center), BusLength
	  - (opts.withSeat) a Seat named "DriverSeat" welded to Root
	Convention: the bus faces Root's LookVector (-Z).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)

local BusBuilder = {}

local WINDOW_COLOR = Color3.fromRGB(35, 45, 55)
local WHEEL_COLOR = Color3.fromRGB(25, 25, 25)
local ROOF_COLOR = Color3.fromRGB(220, 220, 220)

local FRONT_AXIS_DEGREES = {
	["-Z"] = 0,
	["+Z"] = 180,
	["+X"] = 90,
	["-X"] = -90,
}

-- Shared helpers -------------------------------------------------------------------------

local function weldToRoot(root, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function addPart(bus, root, name, size, offset, props)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = root.CFrame * offset
	part.Anchored = root.Anchored
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props or {}) do
		part[key] = value
	end
	part.Parent = bus
	weldToRoot(root, part)
	return part
end

local function makeRoot(bus, size, cframe, anchored)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.CFrame = cframe
	root.Transparency = 1
	root.Anchored = anchored
	root.CanCollide = true
	root.CanQuery = false
	root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
	root.Parent = bus
	bus.PrimaryPart = root
	return root
end

--[[
	Adds the category attachments and optional driver seat.
	dims = { width, length, bodyHeight, deckHeight, bottomY, wheelY, frontZ } (Root space)
	markers = { [category] = worldPosition, seat = worldCFrame } (optional overrides)
]]
local function finishBus(bus, root, dims, markers, opts)
	local defaults = {
		Engine = Vector3.new(0, dims.bottomY + dims.deckHeight * 0.45, -dims.length / 2 - 1.2),
		Accel = Vector3.new(0, dims.bottomY + 1, dims.length / 2 + 1.2),
		Brakes = Vector3.new(dims.width / 2 + 1.2, dims.wheelY, dims.frontZ),
		Handles = Vector3.new(0, dims.bodyHeight / 2 + 1.4, 0),
		Health = Vector3.new(-(dims.width / 2 + 1.2), 0, 0),
	}
	for i, category in ipairs(UpgradeConfig.Categories) do
		local attachment = Instance.new("Attachment")
		attachment.Name = category
		if markers[category] then
			attachment.Position = root.CFrame:PointToObjectSpace(markers[category])
		else
			attachment.Position = defaults[category]
				or Vector3.new(0, dims.bodyHeight / 2 + 1.4, -dims.length / 2 + (i - 0.5) * (dims.length / #UpgradeConfig.Categories))
		end
		attachment.Parent = root
	end

	if opts.withSeat then
		local seat = Instance.new("Seat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(2, 1, 2)
		seat.CFrame = markers.seat or (root.CFrame * CFrame.new(-dims.width / 4, dims.bottomY + 1.2, -dims.length / 2 + 3))
		seat.Transparency = 1
		seat.Anchored = root.Anchored
		seat.CanCollide = false
		seat.CanTouch = false -- only the server seats players
		seat.Massless = true
		seat.Parent = bus
		weldToRoot(root, seat)
	end
end

-- Real models ------------------------------------------------------------------------------

function BusBuilder.GetTemplate(chassisId)
	local assets = ReplicatedStorage:FindFirstChild("GarageAssets")
	local buses = assets and assets:FindFirstChild("Buses")
	local template = buses and buses:FindFirstChild(chassisId)
	if template and (template:IsA("Model") or template:IsA("Folder")) then
		return template
	end
	return nil
end

-- World-axis bounding box of the visible parts (falls back to all parts).
local function worldBounds(model)
	local function measure(visibleOnly)
		local minV, maxV
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and (not visibleOnly or part.Transparency < 1) then
				local cf, half = part.CFrame, part.Size / 2
				local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
				local extents = Vector3.new(
					math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z,
					math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z,
					math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
				)
				local low, high = cf.Position - extents, cf.Position + extents
				minV = minV and minV:Min(low) or low
				maxV = maxV and maxV:Max(high) or high
			end
		end
		return minV, maxV
	end
	local minV, maxV = measure(true)
	if not minV then
		minV, maxV = measure(false)
	end
	if not minV then
		return nil
	end
	return (minV + maxV) / 2, maxV - minV
end

local function buildFromTemplate(template, tier, opts, anchored)
	local body = template:Clone()
	if not body:IsA("Model") then
		local model = Instance.new("Model")
		for _, child in ipairs(body:GetChildren()) do
			child.Parent = model
		end
		body:Destroy()
		body = model
	end
	body.Name = "Body"

	local scale = template:GetAttribute("Scale")
	if type(scale) == "number" and scale > 0 and scale ~= 1 then
		pcall(function()
			body:ScaleTo(body:GetScale() * scale)
		end)
	end

	local center, size = worldBounds(body)
	if not center then
		body:Destroy()
		return nil
	end

	-- Center on the origin and turn the front to -Z.
	local degrees = FRONT_AXIS_DEGREES[template:GetAttribute("FrontAxis") or "-Z"] or 0
	body:PivotTo(CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(-center) * body:GetPivot())
	if degrees == 90 or degrees == -90 then
		size = Vector3.new(size.Z, size.Y, size.X)
	end

	local width, height, length = size.X, size.Y, size.Z
	local rideHeight = template:GetAttribute("RideHeight")
	rideHeight = math.clamp(type(rideHeight) == "number" and rideHeight or height * 0.15, 0, height * 0.5)
	local rootHeight = height - rideHeight

	local bus = Instance.new("Model")
	bus.Name = "Bus_" .. tier.id
	bus:SetAttribute("ChassisId", tier.id)
	bus:SetAttribute("RootHeight", rideHeight + rootHeight / 2)
	bus:SetAttribute("BusLength", length)

	-- Model space: bottom of the wheels at y = -height/2.
	local root = makeRoot(bus, Vector3.new(width, rootHeight, length), CFrame.new(0, rideHeight / 2, 0), anchored)

	local markers = {}
	for _, item in ipairs(body:GetDescendants()) do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		elseif item:IsA("Seat") or item:IsA("VehicleSeat") then
			if item.Name == "DriverSeat" or (item:IsA("VehicleSeat") and not markers.seat) then
				markers.seat = item.CFrame
			end
			item.Disabled = true
		elseif item:IsA("Attachment") and table.find(UpgradeConfig.Categories, item.Name) then
			markers[item.Name] = item.WorldPosition
			item.Name = item.Name .. "_Marker"
		elseif item:IsA("Constraint") then
			item.Enabled = false
		end
	end
	for _, part in ipairs(body:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = anchored
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			weldToRoot(root, part)
		end
	end
	body.Parent = bus

	local bottomY = -rootHeight / 2
	finishBus(bus, root, {
		width = width,
		length = length,
		bodyHeight = rootHeight,
		deckHeight = rootHeight,
		bottomY = bottomY,
		wheelY = bottomY - rideHeight / 2,
		frontZ = -length / 2 + length * 0.18,
	}, markers, opts)

	return bus
end

-- Placeholder block bus --------------------------------------------------------------------

local function buildPlaceholder(tier, opts, anchored)
	local spec = tier.body

	local width, length, deckHeight, decks = spec.width, spec.length, spec.height, spec.decks
	local bodyHeight = deckHeight * decks
	local wheelRadius = math.max(1.6, width * 0.22)
	local rideHeight = wheelRadius * 0.9

	local bus = Instance.new("Model")
	bus.Name = "Bus_" .. tier.id
	bus:SetAttribute("ChassisId", tier.id)
	bus:SetAttribute("RootHeight", rideHeight + bodyHeight / 2)
	bus:SetAttribute("BusLength", length)

	-- Collision root: the body volume, floating rideHeight above the ground.
	local root = makeRoot(bus, Vector3.new(width, bodyHeight, length), CFrame.new(), anchored)

	local bottomY = -bodyHeight / 2

	-- Decks
	for deck = 1, decks do
		local deckCenterY = bottomY + deckHeight * (deck - 0.5)
		addPart(bus, root, "Deck" .. deck, Vector3.new(width, deckHeight - 0.15, length), CFrame.new(0, deckCenterY, 0), {
			Color = spec.color,
		})
		addPart(
			bus,
			root,
			"Windows" .. deck,
			Vector3.new(width + 0.12, deckHeight * 0.38, length * 0.78),
			CFrame.new(0, deckCenterY + deckHeight * 0.14, length * 0.04),
			{ Color = WINDOW_COLOR, Material = Enum.Material.Glass, Transparency = 0.15 }
		)
		addPart(
			bus,
			root,
			"Stripe" .. deck,
			Vector3.new(width + 0.1, deckHeight * 0.12, length * 0.98),
			CFrame.new(0, deckCenterY - deckHeight * 0.22, 0),
			{ Color = spec.stripeColor }
		)
	end

	-- Windshield, roof, lights
	addPart(
		bus,
		root,
		"Windshield",
		Vector3.new(width * 0.88, deckHeight * 0.45, 0.2),
		CFrame.new(0, bottomY + deckHeight * 0.62, -length / 2 - 0.05),
		{ Color = WINDOW_COLOR, Material = Enum.Material.Glass, Transparency = 0.1 }
	)
	addPart(bus, root, "Roof", Vector3.new(width * 0.94, 0.4, length * 0.96), CFrame.new(0, bodyHeight / 2 + 0.2, 0), {
		Color = ROOF_COLOR,
	})
	for _, side in ipairs({ -1, 1 }) do
		addPart(
			bus,
			root,
			"Headlight",
			Vector3.new(width * 0.16, 0.8, 0.2),
			CFrame.new(side * width * 0.34, bottomY + deckHeight * 0.18, -length / 2 - 0.1),
			{ Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon }
		)
		addPart(
			bus,
			root,
			"Taillight",
			Vector3.new(width * 0.14, 0.8, 0.2),
			CFrame.new(side * width * 0.36, bottomY + deckHeight * 0.18, length / 2 + 0.1),
			{ Color = Color3.fromRGB(200, 30, 30), Material = Enum.Material.Neon }
		)
	end

	-- Wheels
	local frontZ = -length / 2 + length * 0.18
	local rearZ = length / 2 - length * 0.18
	local axleZs = { frontZ, rearZ }
	if spec.axles >= 3 then
		table.insert(axleZs, rearZ - wheelRadius * 2.3)
	end
	local wheelY = bottomY - rideHeight + wheelRadius
	for _, z in ipairs(axleZs) do
		for _, side in ipairs({ -1, 1 }) do
			addPart(
				bus,
				root,
				"Wheel",
				Vector3.new(1.1, wheelRadius * 2, wheelRadius * 2),
				CFrame.new(side * (width / 2 - 0.4), wheelY, z),
				{ Shape = Enum.PartType.Cylinder, Color = WHEEL_COLOR }
			)
		end
	end

	finishBus(bus, root, {
		width = width,
		length = length,
		bodyHeight = bodyHeight,
		deckHeight = deckHeight,
		bottomY = bottomY,
		wheelY = wheelY,
		frontZ = frontZ,
	}, {}, opts)

	return bus
end

-- Public API ----------------------------------------------------------------------------------------

--[[
	opts = {
		anchored = true,   -- garage display (default). false for a drivable bus.
		withSeat = false,  -- add a DriverSeat
	}
]]
function BusBuilder.BuildBaseBus(chassisId, opts)
	opts = opts or {}
	local anchored = opts.anchored ~= false
	local tier = UpgradeConfig.GetChassis(chassisId) or UpgradeConfig.GetChassis(UpgradeConfig.DefaultChassisId)

	local template = BusBuilder.GetTemplate(tier.id)
	if template then
		local ok, result = pcall(buildFromTemplate, template, tier, opts, anchored)
		if ok and result then
			return result
		end
		warn("BusBuilder: couldn't use the model for " .. tier.id .. ", using the placeholder instead: " .. tostring(result))
	end
	return buildPlaceholder(tier, opts, anchored)
end

-- Anchors or unanchors every part of a built bus.
function BusBuilder.SetAnchored(bus, anchored)
	for _, part in ipairs(bus:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

return BusBuilder
