--[[
	PassengerFigure.lua

	Builds the little noob figures used for visible passengers -- in bus
	windows, clinging to the roof, and waiting at stops.

	These are decoration only, and are built on each client rather than by
	the server, so they must never touch the simulation:

	  Anchored      they're positioned by CFrame every frame, never by
	                physics, so they can't fall, drift, or fight the bus
	  Massless      belt and braces -- an anchored part is already outside
	                the assembly, but if one is ever welded instead it must
	                not change AssemblyMass, which BusDriveController turns
	                straight into drive force
	  no collision  CanCollide/CanQuery/CanTouch all off, so BusMonitor's
	                contact box never reads a passenger as a crash

	Two shapes: "upper" (head, torso, arms) for window seats, where legs
	are never visible anyway, and "full" for roof clingers and stop crowds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PassengerVisualsConfig)

local PassengerFigure = {}

local COLORS = Config.Colors
local DIMS = Config.Figure

local function piece(parent, name, size, offset, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- Offset from the figure's origin (between the feet for "full",
	-- at the waist for "upper"), kept so Update can rebuild the pose.
	part:SetAttribute("OffsetX", offset.X)
	part:SetAttribute("OffsetY", offset.Y)
	part:SetAttribute("OffsetZ", offset.Z)
	part.Parent = parent
	return part
end

--[[
	Returns a Model whose parts are laid out around its origin. Call
	PassengerFigure.Place(figure, cframe) to move it.

	shape: "upper" | "full"
]]
function PassengerFigure.New(shape, parent)
	local figure = Instance.new("Model")
	figure.Name = "Passenger"

	local full = shape == "full"
	-- For a full figure the origin sits at the feet; for an upper body it
	-- sits at the waist, so both can be placed by a single "stand here".
	local legTop = full and DIMS.LegSize.Y or 0
	local torsoY = legTop + DIMS.TorsoSize.Y / 2
	local headY = legTop + DIMS.TorsoSize.Y + DIMS.HeadSize.Y / 2
	local armY = legTop + DIMS.TorsoSize.Y - DIMS.ArmSize.Y / 2
	local armX = DIMS.TorsoSize.X / 2 + DIMS.ArmSize.X / 2

	piece(figure, "Torso", DIMS.TorsoSize, Vector3.new(0, torsoY, 0), COLORS.Torso)
	piece(figure, "Head", DIMS.HeadSize, Vector3.new(0, headY, 0), COLORS.Head)
	piece(figure, "ArmLeft", DIMS.ArmSize, Vector3.new(-armX, armY, 0), COLORS.Arm)
	piece(figure, "ArmRight", DIMS.ArmSize, Vector3.new(armX, armY, 0), COLORS.Arm)
	if full then
		local legX = DIMS.LegSize.X / 2 + 0.05
		piece(figure, "LegLeft", DIMS.LegSize, Vector3.new(-legX, DIMS.LegSize.Y / 2, 0), COLORS.Leg)
		piece(figure, "LegRight", DIMS.LegSize, Vector3.new(legX, DIMS.LegSize.Y / 2, 0), COLORS.Leg)
	end

	figure.Parent = parent
	return figure
end

-- Moves a whole figure. `cframe` is where its origin goes (feet for a full
-- figure, waist for an upper body).
function PassengerFigure.Place(figure, cframe)
	for _, part in ipairs(figure:GetChildren()) do
		if part:IsA("BasePart") then
			part.CFrame = cframe * CFrame.new(
				part:GetAttribute("OffsetX"),
				part:GetAttribute("OffsetY"),
				part:GetAttribute("OffsetZ")
			)
		end
	end
end

--[[
	Poses a limb whose long axis is its Y size: it starts at `joint` and
	extends along `direction`. Used for the clinging pose, where arms and
	legs point in directions the stored offsets can't express.
]]
local function limb(part, joint, direction, length)
	if not part then
		return
	end
	local dir = direction.Magnitude > 0.001 and direction.Unit or Vector3.yAxis
	local center = joint + dir * (length / 2)
	-- Any axis not parallel to dir works as the "forward" reference; the
	-- limb only cares which way its length points.
	local reference = math.abs(dir.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
	part.CFrame = CFrame.lookAt(center, center + reference:Cross(dir), dir)
end

--[[
	The roof clinger: face down and flat on the roof, arms stretched
	forward with both hands gripping the front edge, legs flung up and back
	by the wind. `struggle` (0..1) drives how hard they're being pulled
	about -- at speed the legs flail and the body shifts as they lose grip.

	baseCF sits on the roof surface, facing the bus's forward (-Z).
]]
function PassengerFigure.PoseCling(figure, baseCF, now, struggle, seed)
	local flail = math.sin(now * 9 + seed) * struggle
	local flail2 = math.sin(now * 13 + seed * 2.7) * struggle
	local slip = math.sin(now * 5 + seed * 1.3) * 0.12 * struggle

	local torsoLen = DIMS.TorsoSize.Y
	local torsoDepth = DIMS.TorsoSize.Z
	-- Lying prone: the torso's length runs front-to-back and its depth
	-- becomes the height, so the belly is against the roof.
	local body = baseCF * CFrame.new(0, torsoDepth / 2, slip)
	local torso = figure:FindFirstChild("Torso")
	if torso then
		torso.CFrame = body * CFrame.Angles(-math.pi / 2, 0, 0)
	end

	-- Head up and forward, looking down the road, bobbing as they're shaken.
	local head = figure:FindFirstChild("Head")
	if head then
		head.CFrame = body
			* CFrame.new(0, DIMS.HeadSize.Y * 0.35, -(torsoLen / 2 + DIMS.HeadSize.Z * 0.5))
			* CFrame.Angles(math.rad(-25 + flail * 6), 0, 0)
	end

	-- Arms reaching forward, hands flat on the roof, splayed a little.
	local shoulderZ = -torsoLen / 2
	local shoulderX = DIMS.TorsoSize.X / 2 - 0.1
	for _, side in ipairs({ -1, 1 }) do
		local arm = figure:FindFirstChild(side < 0 and "ArmLeft" or "ArmRight")
		local joint = body * Vector3.new(side * shoulderX, 0, shoulderZ)
		local spread = side * (0.34 + 0.06 * flail2)
		local direction = (body.LookVector + body.RightVector * spread - body.UpVector * 0.22)
		limb(arm, joint, direction, DIMS.ArmSize.Y)
	end

	-- Legs trailing back and lifted by the wind, kicking independently.
	local hipZ = torsoLen / 2
	local hipX = DIMS.LegSize.X / 2 + 0.05
	for i, side in ipairs({ -1, 1 }) do
		local leg = figure:FindFirstChild(side < 0 and "LegLeft" or "LegRight")
		local kick = (i == 1 and flail or flail2)
		local joint = body * Vector3.new(side * hipX, 0, hipZ)
		local lift = 0.55 + 0.35 * struggle + kick * 0.3
		local direction = (-body.LookVector + body.UpVector * lift + body.RightVector * side * (0.25 + kick * 0.25))
		limb(leg, joint, direction, DIMS.LegSize.Y)
	end
end

-- Raises or lowers a figure's arms, for roof clingers hanging on and for
-- riders waving. `amount` 0 = down, 1 = straight up.
function PassengerFigure.SetArms(figure, cframe, amount)
	local lift = math.clamp(amount or 0, 0, 1) * math.rad(165)
	for _, name in ipairs({ "ArmLeft", "ArmRight" }) do
		local arm = figure:FindFirstChild(name)
		if arm then
			local offset = Vector3.new(
				arm:GetAttribute("OffsetX"),
				arm:GetAttribute("OffsetY"),
				arm:GetAttribute("OffsetZ")
			)
			-- Pivot at the shoulder rather than the arm's centre, so raising
			-- it swings the hand up instead of sliding the whole limb.
			local shoulder = cframe * CFrame.new(offset + Vector3.new(0, DIMS.ArmSize.Y / 2, 0))
			arm.CFrame = shoulder * CFrame.Angles(lift, 0, 0) * CFrame.new(0, -DIMS.ArmSize.Y / 2, 0)
		end
	end
end

function PassengerFigure.SetVisible(figure, visible)
	for _, part in ipairs(figure:GetChildren()) do
		if part:IsA("BasePart") then
			part.Transparency = visible and 0 or 1
		end
	end
end

--[[
	The cartoony black outline, applied to a CONTAINER holding many figures
	rather than to each one. Roblox only renders a limited number of
	Highlights at once (about 31), so one per figure would silently stop
	drawing as soon as a couple of stops were on screen.
]]
function PassengerFigure.Outline(container)
	if not Config.Outline.Enabled then
		return nil
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "ToonOutline"
	highlight.Adornee = container
	highlight.FillTransparency = 1
	highlight.OutlineColor = Config.Outline.Color
	highlight.OutlineTransparency = Config.Outline.Transparency
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = container
	return highlight
end

return PassengerFigure
