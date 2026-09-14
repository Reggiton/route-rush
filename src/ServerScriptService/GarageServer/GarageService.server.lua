--[[
	GarageService.server.lua

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
	  - The garage is closed for players who are in a race (InRace
	    player attribute); everyone waiting in the lobby can use it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-- [Player] = { chassisId = string, pending = {category = level} }
local sessions = {}

local function copyLevels(levels)
	local copy = {}
	for _, category in ipairs(UpgradeConfig.Categories) do
		copy[category] = (levels and levels[category]) or 0
	end
	return copy
end

local function garageIsOpenFor(player)
	return not player:GetAttribute("InRace")
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

	-- Every chassis, so the garage showroom can park each tier in its own bay
	-- wearing its own upgrades rather than only the one being edited.
	local fleet = {}
	for index, chassisTier in ipairs(UpgradeConfig.ChassisTiers) do
		local chassisEntry = data.chassis[chassisTier.id]
		fleet[index] = {
			chassisId = chassisTier.id,
			owned = chassisEntry and chassisEntry.owned or false,
			upgrades = copyLevels(chassisEntry and chassisEntry.upgrades),
		}
	end

	return {
		chassisId = session.chassisId,
		fleet = fleet,
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
	if not garageIsOpenFor(player) then
		GarageError:FireClient(player, "The garage is closed while you're in a race.")
		return
	end
	local data = PlayerDataService.WaitForProfile(player)
	if not data or not garageIsOpenFor(player) then
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
		return
	end
	if not table.find(UpgradeConfig.Categories, category) then
		return
	end
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
	if not garageIsOpenFor(player) then
		GarageError:FireClient(player, "The garage is closed while you're in a race.")
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

-- Close a player's garage the moment they're put into a race.
local function watchInRace(player)
	player:GetAttributeChangedSignal("InRace"):Connect(function()
		if player:GetAttribute("InRace") then
			closeSession(player, true)
		end
	end)
end
Players.PlayerAdded:Connect(watchInRace)
for _, player in ipairs(Players:GetPlayers()) do
	watchInRace(player)
end

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)
