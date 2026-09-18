--[[
	TrackLayouts.lua

	The selectable track layouts. Players vote for one in the lobby
	(MapVoteService) and TrackBuilder builds whichever wins.

	A layout is data plus one pure function:

	    id            stable key, used by the vote and the MapLayout attribute
	    name/blurb    what the vote panel shows
	    roadWidth     studs across; lanes, curbs, bays and the grid all derive
	    curbs         solid walls along the road edge. false = open edges, and
	                  BusMonitor tows you back if you leave the road
	    gridColumns   buses per start-grid row
	    points(rng) -> { {x, y, z} }

	points() returns PLAIN NUMBER offsets from the track centre -- no Vector3 --
	because tools/test/bundle.js stubs only Color3, so anything this module
	touches at load or call time has to be ordinary Lua for the tests to run it.
	TrackBuilder adds the centre and converts to Vector3.

	It also takes the Random rather than making one. TrackBuilder draws obstacle
	placement from the SAME generator afterwards, so creating a second one here
	would shift every obstacle on the existing map. Draw order is part of the
	contract: City Loop must take exactly two numbers, as it always has.

	The result must be a CLOSED, ORDERED ring: TrackBuilder walks it as a loop,
	and both TrackBuilder.DistanceBetween and PassengerService's "N stops ahead"
	destination logic assume stops are numbered in one traversal order around a
	single loop. A self-intersecting closed curve is fine; a branching or
	hub-and-spoke graph is NOT, and would need those two systems reworked.

	Y is free -- BusDriveController raycasts for ground and aligns the bus to
	the surface normal, so a layout can climb and descend.
]]

local RouteConfig = require(script.Parent.RouteConfig)

local TrackLayouts = {}

-- The seeded ellipse the game has always used: two harmonics of sine noise on
-- the radius, sampled at TrackSegments points. Shared by every layout below so
-- they stay recognisably the same city.
--
-- Takes exactly two numbers off `rng`, in this order. Do not change that
-- without accepting that every existing obstacle moves.
local function ellipsePoints(rng, options)
	options = options or {}
	local phase1 = rng:NextNumber(0, math.pi * 2)
	local phase2 = rng:NextNumber(0, math.pi * 2)
	local segments = RouteConfig.TrackSegments
	local radiusX = options.radiusX or RouteConfig.TrackRadiusX
	local radiusZ = options.radiusZ or RouteConfig.TrackRadiusZ
	local hillAmplitude = options.hillAmplitude or 0
	local hillCycles = options.hillCycles or 2

	local points = {}
	for i = 0, segments - 1 do
		local angle = i / segments * math.pi * 2
		local noise = RouteConfig.TrackRadiusNoise
			* (0.6 * math.sin(2 * angle + phase1) + 0.4 * math.sin(3 * angle + phase2))
		points[i + 1] = {
			x = math.cos(angle) * radiusX * (1 + noise),
			y = hillAmplitude > 0 and (hillAmplitude * math.sin(hillCycles * angle)) or 0,
			z = math.sin(angle) * radiusZ * (1 + noise),
		}
	end
	return points
end

TrackLayouts.List = {
	{
		id = "cityLoop",
		name = "City Loop",
		blurb = "The original. Two lanes, hard curbs, no room to hide.",
		roadWidth = RouteConfig.RoadWidth,
		curbs = true,
		gridColumns = 2,
		points = function(rng)
			return ellipsePoints(rng)
		end,
	},
	{
		id = "boulevard",
		name = "Wide Boulevard",
		blurb = "Four lanes, no curbs. Leave the road and you get towed back.",
		roadWidth = RouteConfig.RoadWidth * 2,
		curbs = false,
		gridColumns = 4,
		points = function(rng)
			return ellipsePoints(rng)
		end,
	},
	{
		id = "hills",
		name = "Hill Circuit",
		blurb = "Same ring, two climbs and two descents. Loaded buses suffer.",
		roadWidth = RouteConfig.RoadWidth,
		curbs = true,
		gridColumns = 2,
		points = function(rng)
			return ellipsePoints(rng, { hillAmplitude = RouteConfig.HillAmplitude, hillCycles = 2 })
		end,
	},
}

-- Everything falls back to this: an unknown vote, a tie, or nobody voting at
-- all. Keeping it first means the game's default behaviour never changes.
TrackLayouts.DefaultId = TrackLayouts.List[1].id

function TrackLayouts.Get(layoutId)
	if type(layoutId) ~= "string" then
		return nil
	end
	for _, layout in ipairs(TrackLayouts.List) do
		if layout.id == layoutId then
			return layout
		end
	end
	return nil
end

-- Never returns nil: an unknown id resolves to the default layout.
function TrackLayouts.Resolve(layoutId)
	return TrackLayouts.Get(layoutId) or TrackLayouts.Get(TrackLayouts.DefaultId)
end

return TrackLayouts
