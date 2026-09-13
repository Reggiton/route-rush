--[[
	BusDriveController.lua

	Arcade bus physics, run on the DRIVER'S client (the server hands the
	bus's network ownership to them, so these forces replicate).

	  - Input: PlayerModule move vector (keyboard, gamepad, touch stick).
	    Forward/back = throttle/brake-reverse, left/right = steer.
	    Space / gamepad X = handbrake.
	  - Hover: raycast to the ground, hold the Root at its ride height.
	  - Stats: BusStats.Compute(chassis, levels, passengers), recomputed
	    whenever the Passengers attribute changes -- a loaded bus
	    accelerates, brakes, and corners worse.
	  - Grip: sideways velocity is damped while the tires hold. If the
	    cornering demand (speed x yaw rate) exceeds grip, the bus breaks
	    traction and slides until you calm it down.

	Tuning lives in DrivingConfig.Controller; stats in BusStats.lua.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("GarageSystem").Config.UpgradeConfig)
local DrivingConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.DrivingConfig)
local BusStats = require(ReplicatedStorage.Shared.Modules.BusStats)

local C = DrivingConfig.Controller
local player = Players.LocalPlayer

local BusDriveController = {}

local controls
local function getControls()
	if not controls then
		local ok, playerModule = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		end)
		controls = ok and playerModule:GetControls() or nil
	end
	return controls
end

local active -- current session state, or nil

local function approach(value, target, step)
	if value < target then
		return math.min(value + step, target)
	end
	return math.max(value - step, target)
end

local function readLevels(bus)
	local levels = {}
	for _, category in ipairs(UpgradeConfig.Categories) do
		levels[category] = bus:GetAttribute("Lv_" .. category) or 0
	end
	return levels
end

local function refreshStats()
	local bus = active.bus
	active.stats = BusStats.Compute(bus:GetAttribute("ChassisId"), active.levels, bus:GetAttribute("Passengers") or 0)
end

local function headingOf(lookVector)
	return math.atan2(-lookVector.X, -lookVector.Z)
end

local function handbrakeHeld()
	return UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonX)
end

local function step(dt)
	local bus = active.bus
	local root = active.root
	if not bus.Parent or not root.Parent or root.Anchored then
		return
	end

	local stats = active.stats
	local up = Vector3.yAxis

	-- Input
	local move = Vector3.zero
	local controlModule = getControls()
	if controlModule then
		move = controlModule:GetMoveVector()
	end
	local throttle = math.clamp(-move.Z, -1, 1)
	local steer = math.clamp(move.X, -1, 1)
	local handbrake = handbrakeHeld()
	if bus:GetAttribute("BrokenDown") then
		throttle, steer, handbrake = 0, steer * 0.3, false
	end

	-- Ground
	local rootHeight = bus:GetAttribute("RootHeight") or 4
	local hit = workspace:Raycast(root.Position, -up * (rootHeight + C.GroundRayLength), active.rayParams)
	local grounded = hit ~= nil
	local normal = grounded and hit.Normal or up

	-- Frame
	local look = root.CFrame.LookVector
	local flatForward = Vector3.new(look.X, 0, look.Z)
	flatForward = flatForward.Magnitude > 0.01 and flatForward.Unit or -Vector3.zAxis
	local right = flatForward:Cross(up)

	local velocity = root.AssemblyLinearVelocity
	local forwardSpeed = velocity:Dot(flatForward)
	local lateralSpeed = velocity:Dot(right)

	-- Longitudinal
	local topSpeed = stats.topSpeed
	if not grounded then
		throttle = 0
	end
	if throttle > 0 then
		if forwardSpeed < -1 then
			forwardSpeed = approach(forwardSpeed, 0, stats.brakeDecel * throttle * dt)
		elseif forwardSpeed < topSpeed then
			forwardSpeed = math.min(topSpeed, forwardSpeed + stats.accel * throttle * dt)
		else
			forwardSpeed = approach(forwardSpeed, topSpeed, C.CoastDecel * dt)
		end
	elseif throttle < 0 then
		if forwardSpeed > 1 then
			forwardSpeed = approach(forwardSpeed, 0, stats.brakeDecel * -throttle * dt)
		else
			forwardSpeed = math.max(-topSpeed * C.ReverseSpeedFraction, forwardSpeed - stats.accel * 0.6 * -throttle * dt)
		end
	elseif grounded then
		forwardSpeed = approach(forwardSpeed, 0, C.CoastDecel * dt)
	end
	if handbrake and grounded then
		forwardSpeed = approach(forwardSpeed, 0, C.HandbrakeDecel * dt)
	end

	-- Steering
	local absSpeed = math.abs(forwardSpeed)
	local lowSpeedFactor = math.clamp(absSpeed / C.FullSteerSpeed, 0, 1)
	local highSpeedFactor = 1 + (C.HighSpeedSteerFactor - 1) * math.clamp(absSpeed / topSpeed, 0, 1)
	local direction = forwardSpeed >= 0 and 1 or -1
	local yawRate = grounded and (-steer * stats.turnRate * lowSpeedFactor * highSpeedFactor * direction) or 0

	-- Grip / slide
	local gripLimit = stats.grip * (handbrake and C.HandbrakeGripFactor or 1)
	local demand = math.abs(forwardSpeed * yawRate)
	if demand > gripLimit then
		active.sliding = true
		active.calm = 0
	elseif active.sliding then
		active.calm = active.calm + dt
		if active.calm >= C.GripRecoverTime then
			active.sliding = false
		end
	end
	if active.sliding then
		yawRate = yawRate * 0.75
	end
	local damping = C.LateralDamping * (active.sliding and C.SlideGripFactor or 1)
	if grounded then
		lateralSpeed = lateralSpeed * math.exp(-damping * dt)
	end

	-- Heading (integrated separately so the target never lags behind itself)
	local actualHeading = headingOf(flatForward)
	local drift = math.abs((active.heading - actualHeading + math.pi) % (2 * math.pi) - math.pi)
	if drift > math.rad(C.HeadingResyncDegrees) then
		active.heading = actualHeading
	end
	active.heading = active.heading + yawRate * dt

	-- Drive velocity
	local horizontal = flatForward * forwardSpeed + right * lateralSpeed
	local mass = root.AssemblyMass
	local verticalVelocity, verticalForce = 0, 0
	if grounded then
		local height = root.Position.Y - hit.Position.Y
		verticalVelocity = math.clamp((rootHeight - height) * C.HoverStiffness, -30, 30)
		verticalForce = mass * workspace.Gravity * 3
	end
	active.linearVelocity.VectorVelocity = Vector3.new(horizontal.X, verticalVelocity, horizontal.Z)
	active.linearVelocity.MaxAxesForce = Vector3.new(mass * C.DriveForcePerMass, verticalForce, mass * C.DriveForcePerMass)

	-- Orientation: heading on the ground plane, plus a little body roll under load
	local headingForward = CFrame.Angles(0, active.heading, 0).LookVector
	local planeForward = (headingForward - normal * headingForward:Dot(normal))
	planeForward = planeForward.Magnitude > 0.01 and planeForward.Unit or headingForward
	local planeRight = planeForward:Cross(normal)
	local rollAmount = math.clamp(forwardSpeed * yawRate / math.max(stats.grip, 1), -1, 1) * (0.4 + 0.6 * stats.load)
	active.alignOrientation.CFrame = CFrame.fromMatrix(Vector3.zero, planeRight, normal)
		* CFrame.Angles(0, 0, math.rad(C.BodyRollMaxDegrees * rollAmount))

	active.speed = forwardSpeed
end

function BusDriveController.Start(bus)
	BusDriveController.Stop()

	local root = bus.PrimaryPart
	if not root then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "DriveAttachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "DriveVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	linearVelocity.MaxAxesForce = Vector3.zero
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.Parent = root

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "DriveOrientation"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = C.MaxAlignTorque
	alignOrientation.Responsiveness = C.AlignResponsiveness
	alignOrientation.CFrame = root.CFrame.Rotation
	alignOrientation.Parent = root

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { bus }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local instances = workspace:FindFirstChild("RouteInstances")
	if instances then
		for _, track in ipairs(instances:GetChildren()) do
			local buses = track:FindFirstChild("Buses")
			if buses then
				table.insert(exclude, buses)
			end
		end
	end
	rayParams.FilterDescendantsInstances = exclude

	local look = root.CFrame.LookVector
	active = {
		bus = bus,
		root = root,
		levels = readLevels(bus),
		attachment = attachment,
		linearVelocity = linearVelocity,
		alignOrientation = alignOrientation,
		rayParams = rayParams,
		heading = headingOf(Vector3.new(look.X, 0, look.Z)),
		sliding = false,
		calm = 0,
		speed = 0,
		connections = {},
	}
	refreshStats()

	table.insert(active.connections, bus:GetAttributeChangedSignal("Passengers"):Connect(refreshStats))
	table.insert(active.connections, RunService.PreSimulation:Connect(function(dt)
		if active then
			step(dt)
		end
	end))
	table.insert(active.connections, bus.AncestryChanged:Connect(function()
		if not bus:IsDescendantOf(workspace) then
			BusDriveController.Stop()
		end
	end))
end

function BusDriveController.Stop()
	if not active then
		return
	end
	local current = active
	active = nil
	for _, connection in ipairs(current.connections) do
		connection:Disconnect()
	end
	current.linearVelocity:Destroy()
	current.alignOrientation:Destroy()
	current.attachment:Destroy()
end

-- For the HUD.
function BusDriveController.GetTelemetry()
	if not active then
		return nil
	end
	return {
		speed = active.speed,
		sliding = active.sliding,
		stats = active.stats,
	}
end

return BusDriveController
