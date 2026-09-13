--[[
	GarageSwapSequence.lua

	Plays the jump-behind / smoke / swap / return sequence on the LOCAL
	display clone (not the player's real character or a real networked
	bus) -- it's purely cosmetic, so it runs entirely client-side.

	Tune the feel of the sequence via TIMING below.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GarageSystem = ReplicatedStorage:WaitForChild("GarageSystem")
local BusUpgradeApplier = require(GarageSystem.Modules.BusUpgradeApplier)

local GarageSwapSequence = {}

local TIMING = {
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
	local anchor = Instance.new("Part")
	anchor.Name = "SmokeAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	emitter.Size = NumberSequence.new({
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
		anchor:Destroy()
	end)
end

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