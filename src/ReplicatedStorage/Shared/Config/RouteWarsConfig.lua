--[[
	RouteWarsConfig.lua

	Timing and track placement for RouteWars: the weapons-on race that
	runs as its own round loop (RouteWarsSession.server.lua), parallel to
	and independent from the regular RouteSession loop. Standing in the
	workspace part "RouteWarsZone" (RouteWarsZoneService) marks you Ready
	for this loop the same way ReadyService's button does for the regular
	one.

	Numbers only (no Roblox types), same rule as RouteConfig.
]]

local RouteWarsConfig = {}

-- Session phases (seconds) -----------------------------------------------------
RouteWarsConfig.IntermissionSeconds = 20
RouteWarsConfig.CountdownSeconds = 5
RouteWarsConfig.RunSeconds = 240
RouteWarsConfig.ResultsSeconds = 10

RouteWarsConfig.MinReadyToStart = 1
RouteWarsConfig.ReadyGraceSeconds = 8
RouteWarsConfig.StartWhenAllReady = true
RouteWarsConfig.AllReadyDelay = 3
RouteWarsConfig.AllowMidRaceJoin = true
RouteWarsConfig.MidRaceJoinMinSecondsLeft = 20
RouteWarsConfig.MidRaceJoinDelay = 1.5

-- Track -------------------------------------------------------------------------
-- A reserved TrackBuilder index, well away from the regular mode's bracket
-- tracks (1 and 2): RouteConfig.TrackSpacing studs per step keeps the war
-- track physically separate without pushing it far enough from the origin
-- to hurt physics precision.
RouteWarsConfig.TrackIndex = 10
-- Set a layout id to force every war onto that map; nil means the war
-- lobby's own map vote (WarMapVoteService) decides, like the regular one.
RouteWarsConfig.LayoutId = nil

-- Zone ----------------------------------------------------------------------------
RouteWarsConfig.ZoneName = "RouteWarsZone"
RouteWarsConfig.ZoneCheckInterval = 0.25

return RouteWarsConfig
