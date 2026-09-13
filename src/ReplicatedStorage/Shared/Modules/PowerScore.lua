--[[
	PowerScore.lua

	Hidden matchmaking numbers (GDD section 7). Only the Driving Power
	Score exists for now; a Combat Power Score for Route Wars goes here
	later as its own function.
]]

local ReplicatedStorage = script.Parent.Parent.Parent
local UpgradeConfig = require(ReplicatedStorage.GarageSystem.Config.UpgradeConfig)
local RouteConfig = require(script.Parent.Parent.Config.RouteConfig)

local PowerScore = {}

function PowerScore.Driving(chassisId, levels)
	local score = RouteConfig.TierBaseScore[chassisId] or 0
	for _, category in ipairs(UpgradeConfig.Categories) do
		local level = (levels and levels[category]) or 0
		score = score + level * (RouteConfig.PowerWeights[category] or 1)
	end
	return math.floor(score * 10 + 0.5) / 10
end

-- 1 = lower bracket, 2 = upper bracket.
function PowerScore.Bracket(score)
	return score < RouteConfig.BracketThreshold and 1 or 2
end

return PowerScore
