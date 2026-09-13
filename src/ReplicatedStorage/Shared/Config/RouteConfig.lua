--[[
	RouteConfig.lua

	Session timing, track generation, stops/passengers, and matchmaking
	brackets. Numbers only (no Roblox types) so pure modules can use it.
]]

local RouteConfig = {}

-- Session phases (seconds) -------------------------------------------------------
RouteConfig.IntermissionSeconds = 30
RouteConfig.CountdownSeconds = 5
RouteConfig.RunSeconds = 300
RouteConfig.ResultsSeconds = 12
RouteConfig.MinPlayersToStart = 1

-- Lobby (used only if workspace has no "Lobby") -------------------------------------
RouteConfig.LobbySize = 140
RouteConfig.LobbyHeight = 0

-- Procedural track (used only if workspace has no "RouteMap") -----------------------
RouteConfig.TrackSeed = 1337
RouteConfig.TrackOriginX = 3000 -- first track's center X
RouteConfig.TrackSpacing = 2500 -- X offset between bracket tracks
RouteConfig.TrackY = 0
RouteConfig.TrackRadiusX = 520
RouteConfig.TrackRadiusZ = 360
RouteConfig.TrackRadiusNoise = 0.18 -- +/- fraction of radius
RouteConfig.TrackSegments = 56
RouteConfig.RoadWidth = 28 -- narrow two-way street
RouteConfig.CurbHeight = 4 -- roadside barriers; taller than any bus's ride height
RouteConfig.GrassMargin = 300 -- studs of ground around the loop
RouteConfig.ObstacleChance = 0.3 -- chance per segment of a parked obstacle
RouteConfig.GridRowSpacing = 46 -- studs between start grid rows (longest bus is 40)
RouteConfig.GridSlots = 24 -- 2 per row

-- Stops & passengers ------------------------------------------------------------------
RouteConfig.StopCount = 8
RouteConfig.StopRadius = 22 -- studs from the stop marker to count as "at the stop"
RouteConfig.BoardMaxSpeed = 4 -- studs/s: must be nearly stopped to load/unload
RouteConfig.WaitingInitial = 8
RouteConfig.WaitingCap = 12
RouteConfig.RefillInterval = 20
RouteConfig.RefillAmount = 3
RouteConfig.DestinationMinAhead = 1
RouteConfig.DestinationMaxAhead = 4
-- Deadline for a passenger = now + (studs to destination / ReferenceSpeed)
--   * DeadlineSlack + DeadlineFlatSeconds
RouteConfig.ReferenceSpeed = 45
RouteConfig.DeadlineSlack = 1.5
RouteConfig.DeadlineFlatSeconds = 10

-- Matchmaking brackets ------------------------------------------------------------------
-- Driving Power Score = TierBaseScore[chassis] + sum(level * PowerWeights[category])
RouteConfig.PowerWeights = {
	Engine = 1.2,
	Accel = 1.1,
	Brakes = 1.0,
	Handles = 1.0,
	Health = 0.8,
}
RouteConfig.TierBaseScore = {
	Tier1 = 0,
	Tier2 = 20,
	Tier3 = 45,
	Tier4 = 75,
}
-- Score below this = bracket 1, otherwise bracket 2.
RouteConfig.BracketThreshold = 30
-- Only split into two tracks if BOTH brackets have at least this many players.
RouteConfig.MinPlayersPerBracket = 2

return RouteConfig
