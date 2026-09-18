--[[
	RouteClient.client.lua

	Client side of the route loop. Wires:
	  - session phase attributes        -> status pill, countdown, ready card
	  - ProfileUpdated remote           -> profile card (cash / level / XP / rep)
	  - your bus appearing in the world -> drive controller, chase camera, stop panel
	  - RunStateUpdated / StopEvent     -> bus card, boarding card, stop panel, toasts
	  - RunResults                      -> results card
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RouteConfig = require(Shared.Config.RouteConfig)
local Boarding = require(Shared.Modules.Boarding)

local UI = script.Parent.Parent:WaitForChild("UI")
local UIKit = require(UI:WaitForChild("UIKit"))
local Format = require(UI:WaitForChild("Format"))
local Theme = UIKit.Theme

local RouteHudBuilder = require(script.Parent.RouteHudBuilder)
local BusDriveController = require(script.Parent.BusDriveController)
local ChaseCamera = require(script.Parent.ChaseCamera)
local StopPanel = require(script.Parent.StopPanel)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProfileUpdated = Remotes:WaitForChild("ProfileUpdated")
local RequestBoard = Remotes:WaitForChild("RequestBoard")
local StopEvent = Remotes:WaitForChild("StopEvent")
local RunStateUpdated = Remotes:WaitForChild("RunStateUpdated")
local RunResults = Remotes:WaitForChild("RunResults")
local SetReady = Remotes:WaitForChild("SetReady")
local SetMapVote = Remotes:WaitForChild("SetMapVote")
local Notify = Remotes:WaitForChild("Notify")

local hud = RouteHudBuilder.Build(playerGui)

local myBus
local runState
local boardBindingsActive = false
local boardHeld = false -- E / Board button held down: keeps boarding
local lastBoardRequest = 0

local PHASE_TEXT = {
	Intermission = "Next route",
	Waiting = "Waiting for players",
	Countdown = "Get ready",
	Running = "Route ends in",
	Results = "Back to lobby",
}

local PHASE_LENGTH = {
	Intermission = RouteConfig.IntermissionSeconds,
	Countdown = RouteConfig.CountdownSeconds,
	Running = RouteConfig.RunSeconds,
	Results = RouteConfig.ResultsSeconds,
}

local function inRace()
	return player:GetAttribute("InRace") == true
end

-- Profile -----------------------------------------------------------------------------------------

ProfileUpdated.OnClientEvent:Connect(function(snapshot)
	local profile = hud.profile
	profile.cash.Text = Format.Cash(snapshot.cash)
	profile.level.Text = "Lv " .. snapshot.level
	profile.rep.Text = "Rep " .. Format.Number(snapshot.reputation)
	UIKit.SetFill(profile.xpFill, snapshot.xpForNext and snapshot.xpIntoLevel / snapshot.xpForNext or 1)
end)

Notify.OnClientEvent:Connect(function(message)
	hud.toast(message, "Accent")
end)

-- Jumping out of the driver's seat ---------------------------------------------------------------

local function setJumpEnabled(enabled)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	end
end

player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid")
	setJumpEnabled(myBus == nil)
end)

-- Boarding card --------------------------------------------------------------------------------------

-- Shown while your bus is inside a stop's ring. Your speed sets the cap on how
-- many you may pick up during this visit (Boarding.lua); the server enforces it.
local function renderBoardCard(phase, speed)
	local board = hud.board
	local visible = myBus ~= nil and runState ~= nil and runState.atStop > 0 and phase == "Running"
	board.panel.Visible = visible
	if not visible then
		return
	end

	local cap = Boarding.BoardCap(speed)
	local boarded = runState.boardedThisStop or 0
	local room = math.max(0, cap - boarded)
	local unlimited = cap == math.huge

	-- The meter is what this pass still has left in it, not a rate.
	local roomFraction = 0
	if unlimited then
		roomFraction = 1
	elseif cap > 0 then
		roomFraction = math.clamp(room / cap, 0, 1)
	end

	board.title.Text = "STOP " .. runState.atStop
	board.subtitle.Text = string.format("%d waiting  ·  %s free", runState.waitingAtStop, Format.Count(runState.seatsLeft, "seat"))
	UIKit.SetFill(board.rateFill, roomFraction, Theme.Colors.Negative:Lerp(Theme.Colors.Positive, roomFraction))
	board.boardedCount.Text = string.format("%d BOARDED", boarded)

	local canBoard = runState.waitingAtStop > 0 and runState.seatsLeft > 0 and room > 0
	board.button.Interactable = canBoard

	local nextTier = Boarding.NextTier(speed)
	local hint, tone
	if runState.seatsLeft == 0 then
		hint, tone = "Bus is full", "Warning"
	elseif runState.waitingAtStop == 0 then
		hint, tone = "Nobody waiting here", "TextMuted"
	elseif cap <= 0 then
		hint, tone = string.format("Too fast — get under %d mph", Boarding.Mph(Boarding.MaxBoardSpeed())), "Negative"
	elseif room <= 0 and nextTier then
		hint, tone = string.format("Slow to %d mph for more", Boarding.Mph(nextTier.speed)), "Warning"
	elseif room <= 0 then
		hint, tone = "That's everyone this pass", "TextMuted"
	elseif unlimited then
		hint, tone = "Slow enough for the whole crowd", "Positive"
	else
		hint, tone = string.format("Spam or hold E · room for %d more", room), "Text"
	end
	board.hint.Text = hint
	board.hint.TextColor3 = Theme.Colors[tone]
end

local function requestBoard()
	local now = os.clock()
	if runState and runState.atStop > 0 and now - lastBoardRequest >= RouteConfig.BoardPressCooldown then
		lastBoardRequest = now
		RequestBoard:FireServer(runState.atStop)
	end
end

local function setBoardBindings(enabled)
	if enabled == boardBindingsActive then
		return
	end
	boardBindingsActive = enabled
	if enabled then
		ContextActionService:BindAction("RouteRushBoard", function(_, state)
			if state == Enum.UserInputState.Begin then
				boardHeld = true
				requestBoard()
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				boardHeld = false
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonA)
	else
		boardHeld = false
		ContextActionService:UnbindAction("RouteRushBoard")
	end
end

hud.board.button.MouseButton1Down:Connect(function()
	boardHeld = true
	requestBoard()
end)
hud.board.button.MouseButton1Up:Connect(function()
	boardHeld = false
end)
hud.board.button.MouseLeave:Connect(function()
	boardHeld = false
end)

RunStateUpdated.OnClientEvent:Connect(function(state)
	runState = state
	StopPanel.SetRunState(state, os.clock())
end)

StopEvent.OnClientEvent:Connect(function(event)
	if event.kind == "delivered" then
		local text = string.format("+%s  ·  %s dropped off", Format.Cash(event.earned), Format.Count(event.count, "passenger"))
		if event.onTime > 0 then
			text = text .. string.format("  ·  %d on time", event.onTime)
		end
		hud.toast(text, "Positive")
	elseif event.kind == "boarded" then
		-- Quiet feedback (you may be spamming E): pulse the boarded counter.
		local label = hud.board.boardedCount
		label.TextTransparency = 0.6
		UIKit.Tween(label, { TextTransparency = 0 }, 0.25)
	elseif event.kind == "impact" then
		hud.toast(string.format("Hit %s  ·  −%d HP", tostring(event.what), event.damage), "Warning")
	elseif event.kind == "towed" then
		hud.toast(string.format("Off the road — towed back (%ds)", event.seconds or 0), "Negative")
	elseif event.kind == "lost" then
		hud.toast(string.format("Breakdown!  %s walked off", Format.Count(event.count, "passenger")), "Negative")
	end
end)

-- Your bus --------------------------------------------------------------------------------------------

local function findMyBus()
	local instances = workspace:FindFirstChild("RouteInstances")
	if not instances then
		return nil
	end
	for _, track in ipairs(instances:GetChildren()) do
		local buses = track:FindFirstChild("Buses")
		if buses then
			for _, bus in ipairs(buses:GetChildren()) do
				if bus:GetAttribute("OwnerUserId") == player.UserId and bus.PrimaryPart then
					return bus
				end
			end
		end
	end
	return nil
end

local function detachBus()
	if not myBus then
		return
	end
	myBus = nil
	runState = nil
	BusDriveController.Stop()
	ChaseCamera.Stop()
	StopPanel.Clear()
	setJumpEnabled(true)
	hud.bus.panel.Visible = false
	hud.speed.panel.Visible = false
	hud.board.panel.Visible = false
end

local function attachBus(bus)
	detachBus()
	myBus = bus
	setJumpEnabled(false)
	ChaseCamera.Start(bus)
	BusDriveController.Start(bus)
	StopPanel.SetTrack(bus:GetAttribute("TrackId"), bus)
	hud.bus.panel.Visible = true
	hud.speed.panel.Visible = true
end

task.spawn(function()
	while true do
		if myBus and not myBus:IsDescendantOf(workspace) then
			detachBus()
		end
		if not myBus then
			local bus = findMyBus()
			if bus then
				attachBus(bus)
			end
		end
		task.wait(0.5)
	end
end)

-- Ready card --------------------------------------------------------------------------------------------

local function isReady()
	return player:GetAttribute("Ready") == true
end

local function renderReady(phase)
	local racing = inRace()
	hud.leaveButton.Visible = racing
	hud.ready.panel.Visible = not racing
	if racing then
		return
	end

	local ready = isReady()
	local readyCount, total = 0, 0
	for _, other in ipairs(Players:GetPlayers()) do
		total = total + 1
		if other:GetAttribute("Ready") == true then
			readyCount = readyCount + 1
		end
	end

	local ui = hud.ready
	if phase == "Countdown" or phase == "Running" then
		ui.title.Text = "Race in progress"
		ui.status.Text = ready and "Dropping you in…" or "Jump in now — you'll race the time that's left"
		ui.button.Text = ready and "Cancel" or "Join race"
	else
		ui.title.Text = "Next race"
		if phase == "Waiting" and readyCount == 0 then
			ui.status.Text = "No race starts until someone readies up"
		else
			ui.status.Text = string.format("%d of %d players ready", readyCount, total)
		end
		ui.button.Text = ready and "Ready  ✓   (click to cancel)" or "Ready up"
	end
	ui.button.BackgroundColor3 = ready and Color3.fromRGB(70, 90, 75) or Color3.fromRGB(50, 140, 70)
end

-- Map vote ------------------------------------------------------------------------------------------

-- Shown in the lobby while the server is taking votes. Like the ready count,
-- the tally is computed here from everyone's replicated MapVote attribute
-- rather than pushed down a remote.
local function renderVote(phase)
	local open = ReplicatedStorage:GetAttribute("VoteOpen") == true
	local visible = not inRace() and open
	hud.vote.panel.Visible = visible
	if not visible then
		return
	end

	local counts, total = {}, 0
	for _, other in ipairs(Players:GetPlayers()) do
		local choice = other:GetAttribute("MapVote")
		if choice then
			counts[choice] = (counts[choice] or 0) + 1
			total = total + 1
		end
	end

	local mine = player:GetAttribute("MapVote")
	local leader = ReplicatedStorage:GetAttribute("VoteLeader")

	for layoutId, row in pairs(hud.vote.rows) do
		local count = counts[layoutId] or 0
		local picked = mine == layoutId
		row.count.Text = count > 0 and tostring(count) or "—"
		row.button.BackgroundColor3 = picked and Color3.fromRGB(50, 110, 70) or Color3.fromRGB(40, 40, 45)
		row.name.TextColor3 = layoutId == leader and Theme.Colors.Accent or Color3.new(1, 1, 1)
		UIKit.SetFill(row.fill, total > 0 and count / total or 0, Theme.Colors.Accent)
	end

	hud.vote.title.Text = total > 0 and string.format("VOTE NEXT MAP  ·  %d cast", total) or "VOTE NEXT MAP"
end

for layoutId, row in pairs(hud.vote.rows) do
	row.button.MouseButton1Click:Connect(function()
		SetMapVote:FireServer(layoutId)
	end)
end

hud.ready.button.MouseButton1Click:Connect(function()
	SetReady:FireServer(not isReady())
end)
hud.leaveButton.MouseButton1Click:Connect(function()
	SetReady:FireServer(false)
end)

-- Countdown ------------------------------------------------------------------------------------------------

local lastCountdownText

local function showCountdown(text, tone)
	local countdown = hud.countdown
	if text == lastCountdownText then
		return
	end
	lastCountdownText = text
	countdown.label.Text = text
	countdown.label.TextColor3 = Theme.Colors[tone or "Text"]
	countdown.label.Visible = true
	countdown.pop.Scale = 1.35
	UIKit.Tween(countdown.pop, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
end

local function hideCountdown()
	lastCountdownText = nil
	hud.countdown.label.Visible = false
end

-- Per-frame HUD ------------------------------------------------------------------------------------------

local lastPhase
RunService.RenderStepped:Connect(function()
	local phase = ReplicatedStorage:GetAttribute("SessionPhase") or "Intermission"
	local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0
	local remaining = endsAt - workspace:GetServerTimeNow()
	local racing = inRace()

	-- Status pill
	local status = hud.status
	status.phase.Text = string.upper(PHASE_TEXT[phase] or phase)
	status.timer.Text = phase == "Waiting" and "—" or Format.Time(remaining)
	status.fares.Visible = racing and phase == "Running"
	local length = PHASE_LENGTH[phase]
	UIKit.SetFill(status.progress, length and math.clamp(remaining / length, 0, 1) or 0)

	renderReady(phase)
	renderVote(phase)

	-- Countdown / GO
	if phase ~= lastPhase then
		if lastPhase == "Countdown" and phase == "Running" and racing then
			showCountdown("GO!", "Positive")
			task.delay(0.9, function()
				if lastCountdownText == "GO!" then
					hideCountdown()
				end
			end)
		elseif phase ~= "Countdown" then
			hideCountdown()
		end
		lastPhase = phase
		setBoardBindings(false)
	end
	if phase == "Countdown" and racing then
		showCountdown(tostring(math.max(1, math.ceil(remaining))), "Text")
	end

	-- Bus
	local bus = myBus
	local telemetry = bus and BusDriveController.GetTelemetry()
	local speed = telemetry and math.abs(telemetry.speed) or 0

	renderBoardCard(phase, speed)
	setBoardBindings(hud.board.panel.Visible)
	if boardHeld and hud.board.panel.Visible then
		requestBoard() -- holding E keeps boarding (rate-limited)
	end

	if not bus then
		return
	end

	hud.speed.set(Boarding.Mph(speed))
	hud.speed.sliding.Visible = telemetry ~= nil and telemetry.sliding

	local card = hud.bus
	local passengers = bus:GetAttribute("Passengers") or 0
	local capacity = math.max(bus:GetAttribute("Capacity") or 1, 1)
	local load = passengers / capacity
	card.passengers.Text = string.format("%d / %d", passengers, capacity)
	UIKit.SetFill(card.loadFill, load, Theme.Colors.Positive:Lerp(Theme.Colors.Warning, load))

	local health = bus:GetAttribute("Health") or 0
	local maxHealth = math.max(bus:GetAttribute("MaxHealth") or 1, 1)
	UIKit.SetFill(card.healthFill, health / maxHealth)
	-- A tow also sets BrokenDown (it reuses the same freeze), so check it first
	-- or being towed reads as engine damage.
	if bus:GetAttribute("Towing") then
		card.health.Text = "TOWING…"
		card.health.TextColor3 = Theme.Colors.Warning
	elseif bus:GetAttribute("BrokenDown") then
		card.health.Text = "BROKEN DOWN"
		card.health.TextColor3 = Theme.Colors.Negative
	else
		card.health.Text = string.format("%d / %d", health, maxHealth)
		card.health.TextColor3 = Theme.Colors.Text
	end

	if runState then
		status.faresValue.Text = Format.Cash(runState.fares)
		card.stats.Text = string.format(
			"%d delivered  ·  streak %d  ·  %d hits",
			runState.deliveries,
			runState.cleanStreak,
			runState.collisions
		)
	end

	-- If throttle is held but the bus can't move, say why.
	local problem = telemetry and telemetry.problem
	card.problem.Visible = problem ~= nil
	if problem then
		card.problem.Text = "⚠  " .. problem
	end
end)

-- Results ----------------------------------------------------------------------------------------------------

local resultsToken = 0
RunResults.OnClientEvent:Connect(function(results)
	local card = hud.results
	card.clear()
	card.total.Text = Format.Cash(results.cash)

	card.addRow("Fares collected", Format.Cash(results.fares))
	card.addRow("Passengers delivered", string.format("%d  (%d on time)", results.deliveries, results.onTimeDeliveries))
	card.addRow("Fares per minute", Format.Cash(results.faresPerMinute))
	card.addRow("Collisions  ·  best clean streak", string.format("%d  ·  %d", results.collisions, results.bestCleanStreak))
	if results.cleanBonus > 0 then
		card.addRow("Clean-run bonus", "+" .. Format.Cash(results.cleanBonus), "Positive")
	end
	if results.passengersLost > 0 then
		card.addRow("Lost to breakdowns", Format.Count(results.passengersLost, "passenger"), "Negative")
	end
	card.addRow("Reputation", "+" .. Format.Number(results.reputation), "Accent")
	card.addRow("XP", "+" .. Format.Number(results.xp), "Info")
	if results.levelAfter > results.levelBefore then
		card.addRow("Level up!", "Level " .. results.levelAfter, "Info")
	end
	if results.slotsAfter > results.slotsBefore then
		card.addRow("New skill slots unlocked", "+" .. (results.slotsAfter - results.slotsBefore), "Accent")
	end

	card.panel.Visible = true
	resultsToken = resultsToken + 1
	local myToken = resultsToken
	task.delay(RouteConfig.ResultsSeconds, function()
		if resultsToken == myToken then
			card.panel.Visible = false
		end
	end)
end)
