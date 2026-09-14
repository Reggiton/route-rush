--[[
	RouteSession.server.lua

	The round loop -- the ONLY entry point for Route Rush sessions:

	  Intermission  lobby; players click Ready. The timer only leads to a
	                race if at least RouteConfig.MinReadyToStart are Ready.
	  Waiting       timer ran out with nobody Ready: no race until someone
	                readies up (then a short ReadyGraceSeconds countdown)
	  Countdown     brackets assigned, tracks built, Ready players seated
	  Running       buses released; passengers, collisions, scoring live
	  Results       payouts applied + results sent, racers back to the lobby

	Players who aren't Ready just stay in the lobby (garage available).
	Readying up during Countdown/Running drops you into that race;
	un-readying during a race sends you back to the lobby (paid for what
	you delivered). Ready players stay Ready for the next round, except
	players who were idle for a whole race.

	Phase is published as ReplicatedStorage attributes so every client
	(including late joiners) can read it:
	  SessionPhase  "Intermission" | "Waiting" | "Countdown" | "Running" | "Results"
	  PhaseEndsAt   workspace:GetServerTimeNow() when the phase ends (0 = no timer)
	  VoteOpen      true while the lobby map vote is taking votes
	  VoteLeader    the layout currently winning that vote
	  MapLayout     the layout this race is being run on
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RouteConfig = require(ReplicatedStorage.Shared.Config.RouteConfig)
local DrivingConfig = require(ReplicatedStorage.Shared.Config.DrivingConfig)
local PowerScore = require(ReplicatedStorage.Shared.Modules.PowerScore)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local ServerSignals = require(ServerScriptService.Services.ServerSignals)

local RouteServer = script.Parent
local LobbyBuilder = require(RouteServer.LobbyBuilder)
local TrackBuilder = require(RouteServer.TrackBuilder)
local BusSpawner = require(RouteServer.BusSpawner)
local BusMonitor = require(RouteServer.BusMonitor)
local PassengerService = require(RouteServer.PassengerService)
local RunScoring = require(RouteServer.RunScoring)
local BracketService = require(RouteServer.BracketService)
local ReadyService = require(RouteServer.ReadyService)
local MapVoteService = require(RouteServer.MapVoteService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")

local skipRequested = false
ServerSignals.SkipPhase.Event:Connect(function()
	skipRequested = true
end)

-- The round in progress, or nil while in the lobby.
-- { phase, tracks = {track}, split = bool, racers = {[Player] = true}, nextSlot = {[trackId] = n}, running, endsAt }
local currentRound

-- Phase attributes ---------------------------------------------------------------------------

local function setPhase(name, duration)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", duration and (workspace:GetServerTimeNow() + duration) or 0)
	ReplicatedStorage:SetAttribute("SessionPhase", name)
end

-- Waits `duration` seconds, or until skipped / earlyExit() returns true.
local function waitPhase(duration, earlyExit)
	skipRequested = false
	local endsAt = os.clock() + duration
	while os.clock() < endsAt do
		if skipRequested or (earlyExit and earlyExit()) then
			skipRequested = false
			return
		end
		task.wait(0.1)
	end
end

local function ensureCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return
	end
	player:LoadCharacter()
	local started = os.clock()
	while player.Parent and os.clock() - started < 5 do
		character = player.Character
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return
		end
		task.wait(0.1)
	end
end

-- Joining / leaving a round ------------------------------------------------------------------------

-- Seats a player on a track of the current round. If the race is already
-- running, they're added to scoring and released after a short delay.
local function addToRound(player, track)
	local round = currentRound
	if not round or round.racers[player] or player.Parent ~= Players then
		return
	end
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end

	if not track then
		track = round.tracks[1]
		if round.split then
			local score = PowerScore.Driving(data.selectedChassis, data.chassis[data.selectedChassis].upgrades)
			track = round.tracks[PowerScore.Bracket(score)] or track
		end
	end

	round.racers[player] = true
	ensureCharacter(player)
	if currentRound ~= round or player.Parent ~= Players or not round.racers[player] then
		round.racers[player] = nil
		return
	end

	local slot = round.nextSlot[track.id] or 1
	round.nextSlot[track.id] = slot % RouteConfig.GridSlots + 1
	player:SetAttribute("TrackId", track.id)
	BusSpawner.Spawn(player, track, slot)

	if round.running then
		RunScoring.AddPlayer(player)
		PassengerService.AddPlayer(player)
		task.wait(RouteConfig.MidRaceJoinDelay)
		if currentRound == round and round.running and round.racers[player] then
			BusSpawner.Release(player)
		end
	end
end

-- Sends a racer back to the lobby, paying for what they did so far.
local function removeFromRound(player)
	local round = currentRound
	if not round or not round.racers[player] then
		return
	end
	round.racers[player] = nil
	if round.running then
		RunScoring.FinishPlayer(player)
	else
		RunScoring.Remove(player)
	end
	PassengerService.RemovePlayer(player)
	BusSpawner.Despawn(player)
	player:SetAttribute("TrackId", nil)
	LobbyBuilder.SendToLobby(player)
end

ReadyService.Changed.Event:Connect(function(player, ready)
	local round = currentRound
	if not round then
		return
	end
	if ready then
		if round.phase == "Countdown" then
			task.spawn(addToRound, player)
		elseif round.phase == "Running" and RouteConfig.AllowMidRaceJoin then
			if round.endsAt - os.clock() >= RouteConfig.MidRaceJoinMinSecondsLeft then
				task.spawn(addToRound, player)
			else
				Notify:FireClient(player, "This race is almost over — you'll join the next one.")
			end
		end
	elseif round.racers[player] and (round.phase == "Countdown" or round.phase == "Running") then
		task.spawn(removeFromRound, player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if currentRound then
		currentRound.racers[player] = nil
	end
	BusSpawner.Despawn(player)
	PassengerService.RemovePlayer(player)
	RunScoring.Remove(player)
end)

-- Lobby -------------------------------------------------------------------------------------------------

-- Runs the intermission (and waiting-for-ready) until a race should start.
local function runLobby()
	local minimum = RouteConfig.MinReadyToStart
	local endsAt = os.clock() + RouteConfig.IntermissionSeconds
	setPhase("Intermission", RouteConfig.IntermissionSeconds)
	MapVoteService.Begin()
	skipRequested = false

	while true do
		local readyCount, total = ReadyService.Count()
		local now = os.clock()

		if skipRequested then
			skipRequested = false
			if readyCount >= minimum then
				return
			end
		end

		-- Everyone's ready: no need to wait out the whole timer.
		if RouteConfig.StartWhenAllReady and readyCount >= minimum and readyCount == total
			and endsAt - now > RouteConfig.AllReadyDelay then
			endsAt = now + RouteConfig.AllReadyDelay
			setPhase("Intermission", RouteConfig.AllReadyDelay)
		end

		if now >= endsAt then
			if readyCount >= minimum then
				return
			end
			-- Not enough Ready players: hold until someone readies up.
			setPhase("Waiting", nil)
			while ReadyService.Count() < minimum do
				task.wait(0.2)
			end
			endsAt = os.clock() + RouteConfig.ReadyGraceSeconds
			setPhase("Intermission", RouteConfig.ReadyGraceSeconds)
		end

		task.wait(0.1)
	end
end

-- Round ---------------------------------------------------------------------------------------------------

local function runRound(participants)
	local round = {
		phase = "Countdown",
		tracks = {},
		split = false,
		racers = {},
		nextSlot = {},
		running = false,
		endsAt = 0,
	}
	currentRound = round

	-- Countdown: build the world for this round. The vote closes here, the last
	-- moment before the tracks exist, so a late voter still counts. Both bracket
	-- tracks use the same layout -- one vote, one map.
	setPhase("Countdown", RouteConfig.CountdownSeconds)
	local layoutId = MapVoteService.Close()
	ReplicatedStorage:SetAttribute("MapLayout", layoutId)

	local groups = BracketService.Assign(participants)
	round.split = #groups > 1
	for trackIndex in ipairs(groups) do
		local track = TrackBuilder.Build(trackIndex, layoutId)
		round.tracks[trackIndex] = track
		round.nextSlot[track.id] = 1
	end
	for trackIndex, group in ipairs(groups) do
		for _, player in ipairs(group) do
			if ReadyService.IsReady(player) then
				addToRound(player, round.tracks[trackIndex])
			end
		end
	end

	-- Building can take a moment; give everyone the full countdown after it.
	setPhase("Countdown", RouteConfig.CountdownSeconds)
	waitPhase(RouteConfig.CountdownSeconds)

	-- Running
	local starters = {}
	for player in pairs(round.racers) do
		if BusSpawner.GetRecord(player) then
			table.insert(starters, player)
		end
	end
	RunScoring.Begin(starters)
	for _, player in ipairs(starters) do
		BusSpawner.Release(player)
	end
	PassengerService.Start(round.tracks)
	BusMonitor.Start({
		onImpact = function(player)
			RunScoring.AddCollision(player)
		end,
		onBreakdown = function(player)
			PassengerService.LoseFraction(player, DrivingConfig.Collision.BreakdownPassengerLoss)
		end,
	})
	round.phase = "Running"
	round.running = true
	round.endsAt = os.clock() + RouteConfig.RunSeconds

	setPhase("Running", RouteConfig.RunSeconds)
	waitPhase(RouteConfig.RunSeconds, function()
		return next(BusSpawner.All()) == nil -- everyone left
	end)

	round.running = false
	round.phase = "Results"
	BusMonitor.Stop()
	PassengerService.Stop()

	-- Results
	setPhase("Results", RouteConfig.ResultsSeconds)

	-- Idle racers stop being Ready so they don't sit in every future race.
	for player in pairs(round.racers) do
		local stats = RunScoring.Get(player)
		if stats and player.Parent == Players then
			local timeInRace = os.clock() - stats.startedAt
			if timeInRace >= RouteConfig.AfkMinSecondsInRace and stats.deliveries == 0
				and BusMonitor.GetDistance(player) < RouteConfig.AfkDistanceStuds then
				ReadyService.SetReady(player, false)
				Notify:FireClient(player, "You were idle, so you've been set to Not Ready.")
			end
		end
	end

	RunScoring.Finish()
	BusSpawner.DespawnAll()
	ReplicatedStorage:SetAttribute("MapLayout", nil)
	for _, track in ipairs(round.tracks) do
		TrackBuilder.Destroy(track)
	end
	for player in pairs(round.racers) do
		if player.Parent == Players then
			player:SetAttribute("TrackId", nil)
			LobbyBuilder.SendToLobby(player)
		end
	end
	currentRound = nil
	waitPhase(RouteConfig.ResultsSeconds)
end

-- Main loop ---------------------------------------------------------------------------------------------------

LobbyBuilder.Ensure()

while true do
	runLobby()

	local participants = ReadyService.ReadyPlayers()
	if #participants >= RouteConfig.MinReadyToStart then
		local ok, err = pcall(runRound, participants)
		if not ok then
			warn("RouteSession: round failed, cleaning up: " .. tostring(err))
			currentRound = nil
			BusMonitor.Stop()
			PassengerService.Stop()
			BusSpawner.DespawnAll()
			local instances = workspace:FindFirstChild("RouteInstances")
			if instances then
				instances:ClearAllChildren()
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if player:GetAttribute("TrackId") then
					player:SetAttribute("TrackId", nil)
					LobbyBuilder.SendToLobby(player)
				end
			end
		end
	end
end
