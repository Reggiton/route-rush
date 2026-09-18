--[[
	WarMapVoteService.lua

	The RouteWars lobby's map vote. Mirrors MapVoteService exactly, on its
	own set of names so the two lobbies never read each other's vote:

	  player.WarMapVote              layout id, or nil for "no opinion"
	  ReplicatedStorage.WarVoteOpen  true while war votes are being taken
	  ReplicatedStorage.WarMapLayout the layout the current/next war uses

	RouteWarsSession closes the vote before it builds its track. The tally
	itself is MapVote.lua, the same pure module the regular vote uses.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackLayouts = require(ReplicatedStorage.Shared.Config.TrackLayouts)
local MapVote = require(ReplicatedStorage.Shared.Modules.MapVote)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetWarMapVote = Remotes:WaitForChild("SetWarMapVote")

local WarMapVoteService = {}

local VOTE_COOLDOWN = 0.3

local lastVote = {} -- [Player] = os.clock() of the last accepted vote

local function votes()
	local collected = {}
	for _, player in ipairs(Players:GetPlayers()) do
		collected[player] = player:GetAttribute("WarMapVote")
	end
	return collected
end

function WarMapVoteService.Tally()
	return MapVote.Tally(votes())
end

function WarMapVoteService.Leader()
	return MapVote.Winner(votes())
end

function WarMapVoteService.SetVote(player, layoutId)
	if player.Parent ~= Players or not TrackLayouts.Get(layoutId) then
		return
	end
	if player:GetAttribute("WarMapVote") == layoutId then
		layoutId = nil
	end
	player:SetAttribute("WarMapVote", layoutId)
	ReplicatedStorage:SetAttribute("WarVoteLeader", WarMapVoteService.Leader())
end

function WarMapVoteService.Begin()
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("WarMapVote", nil)
	end
	ReplicatedStorage:SetAttribute("WarVoteOpen", true)
	ReplicatedStorage:SetAttribute("WarVoteLeader", TrackLayouts.DefaultId)
end

function WarMapVoteService.Close()
	local winner = WarMapVoteService.Leader()
	ReplicatedStorage:SetAttribute("WarVoteOpen", false)
	ReplicatedStorage:SetAttribute("WarVoteLeader", winner)
	return winner
end

SetWarMapVote.OnServerEvent:Connect(function(player, layoutId)
	if type(layoutId) ~= "string" or not PlayerDataService.Get(player) then
		return
	end
	if not ReplicatedStorage:GetAttribute("WarVoteOpen") then
		return
	end
	local now = os.clock()
	if lastVote[player] and now - lastVote[player] < VOTE_COOLDOWN then
		return
	end
	lastVote[player] = now
	WarMapVoteService.SetVote(player, layoutId)
end)

Players.PlayerRemoving:Connect(function(player)
	lastVote[player] = nil
end)

return WarMapVoteService
