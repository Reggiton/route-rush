--[[
	WarReadyService.lua

	Who wants to fight. Mirrors ReadyService.lua exactly, but for RouteWars:
	the attribute is "WarReady" instead of "Ready", so the two loops never
	interact. Most players go Ready this way automatically -- walking into
	the RouteWarsZone part sets it, walking back out clears it
	(RouteWarsZoneService) -- but leaving mid-fight needs an explicit action,
	since by then you're nowhere near the zone; the HUD's "Leave war" button
	fires the SetWarReady remote directly, same as the regular Leave button.

	Changed fires (player, isWarReady) on every change -- RouteWarsSession
	uses it the same way RouteSession uses ReadyService.Changed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetWarReady = Remotes:WaitForChild("SetWarReady")

local TOGGLE_COOLDOWN = 0.3

local WarReadyService = {}

WarReadyService.Changed = Instance.new("BindableEvent")

local lastToggle = {}

function WarReadyService.IsReady(player)
	return player:GetAttribute("WarReady") == true
end

function WarReadyService.SetReady(player, ready)
	ready = ready == true
	if player.Parent ~= Players or WarReadyService.IsReady(player) == ready then
		return
	end
	player:SetAttribute("WarReady", ready)
	WarReadyService.Changed:Fire(player, ready)
end

-- Players whose profile has loaded and who are Ready for war.
function WarReadyService.ReadyPlayers()
	local ready = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if WarReadyService.IsReady(player) and PlayerDataService.Get(player) then
			table.insert(ready, player)
		end
	end
	return ready
end

-- Returns readyCount, totalCount (players with a loaded profile).
function WarReadyService.Count()
	local readyCount, total = 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerDataService.Get(player) then
			total = total + 1
			if WarReadyService.IsReady(player) then
				readyCount = readyCount + 1
			end
		end
	end
	return readyCount, total
end

SetWarReady.OnServerEvent:Connect(function(player, ready)
	if type(ready) ~= "boolean" or not PlayerDataService.Get(player) then
		return
	end
	local now = os.clock()
	if lastToggle[player] and now - lastToggle[player] < TOGGLE_COOLDOWN then
		return
	end
	lastToggle[player] = now
	WarReadyService.SetReady(player, ready)
end)

local function onPlayerAdded(player)
	if player:GetAttribute("WarReady") == nil then
		player:SetAttribute("WarReady", false)
	end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastToggle[player] = nil
end)

return WarReadyService
