--[[
	RouteWarsZoneService.lua

	Watches a part named "RouteWarsZone" somewhere in Workspace (build it in
	Studio -- any size, shape, or orientation; it's checked as an oriented
	box, not necessarily axis-aligned).

	Standing inside it switches you to the RouteWars lobby: the attribute
	"InWarZone" is what the HUD reads to decide whether to show the war
	lobby (ready-up + map vote for the war loop) or the regular one. It is
	NOT readiness -- you still press Ready, exactly as in the regular lobby.
	The two lobbies are exclusive: crossing the boundary drops your
	readiness for the one you left, so neither loop can pull you into a
	race out of a lobby you're no longer looking at.

	Only touched while you are not already racing in EITHER loop -- once
	RouteWarsSession seats you in a war bus you're physically moved to the
	war track, nowhere near this part, and "InWar" takes over for the HUD.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RouteWarsConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RouteWarsConfig)
local ReadyService = require(script.Parent.ReadyService)
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
	inZone[player] = value
	-- Ignore this while they're actively racing (regular or war): being
	-- seated on a track moves them away from the part, which isn't a
	-- decision to leave the war lobby.
	if player:GetAttribute("InRace") then
		return
	end
	-- Reconciled every tick rather than only on a transition: a race ends
	-- with the player back in the lobby but the attribute still set from
	-- before it started, and nothing else would clear it.
	if player:GetAttribute("InWarZone") ~= value then
		player:SetAttribute("InWarZone", value)
	end
	-- The two lobbies are exclusive, so readiness for the one you just left
	-- is dropped either way -- otherwise that loop would yank you into a
	-- race out of the lobby you're no longer looking at. Both SetReady
	-- calls no-op when the value is already false.
	if value then
		ReadyService.SetReady(player, false)
	else
		WarReadyService.SetReady(player, false)
	end
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
