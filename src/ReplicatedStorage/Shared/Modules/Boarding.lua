--[[
	Boarding.lua

	Pure math for boarding on the move (no Roblox instances), shared by the
	server (PassengerService, authoritative) and the client (the boarding
	card and the speedometer bands). Numbers live in RouteConfig ->
	"Boarding on the move".

	Speed decides what a bay is worth to you. Roll through at 30 mph or less
	and passengers for that stop get off; each speed tier also caps how many
	you may pick up during that visit:

	    30 mph -> 2        20 mph -> 4        10 mph -> the whole crowd

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
	local mph = Boarding.Mph(speed)
	local cap = 0
	for _, tier in ipairs(RouteConfig.BoardTiers) do
		if mph <= tier.mph and tier.board > cap then
			cap = tier.board
		end
	end
	return cap
end

function Boarding.CanBoard(speed)
	return Boarding.BoardCap(speed) > 0
end

function Boarding.CanDropOff(speed)
	return Boarding.Mph(speed) <= RouteConfig.DropOffMph
end

-- The least slowing down that would raise your cap, or nil if you are already
-- in the slowest tier. Drives the "slow to 20 mph for 4" hint.
function Boarding.NextTier(speed)
	local cap = Boarding.BoardCap(speed)
	local best
	for _, tier in ipairs(RouteConfig.BoardTiers) do
		if tier.board > cap and (best == nil or tier.mph > best.mph) then
			best = tier
		end
	end
	return best
end

-- Fastest you can be going and still pick anyone up.
function Boarding.MaxBoardMph()
	local fastest = 0
	for _, tier in ipairs(RouteConfig.BoardTiers) do
		if tier.mph > fastest then
			fastest = tier.mph
		end
	end
	return fastest
end

-- Tiers slowest-first, for anything that draws them in order (the speedometer
-- bands). Returns a copy; callers must not mutate the config.
function Boarding.TiersBySpeed()
	local sorted = table.clone(RouteConfig.BoardTiers)
	table.sort(sorted, function(a, b)
		return a.mph < b.mph
	end)
	return sorted
end

return Boarding
