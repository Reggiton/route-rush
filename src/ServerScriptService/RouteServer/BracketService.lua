--[[
	BracketService.lua

	Splits a round's players into track groups by Driving Power Score
	(GDD section 7). Two groups only when BOTH brackets have enough
	players to race each other; otherwise everyone shares one track.

	Cross-server matchmaking (MemoryStore queues + reserved servers)
	would replace Assign() later without touching the session loop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RouteConfig = require(ReplicatedStorage.Shared.Config.RouteConfig)
local PowerScore = require(ReplicatedStorage.Shared.Modules.PowerScore)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local BracketService = {}

-- Returns an array of player arrays, one per track to build.
function BracketService.Assign(players)
	local brackets = { {}, {} }
	for _, player in ipairs(players) do
		local data = PlayerDataService.Get(player)
		if data then
			local score = PowerScore.Driving(data.selectedChassis, data.chassis[data.selectedChassis].upgrades)
			local bracket = PowerScore.Bracket(score)
			player:SetAttribute("PowerScore", score)
			player:SetAttribute("Bracket", bracket)
			table.insert(brackets[bracket], player)
		end
	end

	local minimum = RouteConfig.MinPlayersPerBracket
	if #brackets[1] >= minimum and #brackets[2] >= minimum then
		return brackets
	end

	local everyone = {}
	for _, group in ipairs(brackets) do
		for _, player in ipairs(group) do
			table.insert(everyone, player)
		end
	end
	return { everyone }
end

return BracketService
