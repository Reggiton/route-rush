--[[
	RunScoring.lua

	Tracks each player's stats during a route run and, at the end, turns
	them into cash / reputation / XP (via Progression.RunPayout) in a
	single PlayerDataService.Update, then sends the RunResults remote.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Progression = require(ReplicatedStorage.Shared.Modules.Progression)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RunResults = Remotes:WaitForChild("RunResults")

local RunScoring = {}

local runs = {} -- [Player] = stats

function RunScoring.Begin(players)
	runs = {}
	for _, player in ipairs(players) do
		runs[player] = {
			fares = 0,
			deliveries = 0,
			onTimeDeliveries = 0,
			collisions = 0,
			cleanStreak = 0,
			bestCleanStreak = 0,
			passengersLost = 0,
		}
	end
end

function RunScoring.Get(player)
	return runs[player]
end

function RunScoring.AddDelivery(player, fare, onTime)
	local stats = runs[player]
	if not stats then
		return
	end
	stats.fares = stats.fares + fare
	stats.deliveries = stats.deliveries + 1
	if onTime then
		stats.onTimeDeliveries = stats.onTimeDeliveries + 1
	end
	stats.cleanStreak = stats.cleanStreak + 1
	stats.bestCleanStreak = math.max(stats.bestCleanStreak, stats.cleanStreak)
end

function RunScoring.AddCollision(player)
	local stats = runs[player]
	if stats then
		stats.collisions = stats.collisions + 1
		stats.cleanStreak = 0
	end
end

function RunScoring.AddLost(player, count)
	local stats = runs[player]
	if stats then
		stats.passengersLost = stats.passengersLost + count
	end
end

function RunScoring.Remove(player)
	runs[player] = nil
end

-- Pays everyone out and sends results. Returns nothing; clears run state.
function RunScoring.Finish(durationSeconds)
	for player, stats in pairs(runs) do
		stats.durationSeconds = durationSeconds
		local payout = Progression.RunPayout(stats)

		local before = PlayerDataService.Get(player)
		if before and player.Parent then
			local levelBefore = Progression.LevelFromXP(before.xp)
			local reputationBefore = before.reputation

			PlayerDataService.Update(player, function(data)
				data.cash = data.cash + payout.cash
				data.reputation = data.reputation + payout.reputation
				data.xp = data.xp + payout.xp
				data.stats.runs = data.stats.runs + 1
				data.stats.bestFaresPerMin = math.max(data.stats.bestFaresPerMin, payout.faresPerMinute)
				data.stats.bestCleanStreak = math.max(data.stats.bestCleanStreak, stats.bestCleanStreak)
			end)

			local after = PlayerDataService.Get(player)
			RunResults:FireClient(player, {
				fares = payout.fares,
				cleanBonus = payout.cleanBonus,
				cash = payout.cash,
				xp = payout.xp,
				reputation = payout.reputation,
				faresPerMinute = payout.faresPerMinute,
				deliveries = stats.deliveries,
				onTimeDeliveries = stats.onTimeDeliveries,
				collisions = stats.collisions,
				bestCleanStreak = stats.bestCleanStreak,
				passengersLost = stats.passengersLost,
				levelBefore = levelBefore,
				levelAfter = Progression.LevelFromXP(after.xp),
				slotsBefore = Progression.UnlockedSlots(reputationBefore),
				slotsAfter = Progression.UnlockedSlots(after.reputation),
			})
		end
	end
	runs = {}
end

return RunScoring
