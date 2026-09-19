--[[
	BusDriveController.lua

	Arcade bus physics, run on the DRIVER'S client (the server hands the
	bus's network ownership to them, so these forces replicate).

	  - Input: keyboard (W/S or arrows = throttle/brake-reverse, A/D or
	    arrows = steer), gamepad (left stick, R2/L2), and the PlayerModule
	    move vector as a fallback (touch thumbstick).
	    Space / gamepad X = handbrake. Ignored while typing in chat.
	  - Hover: raycast to the ground, hold the Root at its ride height.
	  - Stats: BusStats.Compute(chassis, levels, passengers), recomputed
	    whenever the Passengers attribute changes -- a loaded bus
	    accelerates, brakes, and corners worse.
	  - Grip: sideways velocity is damped while the tires hold. If the
	    cornering demand (speed x yaw rate) exceeds grip, the bus breaks
	    traction and slides until you calm it down.

	If the player presses throttle but the bus can't move, GetTelemetry()
	reports a `problem` string that the HUD shows.

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

local STICK_DEADZONE = 0.15
local STUCK_REPORT_SECONDS = 1

local controls
local function getControls()
	if controls == nil then
		local ok, playerModule = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5))
		end)
		controls = (ok and playerModule and playerModule:GetControls()) or false
	end
	return controls or nil
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
	if not active then
		return
	end
	local bus = active.bus
	active.stats = BusStats.Compute(bus:GetAttribute("ChassisId"), active.levels, bus:GetAttribute("Passengers") or 0)
end

local function headingOf(lookVector)
	return math.atan2(-lookVector.X, -lookVector.Z)
end

-- Input ---------------------------------------------------------------------------------

local function readInput()
	local throttle, steer, handbrake = 0, 0, false

	if not UserInputService:GetFocusedTextBox() then
		local function down(...)
			for _, keyCode in ipairs({ ... }) do
				if UserInputService:IsKeyDown(keyCode) then
					return true
				end
			end
			return false
		end
		if down(Enum.KeyCode.W, Enum.KeyCode.Up) then
			throttle = throttle + 1
		end
		if down(Enum.KeyCode.S, Enum.KeyCode.Down) then
			throttle = throttle - 1
		end
		if down(Enum.KeyCode.D, Enum.KeyCode.Right) then
			steer = steer + 1
		end
		if down(Enum.KeyCode.A, Enum.KeyCode.Left) then
			steer = steer - 1
		end
		handbrake = down(Enum.KeyCode.Space)
	end

	if UserInputService.GamepadEnabled then
		for _, input in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
				if math.abs(input.Position.X) > STICK_DEADZONE then
					steer = steer + input.Position.X
				end
				if math.abs(input.Position.Y) > STICK_DEADZONE then
					throttle = throttle + input.Position.Y
				end
			elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
				throttle = throttle + input.Position.Z
			elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
				throttle = throttle - input.Position.Z
			elseif input.KeyCode == Enum.KeyCode.ButtonX and input.UserInputState == Enum.UserInputState.Begin then
				handbrake = true
			end
		end
	end

	-- Touch thumbstick (and anything else the default controls understand).
	if throttle == 0 and steer == 0 then
		local controlModule = getControls()
		if controlModule then
			local move = controlModule:GetMoveVector()
			throttle = -move.Z
			steer = move.X
		end
	end

	return math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1), handbrake
end

-- Constraints ------------------------------------------------------------------------------

local function destroyConstraints()
	if active and active.constraints then
		for _, instance in ipairs(active.constraints.instances) do
			instance:Destroy()
		end
		active.constraints = nil
	end
end

local function buildConstraints(root)
	destroyConstraints()

	local attachment = Instance.new("Attachment")
	attachment.Name = "DriveAttachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "DriveVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.VectorVelocity = Vector3.zero
	pcall(function()
		linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	end)
	-- Per-axis limits let gravity work when airborne. Older engines only
	-- support a single magnitude limit, so fall back to that.
	local perAxis = pcall(function()
		linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		linearVelocity.MaxAxesForce = Vector3.zero
	end)
	if not perAxis then
		linearVelocity.MaxForce = 0
	end
	linearVelocity.Parent = root

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "DriveOrientation"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = C.MaxAlignTorque
	alignOrientation.Responsiveness = C.AlignResponsiveness
	alignOrientation.CFrame = root.CFrame.Rotation
	alignOrientation.Parent = root

	local look = root.CFrame.LookVector
	active.root = root
	active.heading = headingOf(Vector3.new(look.X, 0, look.Z))
	active.constraints = {
		instances = { linearVelocity, alignOrientation, attachment },
		linearVelocity = linearVelocity,
		alignOrientation = alignOrientation,
		perAxis = perAxis,
	}
end

-- Simulation step -------------------------------------------------------------------------------

local function step(dt)
	local bus = active.bus
	local root = bus.PrimaryPart or bus:FindFirstChild("Root")
	local throttle, steer, handbrake = readInput()
	active.throttle = throttle

	-- With streaming enabled the root can be replaced; follow it.
	if not root then
		active.problem = "Waiting for your bus to load"
		return
	end
	if root ~= active.root or not active.constraints or not active.constraints.linearVelocity.Parent then
		buildConstraints(root)
	end

	local velocity = root.AssemblyLinearVelocity
	local up = Vector3.yAxis
	local look = root.CFrame.LookVector
	local flatForward = Vector3.new(look.X, 0, look.Z)
	flatForward = flatForward.Magnitude > 0.01 and flatForward.Unit or -Vector3.zAxis
	local right = flatForward:Cross(up)
	local forwardSpeed = velocity:Dot(flatForward)
	local lateralSpeed = velocity:Dot(right)
	active.speed = forwardSpeed

	-- Diagnose "pressing W but nothing happens"
	if math.abs(throttle) > 0.2 and math.abs(forwardSpeed) < 1 then
		active.stuckTime = active.stuckTime + dt
	else
		active.stuckTime = 0
	end

	if root.Anchored then
		active.problem = active.stuckTime > STUCK_REPORT_SECONDS and "Bus is still parked (anchored) — wait for GO" or nil
		return
	end

	local stats = active.stats
	if bus:GetAttribute("BrokenDown") then
		throttle, steer, handbrake = 0, steer * 0.3, false
	end

	-- RouteWars item effects (WeaponService sets these attributes; nothing
	-- here if you were never hit). "Until" timestamps are server time, since
	-- WeaponService is a server script and this clock has to agree with it.
	local now = workspace:GetServerTimeNow()
	local topSpeedMult, accelMult, gripMult, steerMult = 1, 1, 1, 1

	-- Limping after a breakdown: one system comes back wrong and recovers
	-- over DrivingConfig.Impair.Seconds. Which one is decided by the server
	-- (BusMonitor) so it can't be wished away by the client.
	local impairUntil = bus:GetAttribute("ImpairUntil")
	if impairUntil and now < impairUntil then
		local kind = bus:GetAttribute("ImpairKind")
		if kind == "Accel" then
			accelMult = accelMult * DrivingConfig.Impair.AccelMultiplier
		elseif kind == "Steer" then
			steerMult = steerMult * DrivingConfig.Impair.SteerMultiplier
		end
	end
	local boostUntil = bus:GetAttribute("BoostUntil")
	if boostUntil and now < boostUntil then
		topSpeedMult = topSpeedMult * (bus:GetAttribute("BoostSpeedMult") or 1)
		accelMult = accelMult * (bus:GetAttribute("BoostAccelMult") or 1)
	end
	local slowUntil = bus:GetAttribute("SlowUntil")
	if slowUntil and now < slowUntil then
		topSpeedMult = topSpeedMult * (bus:GetAttribute("SlowMultiplier") or 1)
	end
	if bus:GetAttribute("OnSlick") then
		gripMult = gripMult * (bus:GetAttribute("SlickGripMult") or 1)
	end

	-- Ground
	local rootHeight = bus:GetAttribute("RootHeight") or 4
	local hit = workspace:Raycast(root.Position, -up * (rootHeight + C.GroundRayLength), active.rayParams)
	local grounded = hit ~= nil
	local normal = grounded and hit.Normal or up

	-- Longitudinal
	local topSpeed = stats.topSpeed * topSpeedMult
	local accel = stats.accel * accelMult
	if not grounded then
		throttle = 0
	end
	if throttle > 0 then
		if forwardSpeed < -1 then
			forwardSpeed = approach(forwardSpeed, 0, stats.brakeDecel * throttle * dt)
		elseif forwardSpeed < topSpeed then
			forwardSpeed = math.min(topSpeed, forwardSpeed + accel * throttle * dt)
		else
			forwardSpeed = approach(forwardSpeed, topSpeed, C.CoastDecel * dt)
		end
	elseif throttle < 0 then
		if forwardSpeed > 1 then
			forwardSpeed = approach(forwardSpeed, 0, stats.brakeDecel * -throttle * dt)
		else
			forwardSpeed = math.max(-topSpeed * C.ReverseSpeedFraction, forwardSpeed - accel * 0.6 * -throttle * dt)
		end
	elseif grounded then
		forwardSpeed = approach(forwardSpeed, 0, C.CoastDecel * dt)
	end
	if handbrake and grounded then
		forwardSpeed = approach(forwardSpeed, 0, C.HandbrakeDecel * dt)
	end

	-- A mine's veer: a lateral bias blended into your own steering input for
	-- a few seconds, so it works WITH the drive controller instead of
	-- fighting a physics impulse the LinearVelocity constraint would just
	-- override next frame.
	local veerUntil = bus:GetAttribute("VeerUntil")
	if veerUntil and now < veerUntil then
		steer = math.clamp(steer + (bus:GetAttribute("VeerBias") or 0), -1, 1)
	end

	-- Steering
	local absSpeed = math.abs(forwardSpeed)
	local lowSpeedFactor = math.clamp(absSpeed / C.FullSteerSpeed, 0, 1)
	local highSpeedFactor = 1 + (C.HighSpeedSteerFactor - 1) * math.clamp(absSpeed / topSpeed, 0, 1)
	local direction = forwardSpeed >= 0 and 1 or -1
	local yawRate = grounded and (-steer * stats.turnRate * lowSpeedFactor * highSpeedFactor * direction) or 0

	-- Grip / slide
	local grip = stats.grip * gripMult
	local gripLimit = grip * (handbrake and C.HandbrakeGripFactor or 1)
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
	local driveForce = mass * C.DriveForcePerMass
	local verticalVelocity, verticalForce
	if grounded then
		local height = root.Position.Y - hit.Position.Y
		verticalVelocity = math.clamp((rootHeight - height) * C.HoverStiffness, -30, 30)
		verticalForce = mass * workspace.Gravity * 3
	else
		verticalVelocity = velocity.Y - workspace.Gravity * dt
		verticalForce = 0
	end

	local constraints = active.constraints
	constraints.linearVelocity.VectorVelocity = Vector3.new(horizontal.X, verticalVelocity, horizontal.Z)
	if constraints.perAxis then
		constraints.linearVelocity.MaxAxesForce = Vector3.new(driveForce, verticalForce, driveForce)
	else
		constraints.linearVelocity.MaxForce = math.max(driveForce, verticalForce)
	end

	-- Orientation: heading on the ground plane, plus a little body roll under load
	local headingForward = CFrame.Angles(0, active.heading, 0).LookVector
	local planeForward = headingForward - normal * headingForward:Dot(normal)
	planeForward = planeForward.Magnitude > 0.01 and planeForward.Unit or headingForward
	local planeRight = planeForward:Cross(normal)
	local rollAmount = math.clamp(forwardSpeed * yawRate / math.max(grip, 1), -1, 1) * (0.4 + 0.6 * stats.load)
	constraints.alignOrientation.CFrame = CFrame.fromMatrix(Vector3.zero, planeRight, normal)
		* CFrame.Angles(0, 0, math.rad(C.BodyRollMaxDegrees * rollAmount))

	-- Report why the bus might not be moving.
	if active.stuckTime > STUCK_REPORT_SECONDS then
		if root.ReceiveAge > 0.25 then
			active.problem = "Server hasn't given you control of the bus yet"
		elseif not grounded then
			active.problem = "No road detected under the bus"
		else
			active.problem = "Throttle pressed but the bus is blocked"
		end
	else
		active.problem = nil
	end
end

-- Public API ------------------------------------------------------------------------------------------

function BusDriveController.Start(bus)
	BusDriveController.Stop()

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

	active = {
		bus = bus,
		root = nil,
		constraints = nil,
		levels = readLevels(bus),
		rayParams = rayParams,
		heading = 0,
		sliding = false,
		steerSmoothed = 0,
		calm = 0,
		speed = 0,
		throttle = 0,
		stuckTime = 0,
		problem = nil,
		errorReported = false,
		connections = {},
	}
	refreshStats()

	local myActive = active
	table.insert(active.connections, bus:GetAttributeChangedSignal("Passengers"):Connect(refreshStats))
	table.insert(active.connections, RunService.PreSimulation:Connect(function(dt)
		if active ~= myActive then
			return
		end
		local ok, err = pcall(step, dt)
		if not ok then
			active.problem = "Drive error: " .. tostring(err)
			if not active.errorReported then
				active.errorReported = true
				warn("[BusDriveController] " .. tostring(err))
			end
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
	for _, connection in ipairs(active.connections) do
		connection:Disconnect()
	end
	destroyConstraints()
	active = nil
end

-- For the HUD.
function BusDriveController.GetTelemetry()
	if not active or not active.stats then
		return nil
	end
	return {
		speed = active.speed,
		sliding = active.sliding,
		stats = active.stats,
		throttle = active.throttle,
		problem = active.problem,
	}
end

return BusDriveController
