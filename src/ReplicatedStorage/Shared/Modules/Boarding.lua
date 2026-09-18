--[[
	Boarding.lua

	Pure math for boarding on the move (no Roblox instances), shared by the
	server (PassengerService, authoritative) and the client (the boarding
	card and the speedometer bands). Numbers live in RouteConfig ->
	"Boarding on the move".

	Speed decides what a bay is worth to you. Roll through at 30 mph or less
	and passengers for that stop get off; each speed tier also caps how many
	you may pick up during that visit:

	    45 studs/s (30 mph) -> 2     30 (20 mph) -> 4     15 (10 mph) -> everyone

	The cap is cumulative for the visit, so braking part-way through a bay
	unlocks the next tier and lets you take more. Everything here works in
	studs/second (what the game measures) and converts to mph for display.
]]

local RouteConfig = require(script.Parent.Parent.Config.RouteConfig)

local Boarding = {}

function Boarding.Mph(studsPerSecond)
	return (studsPerSecond or 0) / RouteConfig.StudsPerMph
end

function Boarding.Studs(mph)
	return (mph or 0) * RouteConfig.StudsPerMph
end

-- The most passengers you may have boarded during one visit at this speed.
-- 0 means you are going too fast to pick anyone up; math.huge means only the
-- bus's capacity limits you. Slower tiers are looser, so the best match wins.
function Boarding.BoardCap(speed)
	speed = speed or 0
	local cap = 0
	for _, tier in ipairs(RouteConfig.BoardTiers) do
		if speed <= tier.speed and tier.board > cap then
			cap = tier.board
		end
	end
	return cap
end

function Boarding.CanBoard(speed)
	return Boarding.BoardCap(speed) > 0
end

function Boarding.CanDropOff(speed)
	return (speed or 0) <= RouteConfig.DropOffSpeed
end

-- The least slowing down that would raise your cap, or nil if you are already
-- in the slowest tier. Drives the "slow to 20 mph for 4" hint.
function Boarding.NextTier(speed)
	local cap = Boarding.BoardCap(speed)
	local best
	for _, tier in ipairs(RouteConfig.BoardTiers) do
		if tier.board > cap and (best == nil or tier.speed > best.speed) then
			best = tier
		end
	end
	return best
end

-- Fastest you can be going and still pick anyone up (studs/s).
function Boarding.MaxBoardSpeed()
	local fastest = 0
	for _, tier in ipairs(RouteConfig.BoardTiers) do
		if tier.speed > fastest then
			fastest = tier.speed
		end
	end
	return fastest
end

-- Tiers slowest-first, for anything that draws them in order (the speedometer
-- bands). Returns a copy; callers must not mutate the config.
function Boarding.TiersBySpeed()
	local sorted = table.clone(RouteConfig.BoardTiers)
	table.sort(sorted, function(a, b)
		return a.speed < b.speed
	end)
	return sorted
end

return Boarding
