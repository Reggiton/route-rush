--[[
	GarageSwapSequence.lua

	Plays the jump-behind / smoke / swap / return sequence on the LOCAL
<<<<<<< HEAD
	display clone (not the player's real character or a networked bus)
	-- it's purely cosmetic, so it runs entirely client-side.

	The actual swap is passed in as `onHidden`, which runs while the
	smoke covers the bus. Safe to call even if the scene gets destroyed
	partway through (every step checks the instances still exist).
=======
	display clone (not the player's real character or a real networked
	bus) -- it's purely cosmetic, so it runs entirely client-side.
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642

	Tune the feel of the sequence via TIMING below.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

<<<<<<< HEAD
local GarageLayoutConfig = require(ReplicatedStorage:WaitForChild("GarageSystem").Config.GarageLayoutConfig)
=======
local GarageSystem = ReplicatedStorage:WaitForChild("GarageSystem")
local BusUpgradeApplier = require(GarageSystem.Modules.BusUpgradeApplier)
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642

local GarageSwapSequence = {}

local TIMING = {
<<<<<<< HEAD
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
=======
	jumpTravelTime = 0.35,
	smokeBuildUp = 0.35,
	smokeLinger = 0.9,
	returnTravelTime = 0.4,
}

local function moveCharacterTo(character, cframe, travelTime)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local tween = TweenService:Create(
		hrp,
		TweenInfo.new(travelTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = cframe }
	)
	tween:Play()
	tween.Completed:Wait()
end

local function burstSmoke(position)
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
	local anchor = Instance.new("Part")
	anchor.Name = "SmokeAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
<<<<<<< HEAD
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = parent or workspace
=======
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	emitter.Size = NumberSequence.new({
<<<<<<< HEAD
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
=======
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 6),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(4, 8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = anchor

	emitter:Emit(40)

	task.delay(TIMING.smokeBuildUp + TIMING.smokeLinger + 1.5, function()
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
		anchor:Destroy()
	end)
end

<<<<<<< HEAD
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
=======
-- Runs on the local display clone. Yields until finished.
function GarageSwapSequence.Play(displayCharacter, bus, standCFrame, behindCFrame, newState)
	local humanoid = displayCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.Jump = true
	moveCharacterTo(displayCharacter, behindCFrame, TIMING.jumpTravelTime)

	local busPosition = bus.PrimaryPart and bus.PrimaryPart.Position or behindCFrame.Position
	burstSmoke(busPosition)
	task.wait(TIMING.smokeBuildUp)

	BusUpgradeApplier.ApplyState(bus, newState)

	task.wait(TIMING.smokeLinger)
	moveCharacterTo(displayCharacter, standCFrame, TIMING.returnTravelTime)
end

return GarageSwapSequence
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
