--[[
	RouteWarsSession.server.lua

	The RouteWars round loop: a second, independent copy of RouteSession's
	Intermission -> Countdown -> Running -> Results loop, running in
	parallel with the regular one. Standing in the "RouteWarsZone" part
	(RouteWarsZoneService) is this loop's Ready button (WarReadyService).

	It shares almost everything with the regular loop -- the same
	TrackBuilder maps, BusSpawner buses, PassengerService stops/fares, and
	BusMonitor collisions -- just on a track of its own (RouteWarsConfig.
	TrackIndex) with weapons live (WeaponService). See BusMonitor.Watch,
	PassengerService.AddTracks/RemoveTracks, and RunScoring.Begin/Finish for
	how those shared services stay correct with two rounds live at once.

	Only ever builds ONE track (no brackets, no map vote -- always
	RouteWarsConfig.LayoutId or the default layout). Phase is published
	under its own attribute names so the regular HUD and the war HUD never
	collide:
	  WarSessionPhase, WarPhaseEndsAt
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RouteConfig = require(ReplicatedStorage.Shared.Config.RouteConfig)
local RouteWarsConfig = require(ReplicatedStorage.Shared.Config.RouteWarsConfig)
local DrivingConfig = require(ReplicatedStorage.Shared.Config.DrivingConfig)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local ServerSignals = require(ServerScriptService.Services.ServerSignals)

local RouteServer = script.Parent
local LobbyBuilder = require(RouteServer.LobbyBuilder)
local TrackBuilder = require(RouteServer.TrackBuilder)
local BusSpawner = require(RouteServer.BusSpawner)
local BusMonitor = require(RouteServer.BusMonitor)
local PassengerService = require(RouteServer.PassengerService)
local RunScoring = require(RouteServer.RunScoring)
local WarReadyService = require(RouteServer.WarReadyService)
local WeaponService = require(RouteServer.WeaponService)
local RouteWarsZoneService = require(RouteServer.RouteWarsZoneService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")

local skipRequested = false
ServerSignals.SkipWarPhase.Event:Connect(function()
	skipRequested = true
end)

-- { phase, track, racers = {[Player] = true}, nextSlot, running, endsAt, monitor }
local currentRound

local function setPhase(name, duration)
	ReplicatedStorage:SetAttribute("WarPhaseEndsAt", duration and (workspace:GetServerTimeNow() + duration) or 0)
	ReplicatedStorage:SetAttribute("WarSessionPhase", name)
end

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

local function addToRound(player)
	local round = currentRound
	if not round or round.racers[player] or player.Parent ~= Players then
		return
	end
	if not PlayerDataService.Get(player) then
		return
	end

	round.racers[player] = true
	ensureCharacter(player)
	if currentRound ~= round or player.Parent ~= Players or not round.racers[player] then
		round.racers[player] = nil
		return
	end

	local slot = round.nextSlot
	round.nextSlot = slot % RouteConfig.GridSlots + 1
	player:SetAttribute("TrackId", round.track.id)
	player:SetAttribute("InWar", true)
	BusSpawner.Spawn(player, round.track, slot)
	BusMonitor.ResetDistance(player)

	if round.running then
		RunScoring.AddPlayer(player)
		PassengerService.AddPlayer(player)
		task.wait(RouteWarsConfig.MidRaceJoinDelay)
		if currentRound == round and round.running and round.racers[player] then
			BusSpawner.Release(player)
		end
	end
end

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
	WeaponService.RemovePlayer(player)
	BusSpawner.Despawn(player)
	player:SetAttribute("TrackId", nil)
	player:SetAttribute("InWar", false)
	LobbyBuilder.SendToLobby(player)
end

WarReadyService.Changed.Event:Connect(function(player, ready)
	local round = currentRound
	if not round then
		return
	end
	if ready then
		if round.phase == "Countdown" then
			task.spawn(addToRound, player)
		elseif round.phase == "Running" and RouteWarsConfig.AllowMidRaceJoin then
			if round.endsAt - os.clock() >= RouteWarsConfig.MidRaceJoinMinSecondsLeft then
				task.spawn(addToRound, player)
			else
				Notify:FireClient(player, "This war is almost over — you'll join the next one.")
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
	WeaponService.RemovePlayer(player)
end)

-- Lobby -------------------------------------------------------------------------------------------------

local function runLobby()
	local minimum = RouteWarsConfig.MinReadyToStart
	local endsAt = os.clock() + RouteWarsConfig.IntermissionSeconds
	setPhase("Intermission", RouteWarsConfig.IntermissionSeconds)
	skipRequested = false

	while true do
		local readyCount, total = WarReadyService.Count()
		local now = os.clock()

		if skipRequested then
			skipRequested = false
			if readyCount >= minimum then
				return
			end
		end

		if RouteWarsConfig.StartWhenAllReady and readyCount >= minimum and readyCount == total
			and endsAt - now > RouteWarsConfig.AllReadyDelay then
			endsAt = now + RouteWarsConfig.AllReadyDelay
			setPhase("Intermission", RouteWarsConfig.AllReadyDelay)
		end

		if now >= endsAt then
			if readyCount >= minimum then
				return
			end
			setPhase("Waiting", nil)
			while WarReadyService.Count() < minimum do
				task.wait(0.2)
			end
			endsAt = os.clock() + RouteWarsConfig.ReadyGraceSeconds
			setPhase("Intermission", RouteWarsConfig.ReadyGraceSeconds)
		end

		task.wait(0.1)
	end
end

-- Round ---------------------------------------------------------------------------------------------------

local function runRound(participants)
	local round = {
		phase = "Countdown",
		track = nil,
		racers = {},
		nextSlot = 1,
		running = false,
		endsAt = 0,
		monitor = nil,
	}
	currentRound = round

	setPhase("Countdown", RouteWarsConfig.CountdownSeconds)
	local track = TrackBuilder.Build(RouteWarsConfig.TrackIndex, RouteWarsConfig.LayoutId)
	round.track = track

	for _, player in ipairs(participants) do
		if WarReadyService.IsReady(player) then
			addToRound(player)
		end
	end

	setPhase("Countdown", RouteWarsConfig.CountdownSeconds)
	waitPhase(RouteWarsConfig.CountdownSeconds)

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
	PassengerService.AddTracks({ track })
	WeaponService.StartRound(track)
	round.monitor = BusMonitor.Watch({ track.id }, {
		onImpact = function(player)
			RunScoring.AddCollision(player)
		end,
		onBreakdown = function(player)
			PassengerService.LoseFraction(player, DrivingConfig.Collision.BreakdownPassengerLoss)
		end,
	})
	round.phase = "Running"
	round.running = true
	round.endsAt = os.clock() + RouteWarsConfig.RunSeconds

	setPhase("Running", RouteWarsConfig.RunSeconds)
	waitPhase(RouteWarsConfig.RunSeconds, function()
		for player in pairs(round.racers) do
			if BusSpawner.GetRecord(player) then
				return false
			end
		end
		return true
	end)

	round.running = false
	round.phase = "Results"
	round.monitor:Stop()
	WeaponService.EndRound()

	local racerList = {}
	for player in pairs(round.racers) do
		table.insert(racerList, player)
		PassengerService.RemovePlayer(player)
	end
	PassengerService.RemoveTracks({ track })

	setPhase("Results", RouteWarsConfig.ResultsSeconds)

	RunScoring.Finish(racerList)
	for _, player in ipairs(racerList) do
		BusSpawner.Despawn(player)
	end
	TrackBuilder.Destroy(track)
	for _, player in ipairs(racerList) do
		if player.Parent == Players then
			player:SetAttribute("TrackId", nil)
			player:SetAttribute("InWar", false)
			LobbyBuilder.SendToLobby(player)
			-- Readiness here is proxied by standing in the zone, not a
			-- persistent toggle: you're back in the lobby now, away from
			-- it, so don't silently pull you into the next war too.
			WarReadyService.SetReady(player, false)
		end
	end
	currentRound = nil
	waitPhase(RouteWarsConfig.ResultsSeconds)
end

-- Main loop ---------------------------------------------------------------------------------------------------

RouteWarsZoneService.Start()

while true do
	runLobby()

	local participants = WarReadyService.ReadyPlayers()
	if #participants >= RouteWarsConfig.MinReadyToStart then
		local ok, err = pcall(runRound, participants)
		if not ok then
			warn("RouteWarsSession: round failed, cleaning up: " .. tostring(err))
			local crashedRound = currentRound
			currentRound = nil
			WeaponService.EndRound()
			if crashedRound and crashedRound.track then
				if crashedRound.monitor then
					crashedRound.monitor:Stop()
				end
				PassengerService.RemoveTracks({ crashedRound.track })
				TrackBuilder.Destroy(crashedRound.track)
			end
			for player in pairs((crashedRound or {}).racers or {}) do
				BusSpawner.Despawn(player)
				PassengerService.RemovePlayer(player)
				RunScoring.Remove(player)
				if player.Parent == Players then
					player:SetAttribute("TrackId", nil)
					player:SetAttribute("InWar", false)
					LobbyBuilder.SendToLobby(player)
					WarReadyService.SetReady(player, false)
				end
			end
		end
	end
end
