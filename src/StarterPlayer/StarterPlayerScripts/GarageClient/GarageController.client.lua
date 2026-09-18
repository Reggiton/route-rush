--[[
	GarageController.client.lua

	Builds a fully local, private garage showroom: a cloned copy of your
	own avatar plus every chassis tier parked in its own bay, positioned
	via GarageLayout, visible only on your screen. Picking a chassis pans
	the camera to its bay. Your REAL character just freezes in place while the menu
	is open -- nothing about the scene replicates anywhere.

	The server is authoritative for levels, cash, and chassis. Every
	garage remote delivers a full state table; this script renders it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GarageSystem = ReplicatedStorage:WaitForChild("GarageSystem")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(GarageSystem.Config.UpgradeConfig)
local BusBuilder = require(GarageSystem.Modules.BusBuilder)
local BusUpgradeApplier = require(GarageSystem.Modules.BusUpgradeApplier)
local GarageLayout = require(GarageSystem.Modules.GarageLayout)
local GarageLayoutConfig = require(GarageSystem.Config.GarageLayoutConfig)
local UpgradeCatalog = require(GarageSystem.Config.UpgradeCatalog)
local BusStats = require(Shared.Modules.BusStats)
local Restoration = require(Shared.Modules.Restoration)
local GarageGuiBuilder = require(script.Parent.GarageGuiBuilder)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local OpenGarage = Remotes:WaitForChild("OpenGarage")
local CloseGarage = Remotes:WaitForChild("CloseGarage")
local GarageReady = Remotes:WaitForChild("GarageReady")
local GarageClosed = Remotes:WaitForChild("GarageClosed")
local RequestSetLevel = Remotes:WaitForChild("RequestSetLevel")
local PendingLevelUpdated = Remotes:WaitForChild("PendingLevelUpdated")
local RequestSelectChassis = Remotes:WaitForChild("RequestSelectChassis")
local ChassisPreviewUpdated = Remotes:WaitForChild("ChassisPreviewUpdated")
local RequestConfirm = Remotes:WaitForChild("RequestConfirm")
local UpgradesConfirmed = Remotes:WaitForChild("UpgradesConfirmed")
local GarageError = Remotes:WaitForChild("GarageError")


local gui = GarageGuiBuilder.Build(playerGui)
local camera = workspace.CurrentCamera

local state -- last garage state from the server
local isOpen = false
local openRequested = false
local swapping = false

-- Local-only scene
local sceneFolder
local displayCharacter
local displayBuses = {} -- [chassisId] = parked model, one per bay
local displayedChassisId
local layout
local savedCameraType
local savedMovement

-- Formatting --------------------------------------------------------------------------

local function formatCash(amount)
	local sign = amount < 0 and "-" or ""
	local digits = tostring(math.floor(math.abs(amount)))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return sign .. "$" .. formatted
end

local STAT_TEXT = {
	Engine = function(s)
		return string.format("Top speed %d", math.floor(s.topSpeed))
	end,
	Accel = function(s)
		return string.format("Accel %.1f", s.accel)
	end,
	Brakes = function(s)
		return string.format("Brakes %.1f", s.brakeDecel)
	end,
	Handles = function(s)
		return string.format("Seats %d · Grip %d", s.capacity, math.floor(s.grip))
	end,
	Health = function(s)
		return string.format("HP %d", s.maxHealth)
	end,
}

-- Rendering ------------------------------------------------------------------------------

local function render()
	if not state then
		return
	end

	gui.headerLabel.Text = string.format("%s  ·  Level %d  ·  Rep %d", formatCash(state.cash), state.level, state.reputation)

	local slotsText = string.format("Slots %d/%d Unlocked", state.quote.slotsAfter, state.unlockedSlots)
	if state.nextUnlockReputation then
		slotsText = slotsText .. string.format(" (more at %d Rep)", state.nextUnlockReputation)
	end
	gui.slotsLabel.Text = slotsText

	gui.chassisName.Text = string.format("Tier %d · %s", state.tierIndex, state.displayName)
	if state.owned then
		local fraction = Restoration.Fraction(state.chassisId, state.pending)
		local bonus = Restoration.FareMultiplier(state.chassisId, state.pending) - 1
		gui.chassisSub.Text = string.format(
			"%s - %d%% restored (+%d%% Fares)",
			state.selected and "Driving this bus" or "Owned",
			math.floor(fraction * 100 + 0.5),
			math.floor(bonus * 100 + 0.5)
		)
	else
		gui.chassisSub.Text = string.format("Locked · Level %d · %s", state.requiredLevel, formatCash(state.price))
	end

	local before = BusStats.Compute(state.chassisId, state.confirmed, 0)
	local after = BusStats.Compute(state.chassisId, state.pending, 0)
	for category, row in pairs(gui.rows) do
		local level = state.pending[category]
		local confirmedLevel = state.confirmed[category]
		row.levelLabel.Text = level .. " / " .. UpgradeConfig.MaxLevel
		local entry = UpgradeCatalog.Get(state.chassisId, category, level)
		row.nameLabel.Text = category .. " · " .. (entry and entry.name or "Stock")
		row.levelLabel.TextColor3 = level > confirmedLevel and Color3.fromRGB(70, 212, 140)
			or level < confirmedLevel and Color3.fromRGB(255, 166, 64)
			or Color3.fromRGB(242, 244, 248)

		local describe = STAT_TEXT[category]
		if describe then
			local oldText, newText = describe(before), describe(after)
			row.statLabel.Text = oldText == newText and newText or (oldText .. "  →  " .. newText)
		end

		row.minus.Interactable = not swapping and state.owned and level > UpgradeConfig.MinLevel
		row.plus.Interactable = not swapping and state.owned and level < UpgradeConfig.MaxLevel
	end

	local quote = state.quote
	if not state.owned then
		gui.quoteLabel.Text = state.blockReason or ("Buy this chassis for " .. formatCash(state.price))
		gui.confirmLabel.Text = "Buy " .. formatCash(state.price)
	elseif quote.added + quote.removed == 0 then
		gui.quoteLabel.Text = state.selected and "No changes" or (state.blockReason or "Switch to this bus")
		gui.confirmLabel.Text = state.selected and "Confirm" or "Drive this bus"
	else
		local netText = quote.net >= 0 and ("Net -" .. formatCash(quote.net)) or ("Net +" .. formatCash(-quote.net))
		gui.quoteLabel.Text = string.format("Cost %s · Refund %s · %s", formatCash(quote.cost), formatCash(quote.refund), netText)
		if state.blockReason then
			gui.quoteLabel.Text = gui.quoteLabel.Text .. " · " .. state.blockReason
		end
		gui.confirmLabel.Text = "Confirm"
	end

	gui.confirmButton.Interactable = not swapping and state.canConfirm
	gui.chassisPrev.Interactable = not swapping and state.tierIndex > 1
	gui.chassisNext.Interactable = not swapping and state.tierIndex < state.tierCount
end

local toastToken = 0
local function showToast(message)
	toastToken = toastToken + 1
	local myToken = toastToken
	gui.toast.Text = message
	gui.toast.Visible = true
	task.delay(2.5, function()
		if toastToken == myToken then
			gui.toast.Visible = false
		end
	end)
end

-- Real character ------------------------------------------------------------------------------

local function freezeRealCharacter(frozen)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if frozen then
		if not savedMovement then
			savedMovement = {
				humanoid = humanoid,
				WalkSpeed = humanoid.WalkSpeed,
				JumpPower = humanoid.JumpPower,
				JumpHeight = humanoid.JumpHeight,
			}
		end
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	elseif savedMovement then
		if savedMovement.humanoid == humanoid then
			humanoid.WalkSpeed = savedMovement.WalkSpeed
			humanoid.JumpPower = savedMovement.JumpPower
			humanoid.JumpHeight = savedMovement.JumpHeight
		end
		savedMovement = nil
	end
end

-- Scene -------------------------------------------------------------------------------------------

-- Which parking spot a chassis lives in: tier order, so Tier1 is bay 1.
local function spotIndexFor(chassisId)
	for index, tier in ipairs(UpgradeConfig.ChassisTiers) do
		if tier.id == chassisId then
			return index
		end
	end
	return 1
end

local function spotFor(chassisId)
	return layout and layout.spots[spotIndexFor(chassisId)]
end

-- Builds one bus into its own bay, wearing that chassis's own upgrades.
local function setDisplayBus(chassisId, levels)
	local spot = spotFor(chassisId)
	if not spot then
		return
	end
	local existing = displayBuses[chassisId]
	if existing then
		existing:Destroy()
	end

	local bus = BusBuilder.BuildBaseBus(chassisId, { anchored = true })
	-- Upgrades bolt on extra parts, so ground the bus AFTER they are attached or
	-- the measurement misses them and a bull-bar or roof rack pushes it off the floor.
	BusUpgradeApplier.ApplyState(bus, levels)
	GarageLayout.GroundModel(bus, spot.bus)
	bus.Parent = sceneFolder
	displayBuses[chassisId] = bus
end

-- Slides the camera (and the avatar with it) to a chassis's bay. This replaces
-- the old smoke-and-swap: every bus is already parked, so there is nothing to
-- hide -- the pan itself is the transition.
local function panToChassis(chassisId, instant)
	local spot = spotFor(chassisId)
	if not spot then
		return
	end
	displayedChassisId = chassisId

	local panTime = instant and 0 or GarageLayoutConfig.SpotPanTime
	if panTime <= 0 then
		camera.CFrame = spot.camera
		if displayCharacter then
			displayCharacter:PivotTo(spot.player)
		end
		return
	end

	local info = TweenInfo.new(panTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(camera, info, { CFrame = spot.camera }):Play()

	-- The avatar rides along so it stays beside whichever bus you are looking
	-- at. PivotTo moves the whole rig; tweening a CFrame value drives it.
	local character = displayCharacter
	if character then
		local startCFrame = character:GetPivot()
		local alpha = Instance.new("NumberValue")
		alpha.Value = 0
		local connection = alpha.Changed:Connect(function(a)
			if character.Parent then
				character:PivotTo(startCFrame:Lerp(spot.player, a))
			end
		end)
		local tween = TweenService:Create(alpha, info, { Value = 1 })
		tween.Completed:Connect(function()
			connection:Disconnect()
			alpha:Destroy()
		end)
		tween:Play()
	end
end

local function buildScene(garageState)
	sceneFolder = Instance.new("Folder")
	sceneFolder.Name = "LocalGarageScene"
	sceneFolder.Parent = workspace

	layout = GarageLayout.Compute(GarageLayout.GetAnchorCFrame(), #UpgradeConfig.ChassisTiers)

	-- Local-only clone of your own avatar -- never replicates anywhere.
	-- Characters are Archivable=false by default, so :Clone() returns nil
	-- unless we flip it on first.
	local realCharacter = player.Character
	if realCharacter then
		local wasArchivable = realCharacter.Archivable
		realCharacter.Archivable = true
		displayCharacter = realCharacter:Clone()
		realCharacter.Archivable = wasArchivable
	end

	if displayCharacter then
		displayCharacter.Name = "GarageDisplayAvatar"
		for _, item in ipairs(displayCharacter:GetDescendants()) do
			if item:IsA("BasePart") then
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
			elseif item:IsA("Script") or item:IsA("LocalScript") then
				item:Destroy()
			end
		end
		local hrp = displayCharacter:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = true
		end
		displayCharacter:PivotTo(spotFor(garageState.chassisId).player)
		displayCharacter.Parent = sceneFolder
	end

	-- Park every tier in its own bay, each wearing its own confirmed upgrades.
	for _, entry in ipairs(garageState.fleet or {}) do
		setDisplayBus(entry.chassisId, entry.upgrades)
	end
	displayedChassisId = garageState.chassisId
end

local function destroyScene()
	if sceneFolder then
		sceneFolder:Destroy()
	end
	sceneFolder = nil
	displayCharacter = nil
	displayBuses = {}
	displayedChassisId = nil
end

local function enterGarageCamera(cameraCFrame)
	savedCameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = cameraCFrame,
	}):Play()
end

local function exitGarageCamera()
	camera.CameraType = savedCameraType or Enum.CameraType.Custom
	savedCameraType = nil
end

-- Open / close -------------------------------------------------------------------------------------

local function closeLocal()
	openRequested = false
	if not isOpen then
		return
	end
	isOpen = false
	gui.panel.Visible = false
	destroyScene()
	exitGarageCamera()
	freezeRealCharacter(false)
end

-- The garage is available to anyone not currently in a race.
local function refreshOpenButton()
	gui.openButton.Visible = not isOpen and not player:GetAttribute("InRace")
end

gui.openButton.MouseButton1Click:Connect(function()
	if isOpen or openRequested then
		return
	end
	openRequested = true
	OpenGarage:FireServer()
end)

gui.closeButton.MouseButton1Click:Connect(function()
	CloseGarage:FireServer()
	closeLocal()
	refreshOpenButton()
end)

-- MAP / MISSIONS / SETTINGS aren't built yet.
for name, button in pairs(gui.navButtons) do
	button.MouseButton1Click:Connect(function()
		showToast(name .. " is coming soon")
	end)
end

GarageReady.OnClientEvent:Connect(function(garageState)
	state = garageState
	if not isOpen then
		if not openRequested then
			return -- stale reply after we already closed
		end
		openRequested = false
		isOpen = true
		buildScene(garageState)
		freezeRealCharacter(true)
		gui.panel.Visible = true
		enterGarageCamera(spotFor(state.chassisId).camera)
	end
	render()
	refreshOpenButton()
end)

GarageClosed.OnClientEvent:Connect(function()
	closeLocal()
	refreshOpenButton()
end)

GarageError.OnClientEvent:Connect(function(message)
	openRequested = false
	if isOpen then
		showToast(message)
	end
end)

player:GetAttributeChangedSignal("InRace"):Connect(function()
	if player:GetAttribute("InRace") then
		closeLocal()
	end
	refreshOpenButton()
end)
refreshOpenButton()

-- Levels & chassis ---------------------------------------------------------------------------------

for category, row in pairs(gui.rows) do
	row.minus.MouseButton1Click:Connect(function()
		if state and not swapping then
			RequestSetLevel:FireServer(category, state.pending[category] - 1)
		end
	end)
	row.plus.MouseButton1Click:Connect(function()
		if state and not swapping then
			RequestSetLevel:FireServer(category, state.pending[category] + 1)
		end
	end)
end

local function stepChassis(delta)
	if not state or swapping then
		return
	end
	local tier = UpgradeConfig.ChassisTiers[state.tierIndex + delta]
	if tier then
		RequestSelectChassis:FireServer(tier.id)
	end
end
gui.chassisPrev.MouseButton1Click:Connect(function()
	stepChassis(-1)
end)
gui.chassisNext.MouseButton1Click:Connect(function()
	stepChassis(1)
end)

PendingLevelUpdated.OnClientEvent:Connect(function(garageState)
	if not isOpen then
		return
	end
	state = garageState
	render()
end)

ChassisPreviewUpdated.OnClientEvent:Connect(function(garageState)
	if not isOpen then
		return
	end
	state = garageState
	if garageState.chassisId == displayedChassisId or swapping then
		render()
		return
	end

	panToChassis(state.chassisId)
	render()
end)

-- Confirm ----------------------------------------------------------------------------------------------

local confirmPending = false

gui.confirmButton.MouseButton1Click:Connect(function()
	if state and state.canConfirm and not swapping then
		confirmPending = true
		swapping = true
		render()
		RequestConfirm:FireServer()
		-- Safety net: never leave the panel locked if no reply arrives.
		task.delay(5, function()
			if confirmPending then
				confirmPending = false
				swapping = false
				render()
			end
		end)
	end
end)

-- A rejected confirm comes back as GarageError: unlock the panel.
GarageError.OnClientEvent:Connect(function()
	if confirmPending then
		confirmPending = false
		swapping = false
		render()
	end
end)

UpgradesConfirmed.OnClientEvent:Connect(function(garageState)
	confirmPending = false
	if not isOpen then
		return
	end
	state = garageState
	swapping = false -- the panel locks on click; the reply is what unlocks it

	-- Rebuilding is the simplest way to be sure removed upgrades actually come
	-- off the model, and it re-grounds the bus for whatever the new parts did
	-- to its height.
	setDisplayBus(garageState.chassisId, garageState.confirmed)
	panToChassis(garageState.chassisId)
	render()
end)
