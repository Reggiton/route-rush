--[[
	GarageSwapSequence.lua

	Plays the jump-behind / smoke / swap / return sequence on the LOCAL
	display clone (not the player's real character or a networked bus)
	-- it's purely cosmetic, so it runs entirely client-side.

	The actual swap is passed in as `onHidden`, which runs while the
	smoke covers the bus. Safe to call even if the scene gets destroyed
	partway through (every step checks the instances still exist).

	Tune the feel of the sequence via TIMING below.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GarageLayoutConfig = require(ReplicatedStorage:WaitForChild("GarageSystem").Config.GarageLayoutConfig)

local GarageSwapSequence = {}

local TIMING = {
	jumpTravelTime = 0.45,
	smokeBuildUp = 0.35,
	smokeLinger = 0.9,
	returnTravelTime = 0.5,
}

-- Moves a whole character model along a parabolic arc with PivotTo
-- (never by setting HumanoidRootPart.CFrame, which the rig's joints fight).
local function arcTo(character, targetCFrame, travelTime, arcHeight)
	if not character.Parent then
		return
	end
	local startCFrame = character:GetPivot()

	local alpha = Instance.new("NumberValue")
	alpha.Value = 0
	local connection = alpha.Changed:Connect(function(a)
		if character.Parent then
			local lift = 4 * arcHeight * a * (1 - a)
			character:PivotTo(startCFrame:Lerp(targetCFrame, a) + Vector3.new(0, lift, 0))
		end
	end)

	local tween = TweenService:Create(alpha, TweenInfo.new(travelTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Value = 1,
	})
	tween:Play()
	tween.Completed:Wait()

	connection:Disconnect()
	alpha:Destroy()
end

local function burstSmoke(position, parent)
	local anchor = Instance.new("Part")
	anchor.Name = "SmokeAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = parent or workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(1, 9),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.9, 1.6)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = anchor

	emitter:Emit(60)

	task.delay(TIMING.smokeBuildUp + TIMING.smokeLinger + 2, function()
		anchor:Destroy()
	end)
end

-- Smoke only: puff, run onHidden while covered, linger. Yields.
function GarageSwapSequence.SmokeSwap(smokePosition, sceneParent, onHidden)
	burstSmoke(smokePosition, sceneParent)
	task.wait(TIMING.smokeBuildUp)
	onHidden()
	task.wait(TIMING.smokeLinger)
end

-- Full sequence on the display clone. Yields until finished.
function GarageSwapSequence.Play(displayCharacter, standCFrame, behindCFrame, smokePosition, sceneParent, onHidden)
	local arcHeight = GarageLayoutConfig.JumpArcHeight or 6

	arcTo(displayCharacter, behindCFrame, TIMING.jumpTravelTime, arcHeight)
	GarageSwapSequence.SmokeSwap(smokePosition, sceneParent, onHidden)
	arcTo(displayCharacter, standCFrame, TIMING.returnTravelTime, arcHeight * 0.5)
end

return GarageSwapSequence
