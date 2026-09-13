--[[
	GarageService.server.lua

	Owns each player's upgrade state ONLY. The garage scene itself
	(camera, avatar clone, bus) is entirely client-side now -- this
	script never moves the player's real character or builds a bus,
	it just validates and stores what levels they've picked.

	NOTE: there is no reputation/cash/leveling system yet, so any level
	from 0 to UpgradeConfig.MaxLevel is accepted for any category.
	Search for "TODO(gating)" below for where that check will go.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		return
	end
	if not table.find(UpgradeConfig.Categories, category) then
		return
	end

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