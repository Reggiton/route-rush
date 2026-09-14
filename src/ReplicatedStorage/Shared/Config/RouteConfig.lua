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

-- Ready-up --------------------------------------------------------------------------------
-- Players click Ready in the lobby. Not-Ready players just stay in the lobby.
RouteConfig.MinReadyToStart = 1 -- no race starts until at least this many players are Ready
RouteConfig.ReadyGraceSeconds = 10 -- countdown after someone readies once the intermission ran out
RouteConfig.StartWhenAllReady = true -- if every player in the server is Ready, skip ahead...
RouteConfig.AllReadyDelay = 3 -- ...to this many seconds
RouteConfig.AllowMidRaceJoin = true -- readying up during a race drops you straight in...
RouteConfig.MidRaceJoinMinSecondsLeft = 20 -- ...unless less than this much race time is left
RouteConfig.MidRaceJoinDelay = 1.5 -- seconds seated before a mid-race joiner can drive
-- Ready players stay Ready between races, except idle ones: a racer who spent at
-- least AfkMinSecondsInRace in a race, drove less than AfkDistanceStuds, and
-- delivered nobody is set back to Not Ready.
RouteConfig.AfkMinSecondsInRace = 60
RouteConfig.AfkDistanceStuds = 150

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
RouteConfig.GridSlots = 24 -- spread across the layout's gridColumns
RouteConfig.HillAmplitude = 55 -- studs of climb/descent on the Hill Circuit layout

-- Stops & passengers ------------------------------------------------------------------
RouteConfig.StopCount = 8
-- Each stop is a glowing rectangular bay against one kerb. A bus is "at the stop"
-- while its center is inside the bay -- it's narrower than the road, so drivers
-- have to steer into it. Stops alternate sides, so you cross the road each time.
RouteConfig.StopBayWidth = 12 -- studs across (one lane is RoadWidth / 2 = 14)
RouteConfig.StopBayLength = 34 -- studs along the road
RouteConfig.StopBayMargin = 1.5 -- extra tolerance around the bay edges (studs)
RouteConfig.StopGlowHeight = 2.5 -- low light walls along the bay's sides (0 = none)
RouteConfig.AlternateStopSides = true -- odd stops on the left kerb, even on the right

-- Boarding on the move ------------------------------------------------------------------
-- You never have to stop. How fast you are rolling through a bay decides whether
-- anyone can get off, and how many you can pick up:
--
--     30 mph or under   drop-offs happen, and you can pick up 2
--     20 mph or under   you can pick up 4
--     10 mph or under   you can pick up as many as the bus will hold
--
-- The cap counts everyone boarded during this visit, so you can take 2 at 30,
-- brake to 20 and take 2 more. Above the fastest tier nothing happens at all.
-- Dropping one passenger off is cheap; filling the bus costs you real time.
-- Thresholds are stored in studs/second -- the unit the game actually measures --
-- so retuning the speedometer can never silently move them. StudsPerMph is a
-- DISPLAY conversion only: it turns studs/s into the mph the HUD shows, and the
-- tier speeds below are chosen to land on round mph numbers under it.
RouteConfig.StudsPerMph = 1.5 -- display only; 1 stud ~= 0.28 m, so this is close to true
RouteConfig.DropOffSpeed = 45 -- studs/s (30 mph): at or under this, passengers get off
-- Order does not matter; Boarding.lua takes the best cap you qualify for.
-- math.huge means "no limit beyond the bus's own capacity".
RouteConfig.BoardTiers = {
	{ speed = 45, board = 2 }, -- 30 mph
	{ speed = 30, board = 4 }, -- 20 mph
	{ speed = 15, board = math.huge }, -- 10 mph
}
RouteConfig.MaxBoardPerPress = 2 -- passengers one E press can board
RouteConfig.BoardPressCooldown = 0.1 -- seconds; holding E repeats at this rate
RouteConfig.WaitingInitial = 8
RouteConfig.WaitingCap = 12
RouteConfig.RefillInterval = 20
RouteConfig.RefillAmount = 3
RouteConfig.DestinationMinAhead = 1
RouteConfig.DestinationMaxAhead = 4
-- Deadline for a passenger = now + (studs to destination / ReferenceSpeed)
--   * DeadlineSlack + DeadlineFlatSeconds
RouteConfig.ReferenceSpeed = 60
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
