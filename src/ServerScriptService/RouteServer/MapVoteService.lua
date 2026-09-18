--[[
	MapVoteService.lua

	The lobby map vote. Modelled on ReadyService: a player's pick lives on the
	player as an attribute, so every client can tally the vote itself without a
	remote round-trip (RouteClient does exactly that for ready counts).

	  player.MapVote              layout id, or nil for "no opinion"
	  ReplicatedStorage.VoteOpen  true while votes are being taken
	  ReplicatedStorage.MapLayout the layout the current/next race uses

	RouteSession closes the vote before it builds tracks; the winner is decided
	by MapVote.lua, which is pure and tested.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackLayouts = require(ReplicatedStorage.Shared.Config.TrackLayouts)
local MapVote = require(ReplicatedStorage.Shared.Modules.MapVote)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetMapVote = Remotes:WaitForChild("SetMapVote")

local MapVoteService = {}

local VOTE_COOLDOWN = 0.3 -- seconds between accepted votes, as ReadyService does

local lastVote = {} -- [Player] = os.clock() of the last accepted vote

local function votes()
	local collected = {}
	for _, player in ipairs(Players:GetPlayers()) do
		collected[player] = player:GetAttribute("MapVote")
	end
	return collected
end

function MapVoteService.Tally()
	return MapVote.Tally(votes())
end

-- The layout that would win if the vote closed right now.
function MapVoteService.Leader()
	return MapVote.Winner(votes())
end

function MapVoteService.SetVote(player, layoutId)
	if player.Parent ~= Players or not TrackLayouts.Get(layoutId) then
		return
	end
	-- Voting for your current pick clears it, the way the Ready button toggles.
	if player:GetAttribute("MapVote") == layoutId then
		layoutId = nil
	end
	player:SetAttribute("MapVote", layoutId)
	ReplicatedStorage:SetAttribute("VoteLeader", MapVoteService.Leader())
end

-- Start taking votes for the next race.
function MapVoteService.Begin()
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("MapVote", nil)
	end
	ReplicatedStorage:SetAttribute("VoteOpen", true)
	ReplicatedStorage:SetAttribute("VoteLeader", TrackLayouts.DefaultId)
end

-- Stop taking votes and return the winner. Always returns a valid layout id.
function MapVoteService.Close()
	local winner = MapVoteService.Leader()
	ReplicatedStorage:SetAttribute("VoteOpen", false)
	ReplicatedStorage:SetAttribute("VoteLeader", winner)
	return winner
end

SetMapVote.OnServerEvent:Connect(function(player, layoutId)
	if type(layoutId) ~= "string" or not PlayerDataService.Get(player) then
		return
	end
	if not ReplicatedStorage:GetAttribute("VoteOpen") then
		return
	end
	local now = os.clock()
	if lastVote[player] and now - lastVote[player] < VOTE_COOLDOWN then
		return
	end
	lastVote[player] = now
	MapVoteService.SetVote(player, layoutId)
end)

Players.PlayerRemoving:Connect(function(player)
	lastVote[player] = nil
end)

return MapVoteService
