--[[
	GarageLayout.lua

	Turns a single stall origin into the camera/player/bus/behind
	CFrames, using GarageLayoutConfig.

	GetAnchorCFrame() looks for a Part named "GarageAnchor" inside a
	"GarageScene" folder/model in Workspace -- place one there whenever
	you build a real garage room, and the whole scene follows it
	automatically. Until then, it falls back to a fixed spot so
	everything keeps working.
]]

local GarageLayoutConfig = require(script.Parent.Parent.Config.GarageLayoutConfig)

local GarageLayout = {}

local FALLBACK_ORIGIN = Vector3.new(0, 10, 500)

function GarageLayout.GetAnchorCFrame()
	local scene = workspace:FindFirstChild("GarageScene")
	local anchorPart = scene and scene:FindFirstChild("GarageAnchor")
	if anchorPart and anchorPart:IsA("BasePart") then
		return anchorPart.CFrame
	end
	return CFrame.new(FALLBACK_ORIGIN)
end

local function place(anchorCFrame, offsetCfg)
	local position = anchorCFrame.Position
		+ anchorCFrame.LookVector * offsetCfg.Forward
		+ anchorCFrame.RightVector * offsetCfg.Right
		+ Vector3.new(0, offsetCfg.Up, 0)

	if offsetCfg.FacingDegrees then
		local rotationOnly = (anchorCFrame - anchorCFrame.Position) * CFrame.Angles(0, math.rad(offsetCfg.FacingDegrees), 0)
		return CFrame.new(position) * rotationOnly
	end

	return CFrame.new(position)
end

function GarageLayout.Compute(anchorCFrame)
	local camPlacement = place(anchorCFrame, GarageLayoutConfig.Camera)

	local aimCfg = GarageLayoutConfig.CameraAim
	local aimPoint = anchorCFrame.Position
		+ anchorCFrame.LookVector * aimCfg.Forward
		+ anchorCFrame.RightVector * aimCfg.Right
		+ Vector3.new(0, aimCfg.Up, 0)
	local cameraCFrame = CFrame.lookAt(camPlacement.Position, aimPoint)

	return {
		camera = cameraCFrame,
		player = place(anchorCFrame, GarageLayoutConfig.Player),
		bus = place(anchorCFrame, GarageLayoutConfig.Bus),
		behind = place(anchorCFrame, GarageLayoutConfig.Behind),
	}
end

return GarageLayout