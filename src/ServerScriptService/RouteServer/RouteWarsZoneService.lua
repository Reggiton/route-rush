--[[
	RouteWarsZoneService.lua

	Watches a part named "RouteWarsZone" somewhere in Workspace (build it in
	Studio -- any size, shape, or orientation; it's checked as an oriented
	box, not necessarily axis-aligned). Standing inside it marks you Ready
	for the RouteWars loop, the same as ReadyService's button does for the
	regular one; stepping out clears it. Only touches WarReady while you are
	not already racing in EITHER loop -- once RouteWarsSession seats you in
	a war bus you're physically moved to the war track, nowhere near this
	part, so there's nothing left for the zone to watch for you until you're
	back in the lobby.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RouteWarsConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RouteWarsConfig)
local WarReadyService = require(script.Parent.WarReadyService)

local RouteWarsZoneService = {}

local inZone = {} -- [Player] = bool
local accumulator = 0
local warnedMissing = false

local function findZonePart()
	local part = workspace:FindFirstChild(RouteWarsConfig.ZoneName, true)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- Oriented box containment: transform the point into the part's local space
-- and compare against its half-size, so a rotated zone part works too.
local function isInside(part, position)
	local size = part.Size
	local local_ = part.CFrame:PointToObjectSpace(position)
	return math.abs(local_.X) <= size.X / 2
		and math.abs(local_.Y) <= size.Y / 2
		and math.abs(local_.Z) <= size.Z / 2
end

local function setInZone(player, value)
	if inZone[player] == value then
		return
	end
	inZone[player] = value
	-- Only auto-manage WarReady while the player is in neither loop's race;
	-- ignore transitions while they're actively racing (regular or war).
	if player:GetAttribute("InRace") then
		return
	end
	WarReadyService.SetReady(player, value)
end

local function step()
	local zonePart = findZonePart()
	if not zonePart then
		if not warnedMissing then
			warnedMissing = true
			warn(("RouteWarsZoneService: no part named '%s' found in Workspace. RouteWars will never fill until one exists."):format(RouteWarsConfig.ZoneName))
		end
		return
	end
	warnedMissing = false

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			setInZone(player, isInside(zonePart, root.Position))
		elseif inZone[player] then
			setInZone(player, false)
		end
	end
end

function RouteWarsZoneService.Start()
	RunService.Heartbeat:Connect(function(dt)
		accumulator = accumulator + dt
		if accumulator < RouteWarsConfig.ZoneCheckInterval then
			return
		end
		accumulator = 0
		step()
	end)
end

Players.PlayerRemoving:Connect(function(player)
	inZone[player] = nil
end)

return RouteWarsZoneService
