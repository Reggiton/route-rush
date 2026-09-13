--[[
	Boarding.lua

	Pure math for boarding on the move (no Roblox instances), shared by the
	server (PassengerService, authoritative) and the client (the boarding
	meter). Numbers live in RouteConfig -> "Boarding on the move".

	Inside a stop's ring, a bus earns boarding allowance at RatePerSecond;
	each E press spends it to board passengers. The slower the bus, the
	faster allowance builds; fully stopped is fastest.
]]

local RouteConfig = require(script.Parent.Parent.Config.RouteConfig)

local Boarding = {}

-- 0 at MaxBoardSpeed or faster, 1 at FullStopSpeed or slower.
function Boarding.Slowness(speed)
	local span = RouteConfig.MaxBoardSpeed - RouteConfig.FullStopSpeed
	if span <= 0 then
		return speed <= RouteConfig.FullStopSpeed and 1 or 0
	end
	return math.clamp((RouteConfig.MaxBoardSpeed - speed) / span, 0, 1)
end

function Boarding.IsStopped(speed)
	return speed <= RouteConfig.FullStopSpeed
end

function Boarding.CanBoard(speed)
	return speed < RouteConfig.MaxBoardSpeed
end

-- Passengers per second that can board at this speed.
function Boarding.RatePerSecond(speed)
	local rate = RouteConfig.BoardRateMax * Boarding.Slowness(speed) ^ RouteConfig.BoardRateCurve
	if Boarding.IsStopped(speed) then
		rate = rate * RouteConfig.FullStopBonus
	end
	return rate
end

return Boarding
