--[[
	WeaponService.lua

	RouteWars item effects: spike traps, trap mines, the goat horn, water
	buckets, and the water gun (ArmoryConfig). ArmoryService (buying) and
	this (using) both just spend/read a player's warInventory through
	PlayerDataService -- there's no separate "loadout" step.

	Two kinds of effect:
	  - Hazards (spikeTrap, mine) and zones (waterBucket) are dropped on the
	    road as a tracked table + one visible Part each. A single Heartbeat
	    loop (running only while a war round is live) checks every war
	    racer's position against them.
	  - Self (goatHorn) and ranged (waterGun) resolve immediately when used.

	Effects on OTHER buses are applied as attributes for BusDriveController
	to read and blend into ITS OWN simulation, rather than by pushing the
	physics body directly -- the client already owns that bus's physics via
	a LinearVelocity constraint every frame, which would simply overwrite a
	server-side impulse on the next step:
	  SlowMultiplier / SlowUntil            spike trap: topSpeed *= this
	  VeerBias / VeerUntil                  mine: added to the steer input
	  BoostSpeedMult / BoostAccelMult / BoostUntil   goat horn (self)
	  OnSlick / SlickGripMult               water bucket: grip *= this,
	                                         kept true only while standing
	                                         in an active puddle

	Only one war track is ever live at a time (RouteWarsConfig.TrackIndex),
	so this module tracks a single activeTrack rather than a table of them.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArmoryConfig = require(ReplicatedStorage.Shared.Config.ArmoryConfig)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local BusSpawner = require(script.Parent.BusSpawner)
local BusMonitor = require(script.Parent.BusMonitor)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestUseWarItem = Remotes:WaitForChild("RequestUseWarItem")
local StopEvent = Remotes:WaitForChild("StopEvent")
local WaterSplash = Remotes:WaitForChild("WaterSplash")
local Notify = Remotes:WaitForChild("Notify")

local SCAN_INTERVAL = 0.15
local HAZARD_COLOR = { spikeTrap = Color3.fromRGB(200, 60, 55), mine = Color3.fromRGB(70, 70, 78) }

local WeaponService = {}

local activeTrack -- the track table WeaponService.StartRound was given, or nil
local hazards = {} -- { item, ownerPlayer, position, part, expiresAt, hitPlayers = {[player]=untilClock} }
local zones = {} -- { item, ownerPlayer, position, part, expiresAt }
local lastUse = {} -- [Player] = { [itemId] = os.clock() }
local connection

-- Helpers -------------------------------------------------------------------------------------

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function groundPosition(record)
	local root = record.bus.PrimaryPart
	if not root then
		return nil
	end
	local rootHeight = record.bus:GetAttribute("RootHeight") or 0
	return root.Position - Vector3.new(0, rootHeight, 0)
end

local function weaponsFolder()
	local folder = activeTrack.folder:FindFirstChild("Weapons")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Weapons"
		folder.Parent = activeTrack.folder
	end
	return folder
end

local function makeMarker(name, position, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = CFrame.new(position + Vector3.new(0, size.Y / 2, 0))
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = weaponsFolder()
	return part
end

local function removeHazard(hazard)
	local index = table.find(hazards, hazard)
	if index then
		table.remove(hazards, index)
	end
	if hazard.part then
		hazard.part:Destroy()
	end
end

local function removeZone(zone)
	local index = table.find(zones, zone)
	if index then
		table.remove(zones, index)
	end
	if zone.part then
		zone.part:Destroy()
	end
end

-- Cooldown / inventory --------------------------------------------------------------------------

-- Returns the player's active-war bus record, or nil plus a toast reason
-- (nil reason = fail silently, e.g. spamming a key on cooldown).
local function canUse(player, item)
	if not activeTrack then
		return nil, "RouteWars isn't running right now."
	end
	local record = BusSpawner.GetRecord(player)
	if not record or record.track.id ~= activeTrack.id or not player:GetAttribute("InWar") then
		return nil, "You need to be racing in RouteWars to use items."
	end
	local data = PlayerDataService.Get(player)
	if not data or (data.warInventory[item.id] or 0) <= 0 then
		return nil, "You're out of " .. item.name .. ". Buy more at the Armory."
	end
	local now = os.clock()
	local cooldowns = lastUse[player]
	if cooldowns and cooldowns[item.id] and now - cooldowns[item.id] < item.cooldown then
		return nil, nil
	end
	return record
end

local function spend(player, item)
	lastUse[player] = lastUse[player] or {}
	lastUse[player][item.id] = os.clock()
	PlayerDataService.Update(player, function(data)
		data.warInventory[item.id] = math.max(0, (data.warInventory[item.id] or 0) - 1)
	end)
end

-- Effects -----------------------------------------------------------------------------------------

local function useHazard(player, record, item)
	local ground = groundPosition(record)
	local root = record.bus.PrimaryPart
	if not ground or not root then
		return
	end
	local behind = flat(-root.CFrame.LookVector)
	local position = ground + (behind.Magnitude > 0.01 and behind.Unit or -Vector3.zAxis) * 6

	local mine = {}
	for _, hazard in ipairs(hazards) do
		if hazard.ownerPlayer == player and hazard.item.id == item.id then
			table.insert(mine, hazard)
		end
	end
	table.sort(mine, function(a, b)
		return a.expiresAt < b.expiresAt
	end)
	while #mine >= item.maxActive do
		removeHazard(table.remove(mine, 1))
	end

	local size = item.id == "spikeTrap" and Vector3.new(5, 0.6, 5) or Vector3.new(2, 0.5, 2)
	local part = makeMarker(item.id, position, size, HAZARD_COLOR[item.id] or Color3.fromRGB(150, 150, 150), Enum.Material.Metal)

	table.insert(hazards, {
		item = item,
		ownerPlayer = player,
		position = position,
		part = part,
		expiresAt = os.clock() + item.lifetime,
		hitPlayers = {},
	})
	StopEvent:FireClient(player, { kind = "weaponUsed", item = item.id })
end

local function useSelf(player, record, item)
	local bus = record.bus
	local until_ = workspace:GetServerTimeNow() + item.duration
	bus:SetAttribute("BoostSpeedMult", item.speedMultiplier)
	bus:SetAttribute("BoostAccelMult", item.accelMultiplier)
	bus:SetAttribute("BoostUntil", until_)
	StopEvent:FireClient(player, { kind = "weaponUsed", item = item.id })
end

local function useZone(player, record, item)
	local ground = groundPosition(record)
	local root = record.bus.PrimaryPart
	if not ground or not root then
		return
	end
	local ahead = flat(root.CFrame.LookVector)
	local position = ground + (ahead.Magnitude > 0.01 and ahead.Unit or Vector3.zAxis) * 10

	local mine = {}
	for _, zone in ipairs(zones) do
		if zone.ownerPlayer == player then
			table.insert(mine, zone)
		end
	end
	table.sort(mine, function(a, b)
		return a.expiresAt < b.expiresAt
	end)
	while #mine >= item.maxActive do
		removeZone(table.remove(mine, 1))
	end

	local size = Vector3.new(item.radius * 1.6, 0.2, item.radius * 1.6)
	local part = makeMarker(item.id, position, size, Color3.fromRGB(80, 150, 230), Enum.Material.Ice)
	part.Transparency = 0.25

	table.insert(zones, {
		item = item,
		ownerPlayer = player,
		position = position,
		part = part,
		expiresAt = os.clock() + item.lifetime,
	})
	StopEvent:FireClient(player, { kind = "weaponUsed", item = item.id })
end

local function useRanged(player, record, item)
	local root = record.bus.PrimaryPart
	if not root then
		return
	end
	local forward = flat(root.CFrame.LookVector)
	forward = forward.Magnitude > 0.01 and forward.Unit or -Vector3.zAxis
	local myPosition = root.Position

	local bestPlayer, bestDistance
	for otherPlayer, otherRecord in pairs(BusSpawner.All()) do
		if otherPlayer ~= player and otherRecord.track.id == activeTrack.id then
			local otherRoot = otherRecord.bus.PrimaryPart
			if otherRoot then
				local offset = flat(otherRoot.Position - myPosition)
				local distance = offset.Magnitude
				if distance > 0.1 and distance <= item.range then
					local angle = math.deg(math.acos(math.clamp(offset.Unit:Dot(forward), -1, 1)))
					if angle <= item.coneDegrees and (not bestDistance or distance < bestDistance) then
						bestPlayer, bestDistance = otherPlayer, distance
					end
				end
			end
		end
	end

	if not bestPlayer then
		Notify:FireClient(player, "No one in range.")
		return
	end
	WaterSplash:FireClient(bestPlayer, { seconds = item.splashSeconds })
	StopEvent:FireClient(player, { kind = "weaponUsed", item = item.id })
	StopEvent:FireClient(bestPlayer, { kind = "splashed" })
end

-- Hazard/zone trigger scan -------------------------------------------------------------------------

local function triggerHazard(hazard, victimPlayer, record)
	local item = hazard.item
	hazard.hitPlayers[victimPlayer] = os.clock() + (item.perVictimCooldown or item.lifetime)
	BusMonitor.ApplyDamage(victimPlayer, item.damage)

	local bus = record.bus
	local now = workspace:GetServerTimeNow()
	if item.id == "spikeTrap" then
		bus:SetAttribute("SlowMultiplier", item.slowMultiplier)
		bus:SetAttribute("SlowUntil", now + item.slowSeconds)
	elseif item.id == "mine" then
		bus:SetAttribute("VeerBias", (math.random() < 0.5 and -1 or 1) * 0.8)
		bus:SetAttribute("VeerUntil", now + item.veerSeconds)
	end
	StopEvent:FireClient(victimPlayer, { kind = "weaponHit", item = item.id, damage = item.damage })

	if item.singleUse then
		removeHazard(hazard)
	end
end

local function scan()
	local now = os.clock()

	for i = #hazards, 1, -1 do
		if now >= hazards[i].expiresAt then
			removeHazard(hazards[i])
		end
	end
	for i = #zones, 1, -1 do
		if now >= zones[i].expiresAt then
			removeZone(zones[i])
		end
	end

	if not activeTrack then
		return
	end

	-- Who's actually on the war track right now, once, for both passes below.
	local racers = {}
	for player, record in pairs(BusSpawner.All()) do
		if record.released and record.track.id == activeTrack.id and record.bus.PrimaryPart then
			racers[player] = record
		end
	end

	for _, hazard in ipairs(hazards) do
		for victimPlayer, record in pairs(racers) do
			if victimPlayer ~= hazard.ownerPlayer then
				local root = record.bus.PrimaryPart
				local distance = flat(root.Position - hazard.position).Magnitude
				if distance <= hazard.item.triggerRadius then
					local cooldownUntil = hazard.hitPlayers[victimPlayer]
					if not cooldownUntil or now >= cooldownUntil then
						triggerHazard(hazard, victimPlayer, record)
					end
				end
			end
		end
	end

	for player, record in pairs(racers) do
		local root = record.bus.PrimaryPart
		local onSlick, gripMult = false, 1
		for _, zone in ipairs(zones) do
			local distance = flat(root.Position - zone.position).Magnitude
			if distance <= zone.item.radius then
				onSlick = true
				gripMult = math.min(gripMult, zone.item.gripMultiplier)
			end
		end
		if record.bus:GetAttribute("OnSlick") ~= onSlick then
			record.bus:SetAttribute("OnSlick", onSlick)
		end
		if onSlick then
			record.bus:SetAttribute("SlickGripMult", gripMult)
		end
	end
end

-- Round lifecycle -----------------------------------------------------------------------------------

function WeaponService.StartRound(track)
	activeTrack = track
	lastUse = {}
	if not connection then
		local accumulator = 0
		connection = RunService.Heartbeat:Connect(function(dt)
			accumulator = accumulator + dt
			if accumulator < SCAN_INTERVAL then
				return
			end
			accumulator = 0
			scan()
		end)
	end
end

function WeaponService.EndRound()
	activeTrack = nil
	for i = #hazards, 1, -1 do
		removeHazard(hazards[i])
	end
	for i = #zones, 1, -1 do
		removeZone(zones[i])
	end
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

function WeaponService.RemovePlayer(player)
	lastUse[player] = nil
	for i = #hazards, 1, -1 do
		if hazards[i].ownerPlayer == player then
			removeHazard(hazards[i])
		end
	end
	for i = #zones, 1, -1 do
		if zones[i].ownerPlayer == player then
			removeZone(zones[i])
		end
	end
end

RequestUseWarItem.OnServerEvent:Connect(function(player, itemId)
	if type(itemId) ~= "string" then
		return
	end
	local item = ArmoryConfig.Get(itemId)
	if not item then
		return
	end
	local record, reason = canUse(player, item)
	if not record then
		if reason then
			Notify:FireClient(player, reason)
		end
		return
	end

	spend(player, item)
	if item.kind == "hazard" then
		useHazard(player, record, item)
	elseif item.kind == "self" then
		useSelf(player, record, item)
	elseif item.kind == "zone" then
		useZone(player, record, item)
	elseif item.kind == "ranged" then
		useRanged(player, record, item)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	WeaponService.RemovePlayer(player)
end)

return WeaponService
