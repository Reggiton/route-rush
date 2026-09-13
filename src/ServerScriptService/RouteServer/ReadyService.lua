--[[
	ReadyService.lua

	Who wants to race. A player's ready state is the player attribute
	"Ready" (true/false), so every client can see it (e.g. "3 / 5 ready").
	Players toggle it with the SetReady remote; everyone starts Not Ready.

	Changed fires (player, isReady) on every change -- RouteSession uses it
	to drop newly-ready players into a race and pull out players who
	un-ready mid-race.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetReady = Remotes:WaitForChild("SetReady")

local TOGGLE_COOLDOWN = 0.3

local ReadyService = {}

ReadyService.Changed = Instance.new("BindableEvent")

local lastToggle = {}

function ReadyService.IsReady(player)
	return player:GetAttribute("Ready") == true
end

function ReadyService.SetReady(player, ready)
	ready = ready == true
	if player.Parent ~= Players or ReadyService.IsReady(player) == ready then
		return
	end
	player:SetAttribute("Ready", ready)
	ReadyService.Changed:Fire(player, ready)
end

-- Players whose profile has loaded and who are Ready.
function ReadyService.ReadyPlayers()
	local ready = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if ReadyService.IsReady(player) and PlayerDataService.Get(player) then
			table.insert(ready, player)
		end
	end
	return ready
end

-- Returns readyCount, totalCount (players with a loaded profile).
function ReadyService.Count()
	local readyCount, total = 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerDataService.Get(player) then
			total = total + 1
			if ReadyService.IsReady(player) then
				readyCount = readyCount + 1
			end
		end
	end
	return readyCount, total
end

SetReady.OnServerEvent:Connect(function(player, ready)
	if type(ready) ~= "boolean" or not PlayerDataService.Get(player) then
		return
	end
	local now = os.clock()
	if lastToggle[player] and now - lastToggle[player] < TOGGLE_COOLDOWN then
		return
	end
	lastToggle[player] = now
	ReadyService.SetReady(player, ready)
end)

local function onPlayerAdded(player)
	if player:GetAttribute("Ready") == nil then
		player:SetAttribute("Ready", false)
	end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastToggle[player] = nil
end)

return ReadyService
