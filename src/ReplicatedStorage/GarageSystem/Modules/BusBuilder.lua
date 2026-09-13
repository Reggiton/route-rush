--[[
	BusBuilder.lua

<<<<<<< HEAD
	Builds a bus model for a chassis tier, with one Attachment per upgrade
	category so BusUpgradeApplier knows where to weld each upgrade.

	RIGHT NOW: each tier is a distinct placeholder built from parts
	(body, decks, windows, stripe, wheels, lights), shaped by
	UpgradeConfig.ChassisTiers[i].body.

	LATER: replace the body of BuildBaseBus() with a :Clone() of a real
	bus asset. The returned model must still have:
	  - PrimaryPart = an invisible collision box named "Root"
	  - one Attachment per UpgradeConfig.Categories entry, parented to Root
	  - attribute RootHeight (studs from the ground to Root's center)
	  - attribute BusLength (used by the chase camera)
	  - (driving buses) a Seat named "DriverSeat" welded to Root
	Nothing else in the codebase needs to change.

	Convention: the bus faces Root's LookVector (-Z). Visual parts are
	welded, massless, and non-colliding; only Root collides.
=======
	Builds a bus model with one Attachment per upgrade category, so
	BusUpgradeApplier knows where to weld each upgrade's model.

	RIGHT NOW: the "bus" is a single placeholder block, per the brief.

	LATER: replace the body of BuildBaseBus() with code that clones a
	real bus asset for the given chassisId (e.g. from
	ReplicatedStorage.GarageAssets.Chassis[chassisId].BusTemplate).
	The only requirement is that the returned model still has:
	  - a PrimaryPart
	  - one Attachment per UpgradeConfig.Categories entry, parented to
	    the PrimaryPart (or wherever you want upgrades to weld to)
	Nothing else in the codebase needs to change.
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
]]

local UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)

local BusBuilder = {}

<<<<<<< HEAD
local WINDOW_COLOR = Color3.fromRGB(35, 45, 55)
local WHEEL_COLOR = Color3.fromRGB(25, 25, 25)
local ROOF_COLOR = Color3.fromRGB(220, 220, 220)

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

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function addAttachment(root, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = root
end

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
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(width, bodyHeight, length)
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.Anchored = anchored
	root.CanCollide = true
	root.CanQuery = false
	root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
	root.Parent = bus
	bus.PrimaryPart = root

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

	-- One attachment per category, each somewhere it reads on the silhouette.
	local attachmentPositions = {
		Engine = Vector3.new(0, bottomY + deckHeight * 0.45, -length / 2 - 1.2),
		Accel = Vector3.new(0, bottomY + 1, length / 2 + 1.2),
		Brakes = Vector3.new(width / 2 + 1.2, wheelY, frontZ),
		Handles = Vector3.new(0, bodyHeight / 2 + 1.4, 0),
		Health = Vector3.new(-(width / 2 + 1.2), 0, 0),
	}
	for i, category in ipairs(UpgradeConfig.Categories) do
		local position = attachmentPositions[category]
			or Vector3.new(0, bodyHeight / 2 + 1.4, -length / 2 + (i - 0.5) * (length / #UpgradeConfig.Categories))
		addAttachment(root, category, position)
	end

	if opts.withSeat then
		local seat = Instance.new("Seat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(2, 1, 2)
		seat.CFrame = root.CFrame * CFrame.new(-width / 4, bottomY + 1.2, -length / 2 + 3)
		seat.Transparency = 1
		seat.Anchored = anchored
		seat.CanCollide = false
		seat.CanTouch = false -- only the server seats players
		seat.Massless = true
		seat.Parent = bus

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = seat
		weld.Parent = seat
=======
function BusBuilder.BuildBaseBus(chassisId)
	chassisId = chassisId or UpgradeConfig.DefaultChassisId

	local bus = Instance.new("Model")
	bus.Name = "Bus_" .. chassisId

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(8, 6, 20)
	body.Color = Color3.fromRGB(255, 200, 0)
	body.Anchored = true
	body.CanCollide = true
	body.Parent = bus
	bus.PrimaryPart = body

	-- One attachment per category, spaced along the roof so placeholder
	-- blocks don't overlap. Positions are purely cosmetic for now.
	for i, category in ipairs(UpgradeConfig.Categories) do
		local attachment = Instance.new("Attachment")
		attachment.Name = category
		attachment.Position = Vector3.new(0, 3.5, -8 + (i - 1) * 4)
		attachment.Parent = body
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
	end

	return bus
end

<<<<<<< HEAD
-- Anchors or unanchors every part of a built bus.
function BusBuilder.SetAnchored(bus, anchored)
	for _, part in ipairs(bus:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

=======
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
return BusBuilder
