--[[
	GarageController.client.lua

	Builds a fully local, private garage scene: a cloned copy of your
	own avatar plus a cloned bus, positioned via GarageLayout, visible
	only on your screen. Your REAL character just freezes in place
	while the menu is open -- nothing about this replicates to the
	server or other players.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GarageSystem = ReplicatedStorage:WaitForChild("GarageSystem")
local UpgradeConfig = require(GarageSystem.Config.UpgradeConfig)
local BusBuilder = require(GarageSystem.Modules.BusBuilder)
local BusUpgradeApplier = require(GarageSystem.Modules.BusUpgradeApplier)
local GarageLayout = require(GarageSystem.Modules.GarageLayout)
local GarageGuiBuilder = require(script.Parent.GarageGuiBuilder)
local GarageSwapSequence = require(script.Parent.GarageSwapSequence)

local Remotes = GarageSystem:WaitForChild("Remotes")
local OpenGarage = Remotes:WaitForChild("OpenGarage")
local GarageReady = Remotes:WaitForChild("GarageReady")
local RequestSetLevel = Remotes:WaitForChild("RequestSetLevel")
local PendingLevelUpdated = Remotes:WaitForChild("PendingLevelUpdated")
local RequestConfirm = Remotes:WaitForChild("RequestConfirm")
local UpgradesConfirmed = Remotes:WaitForChild("UpgradesConfirmed")

local gui = GarageGuiBuilder.Build(playerGui)

local pendingLevels = {}
for _, category in ipairs(UpgradeConfig.Categories) do
	pendingLevels[category] = 0
end

local camera = workspace.CurrentCamera
local savedCameraType

-- Local-only scene state
local sceneFolder -- Folder holding the display clone + bus (client-only)
local displayCharacter
local displayBus
local layout

local function setRowsInteractable(enabled)
	gui.confirmButton.Active = enabled
	gui.confirmButton.AutoButtonColor = enabled
	for _, row in pairs(gui.rows) do
		row.minus.Active = enabled
		row.plus.Active = enabled
	end
end

local function refreshLevelLabel(category)
	local row = gui.rows[category]
	if row then
		row.levelLabel.Text = pendingLevels[category] .. " / " .. UpgradeConfig.MaxLevel
	end
end

local function freezeRealCharacter(frozen)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if frozen then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	else
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end
end

local function buildScene(confirmedState)
	sceneFolder = Instance.new("Folder")
	sceneFolder.Name = "LocalGarageScene"
	sceneFolder.Parent = workspace

	local anchorCFrame = GarageLayout.GetAnchorCFrame()
	layout = GarageLayout.Compute(anchorCFrame)

		-- Local-only clone of your own avatar -- never replicates anywhere.
	local realCharacter = player.Character
	if realCharacter then
		local wasArchivable = realCharacter.Archivable
		realCharacter.Archivable = true
		displayCharacter = realCharacter:Clone()
		realCharacter.Archivable = wasArchivable

		displayCharacter.Name = "GarageDisplayAvatar"
		local hrp = displayCharacter:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = true
		end
		for _, part in ipairs(displayCharacter:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
			end
		end
		displayCharacter:PivotTo(layout.player)
		displayCharacter.Parent = sceneFolder
	end

	displayBus = BusBuilder.BuildBaseBus(UpgradeConfig.DefaultChassisId)
	displayBus:PivotTo(layout.bus)
	BusUpgradeApplier.ApplyState(displayBus, confirmedState)
	displayBus.Parent = sceneFolder
end

local function destroyScene()
	if sceneFolder then
		sceneFolder:Destroy()
		sceneFolder = nil
	end
	displayCharacter = nil
	displayBus = nil
end

local function enterGarageCamera(cameraCFrame)
	savedCameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	local tween = TweenService:Create(
		camera,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = cameraCFrame }
	)
	tween:Play()
end

local function exitGarageCamera()
	camera.CameraType = savedCameraType or Enum.CameraType.Custom
end

-- Open / close --------------------------------------------------------------

gui.openButton.MouseButton1Click:Connect(function()
	OpenGarage:FireServer()
end)

gui.closeButton.MouseButton1Click:Connect(function()
	gui.panel.Visible = false
	destroyScene()
	exitGarageCamera()
	freezeRealCharacter(false)
end)

GarageReady.OnClientEvent:Connect(function(confirmedState)
	for category, level in pairs(confirmedState) do
		pendingLevels[category] = level
		refreshLevelLabel(category)
	end

	buildScene(confirmedState)
	freezeRealCharacter(true)
	gui.panel.Visible = true
	setRowsInteractable(true)
	enterGarageCamera(layout.camera)
end)

-- +/- buttons -----------------------------------------------------------------

for category, row in pairs(gui.rows) do
	row.minus.MouseButton1Click:Connect(function()
		local newLevel = math.max(UpgradeConfig.MinLevel, pendingLevels[category] - 1)
		if newLevel == pendingLevels[category] then
			return
		end
		RequestSetLevel:FireServer(category, newLevel)
	end)

	row.plus.MouseButton1Click:Connect(function()
		local newLevel = math.min(UpgradeConfig.MaxLevel, pendingLevels[category] + 1)
		if newLevel == pendingLevels[category] then
			return
		end
		RequestSetLevel:FireServer(category, newLevel)
	end)
end

PendingLevelUpdated.OnClientEvent:Connect(function(category, level)
	pendingLevels[category] = level
	refreshLevelLabel(category)
end)

-- Confirm -----------------------------------------------------------------

gui.confirmButton.MouseButton1Click:Connect(function()
	setRowsInteractable(false)
	RequestConfirm:FireServer()
end)

UpgradesConfirmed.OnClientEvent:Connect(function(confirmedState)
	for category, level in pairs(confirmedState) do
		pendingLevels[category] = level
	end

	if displayCharacter and displayBus and layout then
		GarageSwapSequence.Play(displayCharacter, displayBus, layout.player, layout.behind, confirmedState)
	end

	for category in pairs(confirmedState) do
		refreshLevelLabel(category)
	end
	setRowsInteractable(true)
end)