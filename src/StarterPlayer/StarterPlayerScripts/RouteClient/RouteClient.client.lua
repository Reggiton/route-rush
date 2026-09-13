--[[
	RouteClient.client.lua

	Client side of the route loop. Wires:
	  - session phase attributes      -> top-bar timer, countdown overlay
	  - ProfileUpdated remote         -> cash / level / XP / rep
	  - your bus appearing in the world -> drive controller + chase camera
	  - RunStateUpdated / StopEvent   -> bus panel, boarding panel, toasts
	  - RunResults                    -> results screen
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RouteConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.RouteConfig)
local RouteHudBuilder = require(script.Parent.RouteHudBuilder)
local BusDriveController = require(script.Parent.BusDriveController)
local ChaseCamera = require(script.Parent.ChaseCamera)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProfileUpdated = Remotes:WaitForChild("ProfileUpdated")
local RequestBoard = Remotes:WaitForChild("RequestBoard")
local StopEvent = Remotes:WaitForChild("StopEvent")
local RunStateUpdated = Remotes:WaitForChild("RunStateUpdated")
local RunResults = Remotes:WaitForChild("RunResults")

local hud = RouteHudBuilder.Build(playerGui)

local myBus
local runState
local boardCount = 1
local lastAtStop = 0
local boardBindingsActive = false

-- Formatting ---------------------------------------------------------------------------------

local function formatCash(amount)
	local digits = tostring(math.floor(math.abs(amount)))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (amount < 0 and "-$" or "$") .. formatted
end

local function formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local PHASE_TEXT = {
	Intermission = "Next route in",
	Countdown = "Route starting",
	Running = "Route ends in",
	Results = "Back to lobby in",
}

-- Toasts ---------------------------------------------------------------------------------------

local toastToken = 0
local function showToast(message, color)
	toastToken = toastToken + 1
	local myToken = toastToken
	hud.toast.Text = message
	hud.toast.TextColor3 = color or Color3.new(1, 1, 1)
	hud.toast.Visible = true
	task.delay(2.5, function()
		if toastToken == myToken then
			hud.toast.Visible = false
		end
	end)
end

-- Profile -----------------------------------------------------------------------------------------

ProfileUpdated.OnClientEvent:Connect(function(snapshot)
	hud.cashLabel.Text = formatCash(snapshot.cash)
	hud.levelLabel.Text = "Lv " .. snapshot.level
	hud.repLabel.Text = "Rep " .. snapshot.reputation
	local fraction = snapshot.xpForNext and snapshot.xpIntoLevel / snapshot.xpForNext or 1
	hud.xpFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
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

-- Boarding panel ----------------------------------------------------------------------------------

local function maxBoardable()
	if not runState then
		return 0
	end
	return math.min(runState.waitingAtStop, runState.seatsLeft)
end

local function renderBoardPanel()
	local phase = ReplicatedStorage:GetAttribute("SessionPhase")
	local visible = myBus ~= nil and runState ~= nil and runState.atStop > 0 and phase == "Running"
	hud.boardPanel.Visible = visible
	if not visible then
		return
	end

	local maximum = maxBoardable()
	boardCount = math.clamp(boardCount, math.min(1, maximum), maximum)
	hud.boardTitle.Text = string.format("Stop %d · %d waiting · %d seats left", runState.atStop, runState.waitingAtStop, runState.seatsLeft)
	hud.boardCount.Text = tostring(boardCount)
	hud.boardMinus.Interactable = boardCount > 1
	hud.boardPlus.Interactable = boardCount < maximum
	hud.boardButton.Interactable = boardCount > 0

	local capacity = math.max(runState.capacity, 1)
	local loadAfter = (runState.passengers + boardCount) / capacity
	if maximum == 0 then
		hud.boardHint.Text = runState.seatsLeft == 0 and "Bus is full" or "Nobody waiting here"
	else
		hud.boardHint.Text = string.format("Load after boarding: %d%% — heavier = slower & slidier", math.floor(loadAfter * 100))
	end
end

local function adjustBoard(delta)
	boardCount = boardCount + delta
	renderBoardPanel()
end

local function confirmBoard()
	if runState and runState.atStop > 0 and boardCount > 0 then
		RequestBoard:FireServer(runState.atStop, boardCount)
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
				confirmBoard()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonA)
		ContextActionService:BindAction("RouteRushBoardLess", function(_, state)
			if state == Enum.UserInputState.Begin then
				adjustBoard(-1)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Z, Enum.KeyCode.DPadLeft)
		ContextActionService:BindAction("RouteRushBoardMore", function(_, state)
			if state == Enum.UserInputState.Begin then
				adjustBoard(1)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.X, Enum.KeyCode.DPadRight)
	else
		ContextActionService:UnbindAction("RouteRushBoard")
		ContextActionService:UnbindAction("RouteRushBoardLess")
		ContextActionService:UnbindAction("RouteRushBoardMore")
	end
end

hud.boardMinus.MouseButton1Click:Connect(function()
	adjustBoard(-1)
end)
hud.boardPlus.MouseButton1Click:Connect(function()
	adjustBoard(1)
end)
hud.boardButton.MouseButton1Click:Connect(confirmBoard)

RunStateUpdated.OnClientEvent:Connect(function(state)
	runState = state
	if state.atStop ~= lastAtStop then
		lastAtStop = state.atStop
		boardCount = maxBoardable() -- default: take everyone who fits
	end
	renderBoardPanel()
end)

StopEvent.OnClientEvent:Connect(function(event)
	if event.kind == "delivered" then
		showToast(
			string.format("+%s · %d dropped off (%d on time)", formatCash(event.earned), event.count, event.onTime),
			Color3.fromRGB(120, 220, 140)
		)
	elseif event.kind == "boarded" then
		showToast(string.format("%d passenger%s boarded", event.count, event.count == 1 and "" or "s"))
	elseif event.kind == "impact" then
		showToast(string.format("Hit %s  −%d HP", tostring(event.what), event.damage), Color3.fromRGB(240, 160, 90))
	elseif event.kind == "lost" then
		showToast(string.format("Breakdown! %d passenger%s walked off", event.count, event.count == 1 and "" or "s"), Color3.fromRGB(240, 120, 100))
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
	lastAtStop = 0
	BusDriveController.Stop()
	ChaseCamera.Stop()
	setJumpEnabled(true)
	hud.runPanel.Visible = false
	renderBoardPanel()
end

local function attachBus(bus)
	detachBus()
	myBus = bus
	setJumpEnabled(false)
	ChaseCamera.Start(bus)
	BusDriveController.Start(bus)
	hud.runPanel.Visible = true
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

-- Per-frame HUD ------------------------------------------------------------------------------------------

local lastPhase
RunService.RenderStepped:Connect(function()
	local phase = ReplicatedStorage:GetAttribute("SessionPhase") or "Intermission"
	local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0
	local remaining = endsAt - workspace:GetServerTimeNow()

	hud.phaseLabel.Text = PHASE_TEXT[phase] or phase
	hud.timerLabel.Text = formatTime(remaining)

	if phase ~= lastPhase then
		if lastPhase == "Countdown" and phase == "Running" then
			hud.countdownLabel.Text = "GO!"
			hud.countdownLabel.Visible = true
			task.delay(1, function()
				if ReplicatedStorage:GetAttribute("SessionPhase") ~= "Countdown" then
					hud.countdownLabel.Visible = false
				end
			end)
		elseif phase ~= "Countdown" then
			hud.countdownLabel.Visible = false
		end
		lastPhase = phase
		renderBoardPanel()
		setBoardBindings(false)
	end
	if phase == "Countdown" then
		hud.countdownLabel.Visible = true
		hud.countdownLabel.Text = tostring(math.max(1, math.ceil(remaining)))
	end

	setBoardBindings(hud.boardPanel.Visible)

	-- Bus panel
	local bus = myBus
	if not bus then
		return
	end
	local telemetry = BusDriveController.GetTelemetry()
	local speed = telemetry and math.abs(telemetry.speed) or 0
	hud.speedLabel.Text = string.format("%d", math.floor(speed))
	if telemetry and telemetry.sliding then
		hud.speedLabel.TextColor3 = Color3.fromRGB(240, 140, 110)
	else
		hud.speedLabel.TextColor3 = Color3.new(1, 1, 1)
	end

	local passengers = bus:GetAttribute("Passengers") or 0
	local capacity = math.max(bus:GetAttribute("Capacity") or 1, 1)
	local load = passengers / capacity
	hud.passengersLabel.Text = string.format("Passengers %d / %d", passengers, capacity)
	hud.loadFill.Size = UDim2.fromScale(load, 1)
	hud.loadFill.BackgroundColor3 = Color3.fromRGB(120, 220, 140):Lerp(Color3.fromRGB(240, 90, 70), load)

	local health = bus:GetAttribute("Health") or 0
	local maxHealth = math.max(bus:GetAttribute("MaxHealth") or 1, 1)
	hud.healthFill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
	if bus:GetAttribute("BrokenDown") then
		hud.healthLabel.Text = "BROKEN DOWN — repairing..."
	else
		hud.healthLabel.Text = string.format("Health %d / %d", health, maxHealth)
	end

	if runState then
		hud.faresLabel.Text = formatCash(runState.fares)
		hud.streakLabel.Text = string.format(
			"Delivered %d · Collisions %d · Clean streak %d",
			runState.deliveries,
			runState.collisions,
			runState.cleanStreak
		)

		local root = bus.PrimaryPart
		local target = runState.drops[1]
		if root and target then
			local offset = target.position - root.Position
			local relative = root.CFrame:VectorToObjectSpace(offset)
			hud.dropArrow.Visible = true
			hud.dropArrow.Rotation = math.deg(math.atan2(relative.X, -relative.Z))
			local deadlineText = target.soonestDeadline > 0 and (formatTime(target.soonestDeadline) .. " left") or "late"
			hud.dropLabel.Text = string.format("Stop %d · %d pax · %d studs · %s", target.index, target.count, math.floor(offset.Magnitude), deadlineText)
		else
			hud.dropArrow.Visible = false
			hud.dropLabel.Text = "No passengers — stop at a bus stop to load"
		end
	end

	-- If throttle is held but the bus can't move, say why.
	if telemetry and telemetry.problem then
		hud.streakLabel.Text = "⚠ " .. telemetry.problem
		hud.streakLabel.TextColor3 = Color3.fromRGB(240, 160, 90)
	else
		hud.streakLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
		if not runState then
			hud.streakLabel.Text = ""
		end
	end
end)

-- Results ----------------------------------------------------------------------------------------------------

local resultsToken = 0
RunResults.OnClientEvent:Connect(function(results)
	local lines = {
		string.format("Fares collected: <b>%s</b>", formatCash(results.fares)),
		string.format("Passengers delivered: <b>%d</b> (%d on time)", results.deliveries, results.onTimeDeliveries),
		string.format("Collisions: <b>%d</b>   Best clean streak: <b>%d</b>", results.collisions, results.bestCleanStreak),
		string.format("Fares per minute: <b>%s</b>", formatCash(results.faresPerMinute)),
	}
	if results.cleanBonus > 0 then
		table.insert(lines, string.format("Clean-run bonus: <b>+%s</b>", formatCash(results.cleanBonus)))
	end
	if results.passengersLost > 0 then
		table.insert(lines, string.format("Passengers lost to breakdowns: <b>%d</b>", results.passengersLost))
	end
	table.insert(lines, string.format("Reputation: <b>+%d</b>   XP: <b>+%d</b>", results.reputation, results.xp))
	if results.levelAfter > results.levelBefore then
		table.insert(lines, string.format('<font color="#5aa0f0"><b>LEVEL UP! Level %d</b></font>', results.levelAfter))
	end
	if results.slotsAfter > results.slotsBefore then
		table.insert(lines, string.format('<font color="#fad23c"><b>%d new skill slots unlocked!</b></font>', results.slotsAfter - results.slotsBefore))
	end

	hud.resultsBody.Text = table.concat(lines, "\n")
	hud.resultsTotal.Text = "Total earned: " .. formatCash(results.cash)
	hud.resultsFrame.Visible = true

	resultsToken = resultsToken + 1
	local myToken = resultsToken
	task.delay(RouteConfig.ResultsSeconds, function()
		if resultsToken == myToken then
			hud.resultsFrame.Visible = false
		end
	end)
end)
