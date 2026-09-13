--[[
	GarageService.server.lua

<<<<<<< HEAD
	Server authority for the garage: validates every level change,
	chassis switch, and confirm against the player's profile, and
	charges/refunds cash. The garage SCENE (camera, avatar clone, bus)
	is entirely client-side -- this script never builds or moves
	anything in the world.

	Every garage remote sent to the client carries the same full
	"garage state" table (see buildState), so the client just re-renders.

	Rules (see Progression.lua / EconomyConfig.lua for the numbers):
	  - Reputation decides how many slots are unlocked per chassis.
	  - Adding levels costs cash per slot (price grows per slot filled).
	  - Lowering levels refunds RespecRefundRate of those slots' price.
	  - Chassis are bought with cash once the player's Level is high enough.
	  - Confirming on a chassis also makes it the one you drive.
	  - The garage is closed while a route is counting down or running.
=======
	Owns each player's upgrade state ONLY. The garage scene itself
	(camera, avatar clone, bus) is entirely client-side now -- this
	script never moves the player's real character or builds a bus,
	it just validates and stores what levels they've picked.

	NOTE: there is no reputation/cash/leveling system yet, so any level
	from 0 to UpgradeConfig.MaxLevel is accepted for any category.
	Search for "TODO(gating)" below for where that check will go.
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
<<<<<<< HEAD
local ServerScriptService = game:GetService("ServerScriptService")

local UpgradeConfig = require(ReplicatedStorage.GarageSystem.Config.UpgradeConfig)
local Progression = require(ReplicatedStorage.Shared.Modules.Progression)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

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

local CLOSED_PHASES = {
	Countdown = true,
	Running = true,
}

-- [Player] = { chassisId = string, pending = {category = level} }
local sessions = {}

local function copyLevels(levels)
	local copy = {}
	for _, category in ipairs(UpgradeConfig.Categories) do
		copy[category] = (levels and levels[category]) or 0
	end
	return copy
end

local function garageIsOpenForPhase()
	return not CLOSED_PHASES[ReplicatedStorage:GetAttribute("SessionPhase") or "Intermission"]
end

local function buildState(player)
	local session = sessions[player]
	local data = PlayerDataService.Get(player)
	if not session or not data then
		return nil
	end

	local tier, tierIndex = UpgradeConfig.GetChassis(session.chassisId)
	local entry = data.chassis[session.chassisId]
	local level = Progression.LevelFromXP(data.xp)
	local unlockedSlots = Progression.UnlockedSlots(data.reputation)
	local quote = Progression.QuoteChange(session.chassisId, entry.upgrades, session.pending)

	local canConfirm, blockReason = false, nil
	local netCost
	if entry.owned then
		netCost = quote.net
		local changed = quote.added + quote.removed > 0
		local switching = data.selectedChassis ~= session.chassisId
		if not changed and not switching then
			blockReason = nil
		elseif quote.slotsAfter > unlockedSlots then
			blockReason = "Earn reputation to unlock more slots"
		elseif netCost > data.cash then
			blockReason = "Not enough cash"
		else
			canConfirm = true
		end
	else
		netCost = tier.price
		if level < tier.requiredLevel then
			blockReason = "Requires Level " .. tier.requiredLevel
		elseif tier.price > data.cash then
			blockReason = "Not enough cash"
		else
			canConfirm = true
		end
	end

	return {
		chassisId = session.chassisId,
		displayName = tier.displayName,
		tierIndex = tierIndex,
		tierCount = #UpgradeConfig.ChassisTiers,
		owned = entry.owned,
		selected = data.selectedChassis == session.chassisId,
		requiredLevel = tier.requiredLevel,
		price = tier.price,

		confirmed = copyLevels(entry.upgrades),
		pending = copyLevels(session.pending),
		quote = quote,
		netCost = netCost,
		canConfirm = canConfirm,
		blockReason = blockReason,

		cash = data.cash,
		reputation = data.reputation,
		level = level,
		unlockedSlots = unlockedSlots,
		maxSlots = Progression.MaxSlotsPerChassis,
		nextUnlockReputation = Progression.NextUnlockReputation(data.reputation),
	}
end

local function closeSession(player, notifyClient)
	if sessions[player] then
		sessions[player] = nil
		if notifyClient then
			GarageClosed:FireClient(player)
		end
	end
end

-- Remote handlers ----------------------------------------------------------------------

OpenGarage.OnServerEvent:Connect(function(player)
	if not garageIsOpenForPhase() then
		GarageError:FireClient(player, "The garage is closed during a route.")
		return
	end
	local data = PlayerDataService.WaitForProfile(player)
	if not data or not garageIsOpenForPhase() then
		return
	end

	sessions[player] = {
		chassisId = data.selectedChassis,
		pending = copyLevels(data.chassis[data.selectedChassis].upgrades),
	}
	GarageReady:FireClient(player, buildState(player))
end)

CloseGarage.OnServerEvent:Connect(function(player)
	closeSession(player, false)
end)

RequestSetLevel.OnServerEvent:Connect(function(player, category, newLevel)
	local session = sessions[player]
	local data = PlayerDataService.Get(player)
	if not session or not data then
		return
	end
	if type(category) ~= "string" or type(newLevel) ~= "number" or newLevel ~= newLevel then
=======

local GarageSystem = ReplicatedStorage:WaitForChild("GarageSystem")
local UpgradeConfig = require(GarageSystem.Config.UpgradeConfig)

local Remotes = GarageSystem:WaitForChild("Remotes")
local OpenGarage = Remotes:WaitForChild("OpenGarage")
local GarageReady = Remotes:WaitForChild("GarageReady")
local RequestSetLevel = Remotes:WaitForChild("RequestSetLevel")
local PendingLevelUpdated = Remotes:WaitForChild("PendingLevelUpdated")
local RequestConfirm = Remotes:WaitForChild("RequestConfirm")
local UpgradesConfirmed = Remotes:WaitForChild("UpgradesConfirmed")

-- userId -> { pending = {cat=level}, confirmed = {cat=level} }
local playerStates = {}

local function defaultState()
	local state = {}
	for _, category in ipairs(UpgradeConfig.Categories) do
		state[category] = 0
	end
	return state
end

local function getState(player)
	local state = playerStates[player.UserId]
	if not state then
		state = { pending = defaultState(), confirmed = defaultState() }
		playerStates[player.UserId] = state
	end
	return state
end

Players.PlayerRemoving:Connect(function(player)
	playerStates[player.UserId] = nil
end)

OpenGarage.OnServerEvent:Connect(function(player)
	local state = getState(player)
	GarageReady:FireClient(player, state.confirmed)
end)

RequestSetLevel.OnServerEvent:Connect(function(player, category, newLevel)
	if type(category) ~= "string" or type(newLevel) ~= "number" then
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
		return
	end
	if not table.find(UpgradeConfig.Categories, category) then
		return
	end
<<<<<<< HEAD
	if not data.chassis[session.chassisId].owned then
		GarageError:FireClient(player, "Buy this chassis before upgrading it.")
		return
	end

	newLevel = math.clamp(math.floor(newLevel), UpgradeConfig.MinLevel, UpgradeConfig.MaxLevel)
	local oldLevel = session.pending[category]

	if newLevel > oldLevel then
		local trial = copyLevels(session.pending)
		trial[category] = newLevel
		if Progression.SlotsUsed(trial) > Progression.UnlockedSlots(data.reputation) then
			GarageError:FireClient(player, "All unlocked slots are in use. Earn reputation to unlock more.")
			return
		end
	end

	session.pending[category] = newLevel
	PendingLevelUpdated:FireClient(player, buildState(player))
end)

RequestSelectChassis.OnServerEvent:Connect(function(player, chassisId)
	local session = sessions[player]
	local data = PlayerDataService.Get(player)
	if not session or not data or type(chassisId) ~= "string" then
		return
	end
	if not UpgradeConfig.GetChassis(chassisId) then
		return
	end

	session.chassisId = chassisId
	session.pending = copyLevels(data.chassis[chassisId].upgrades)
	ChassisPreviewUpdated:FireClient(player, buildState(player))
end)

RequestConfirm.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session or not PlayerDataService.Get(player) then
		return
	end
	if not garageIsOpenForPhase() then
		GarageError:FireClient(player, "The garage is closed during a route.")
		return
	end

	local state = buildState(player)
	if not state.canConfirm then
		GarageError:FireClient(player, state.blockReason or "Nothing to confirm.")
		return
	end

	local chassisId = session.chassisId
	local pending = copyLevels(session.pending)

	PlayerDataService.Update(player, function(data)
		local entry = data.chassis[chassisId]
		if entry.owned then
			local quote = Progression.QuoteChange(chassisId, entry.upgrades, pending)
			data.cash = data.cash - quote.net
			entry.upgrades = pending
		else
			local tier = UpgradeConfig.GetChassis(chassisId)
			data.cash = data.cash - tier.price
			entry.owned = true
		end
		data.selectedChassis = chassisId
	end)

	UpgradesConfirmed:FireClient(player, buildState(player))
end)

-- Keep open garages in sync with profile changes made elsewhere (payouts, dev commands).
PlayerDataService.Changed.Event:Connect(function(player)
	local session = sessions[player]
	local data = PlayerDataService.Get(player)
	if session and data then
		-- A reset can un-own the previewed chassis or lower confirmed levels.
		if not data.chassis[session.chassisId].owned then
			session.pending = copyLevels(data.chassis[session.chassisId].upgrades)
		end
		PendingLevelUpdated:FireClient(player, buildState(player))
	end
end)

ReplicatedStorage:GetAttributeChangedSignal("SessionPhase"):Connect(function()
	if not garageIsOpenForPhase() then
		for player in pairs(sessions) do
			closeSession(player, true)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)
=======

	local state = getState(player)
	newLevel = math.clamp(math.floor(newLevel), UpgradeConfig.MinLevel, UpgradeConfig.MaxLevel)

	-- TODO(gating): once Reputation/Cash-gated slots exist, reject
	-- newLevel here if the player hasn't unlocked it yet.

	state.pending[category] = newLevel
	PendingLevelUpdated:FireClient(player, category, newLevel)
end)

RequestConfirm.OnServerEvent:Connect(function(player)
	local state = getState(player)
	for category, level in pairs(state.pending) do
		state.confirmed[category] = level
	end

	-- TODO: deduct cash / persist state.confirmed to a DataStore here.

	UpgradesConfirmed:FireClient(player, state.confirmed)
end)
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
