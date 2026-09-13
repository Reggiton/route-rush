--[[
	ChaseCamera.lua

	Smoothed follow camera behind and above your bus, pulled further back
	for longer chassis. Press C (or gamepad R3) to toggle back to the
	default Roblox camera.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local ChaseCamera = {}

local BIND_NAME = "RouteRushChaseCamera"
local TOGGLE_ACTION = "RouteRushToggleCamera"

local camera = workspace.CurrentCamera
local currentBus
local chaseEnabled = true
local savedCameraType

local function update(dt)
	local bus = currentBus
	local root = bus and bus.PrimaryPart
	if not root or not root.Parent or not chaseEnabled then
		return
	end

	local length = bus:GetAttribute("BusLength") or 20
	local look = root.CFrame.LookVector
	local flatForward = Vector3.new(look.X, 0, look.Z)
	flatForward = flatForward.Magnitude > 0.01 and flatForward.Unit or -Vector3.zAxis

	local distance = 18 + length * 0.9
	local height = 7 + length * 0.3
	local position = root.Position - flatForward * distance + Vector3.new(0, height, 0)
	local focus = root.Position + flatForward * 12 + Vector3.new(0, 3, 0)

	camera.CameraType = Enum.CameraType.Scriptable
	local alpha = 1 - math.exp(-8 * dt)
	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(position, focus), alpha)
end

local function applyMode()
	if chaseEnabled then
		camera.CameraType = Enum.CameraType.Scriptable
	else
		camera.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

function ChaseCamera.Start(bus)
	ChaseCamera.Stop()
	currentBus = bus
	savedCameraType = camera.CameraType
	chaseEnabled = true
	applyMode()

	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, update)
	ContextActionService:BindAction(TOGGLE_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			chaseEnabled = not chaseEnabled
			applyMode()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonR3)
end

function ChaseCamera.Stop()
	if not currentBus then
		return
	end
	currentBus = nil
	RunService:UnbindFromRenderStep(BIND_NAME)
	ContextActionService:UnbindAction(TOGGLE_ACTION)
	camera.CameraType = savedCameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom
		or (savedCameraType or Enum.CameraType.Custom)
	savedCameraType = nil
end

return ChaseCamera
