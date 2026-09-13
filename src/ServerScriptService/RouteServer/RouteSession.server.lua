--[[
	RouteSession.server.lua

	The round loop -- the ONLY entry point for Route Rush sessions:

	  Intermission  players in the lobby, garage open
	  Countdown     brackets assigned, tracks built, buses spawned (anchored,
	                players seated), garage closed
	  Running       buses released to their drivers; passengers, collisions,
	                and scoring live
	  Results       payouts applied + results sent, everyone back to the lobby

	Phase is published as ReplicatedStorage attributes so every client
	(including late joiners) can read it:
	  SessionPhase  "Intermission" | "Countdown" | "Running" | "Results"
	  PhaseEndsAt   workspace:GetServerTimeNow() when the phase ends
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RouteConfig = require(ReplicatedStorage.Shared.Config.RouteConfig)
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
local BracketService = require(RouteServer.BracketService)

local skipRequested = false
ServerSignals.SkipPhase.Event:Connect(function()
	skipRequested = true
end)

local function setPhase(name, duration)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + duration)
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

local function readyPlayers()
	local ready = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerDataService.Get(player) then
			table.insert(ready, player)
		end
	end
	return ready
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

Players.PlayerRemoving:Connect(function(player)
	BusSpawner.Despawn(player)
	PassengerService.RemovePlayer(player)
	RunScoring.Remove(player)
end)

local function runRound(participants)
	-- Countdown: build the world for this round.
	setPhase("Countdown", RouteConfig.CountdownSeconds)

	local groups = BracketService.Assign(participants)
	local tracks = {}
	for trackIndex, group in ipairs(groups) do
		local track = TrackBuilder.Build(trackIndex)
		table.insert(tracks, track)
		for slot, player in ipairs(group) do
			if player.Parent == Players then
				ensureCharacter(player)
				player:SetAttribute("TrackId", trackIndex)
				BusSpawner.Spawn(player, track, slot)
			end
		end
	end

	-- Building can take a moment; give everyone the full countdown after it.
	setPhase("Countdown", RouteConfig.CountdownSeconds)
	waitPhase(RouteConfig.CountdownSeconds)

	-- Running
	local racers = {}
	for player in pairs(BusSpawner.All()) do
		table.insert(racers, player)
	end
	RunScoring.Begin(racers)
	for _, player in ipairs(racers) do
		BusSpawner.Release(player)
	end
	PassengerService.Start(tracks)
	BusMonitor.Start({
		onImpact = function(player)
			RunScoring.AddCollision(player)
		end,
		onBreakdown = function(player)
			PassengerService.LoseFraction(player, DrivingConfig.Collision.BreakdownPassengerLoss)
		end,
	})

	local started = os.clock()
	setPhase("Running", RouteConfig.RunSeconds)
	waitPhase(RouteConfig.RunSeconds, function()
		return next(BusSpawner.All()) == nil -- everyone left
	end)
	local duration = os.clock() - started

	BusMonitor.Stop()
	PassengerService.Stop()

	-- Results
	setPhase("Results", RouteConfig.ResultsSeconds)
	RunScoring.Finish(duration)
	BusSpawner.DespawnAll()
	for _, track in ipairs(tracks) do
		TrackBuilder.Destroy(track)
	end
	for _, player in ipairs(participants) do
		if player.Parent == Players then
			player:SetAttribute("TrackId", nil)
			LobbyBuilder.SendToLobby(player)
		end
	end
	waitPhase(RouteConfig.ResultsSeconds)
end

-- Main loop ---------------------------------------------------------------------------------------

LobbyBuilder.Ensure()

while true do
	setPhase("Intermission", RouteConfig.IntermissionSeconds)
	waitPhase(RouteConfig.IntermissionSeconds)

	local participants = readyPlayers()
	if #participants >= RouteConfig.MinPlayersToStart then
		local ok, err = pcall(runRound, participants)
		if not ok then
			warn("RouteSession: round failed, cleaning up: " .. tostring(err))
			BusMonitor.Stop()
			PassengerService.Stop()
			BusSpawner.DespawnAll()
			local instances = workspace:FindFirstChild("RouteInstances")
			if instances then
				instances:ClearAllChildren()
			end
			for _, player in ipairs(Players:GetPlayers()) do
				player:SetAttribute("TrackId", nil)
				LobbyBuilder.SendToLobby(player)
			end
		end
	end
end
