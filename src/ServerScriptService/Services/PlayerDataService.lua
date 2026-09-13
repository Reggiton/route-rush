--[[
	PlayerDataService.lua

	Owns every player's persistent profile: cash, reputation, XP, owned
	chassis, and per-chassis upgrade levels. Sets itself up the first
	time any server script requires it.

	RULES
	  - Read with Get(player). Treat the returned table as read-only.
	  - Change data ONLY through Update(player, fn). fn receives the live
	    data table and must not yield. After it runs, leaderstats, the
	    client snapshot (ProfileUpdated remote), and the Changed signal
	    all refresh automatically.

	SAVING
	  - DataStore: RouteRushPlayerData_v1, key "u_<userId>".
	  - A session lock is written into the record so two servers can't
	    both own the same profile. A lock older than LOCK_STALE_SECONDS
	    is treated as abandoned.
	  - Autosaves every AUTOSAVE_INTERVAL seconds, on leave, and on
	    shutdown.
	  - If DataStores are unreachable (e.g. Studio without "Enable Studio
	    Access to API Services"), the player gets a working profile that
	    simply doesn't save, plus a warning in Output.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.GarageSystem.Config.UpgradeConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Progression = require(ReplicatedStorage.Shared.Modules.Progression)
local PowerScore = require(ReplicatedStorage.Shared.Modules.PowerScore)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProfileUpdated = Remotes:WaitForChild("ProfileUpdated")

local DATASTORE_NAME = "RouteRushPlayerData_v1"
local SCHEMA_VERSION = 1
local AUTOSAVE_INTERVAL = 120
local LOCK_STALE_SECONDS = 15 * 60
local LOAD_ATTEMPTS = 5
local SAVE_ATTEMPTS = 3

local SESSION_ID = HttpService:GenerateGUID(false)

local PlayerDataService = {}

-- (player, data) after any Update or load
PlayerDataService.Changed = Instance.new("BindableEvent")

local profiles = {} -- [Player] = { data = table, canSave = bool }

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("PlayerDataService: DataStores unavailable, progress will NOT save this session:", result)
	end
end

-- Helpers ---------------------------------------------------------------------------

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function defaultData()
	local chassis = {}
	for _, tier in ipairs(UpgradeConfig.ChassisTiers) do
		local upgrades = {}
		for _, category in ipairs(UpgradeConfig.Categories) do
			upgrades[category] = 0
		end
		chassis[tier.id] = {
			owned = tier.price <= 0 or tier.id == UpgradeConfig.DefaultChassisId,
			upgrades = upgrades,
		}
	end

	return {
		version = SCHEMA_VERSION,
		cash = EconomyConfig.StartingCash,
		reputation = 0,
		xp = 0,
		selectedChassis = UpgradeConfig.DefaultChassisId,
		chassis = chassis,
		stats = {
			runs = 0,
			bestFaresPerMin = 0,
			bestCleanStreak = 0,
		},
	}
end

-- Fills in anything missing (new tiers/categories added since last save)
-- and clamps values that config changes may have invalidated.
local function reconcile(data)
	local function fill(target, template)
		for k, v in pairs(template) do
			if target[k] == nil then
				target[k] = deepCopy(v)
			elseif type(v) == "table" and type(target[k]) == "table" then
				fill(target[k], v)
			end
		end
	end
	fill(data, defaultData())

	for _, entry in pairs(data.chassis) do
		for category, level in pairs(entry.upgrades) do
			entry.upgrades[category] = math.clamp(math.floor(tonumber(level) or 0), UpgradeConfig.MinLevel, UpgradeConfig.MaxLevel)
		end
	end
	if not UpgradeConfig.GetChassis(data.selectedChassis) or not data.chassis[data.selectedChassis].owned then
		data.selectedChassis = UpgradeConfig.DefaultChassisId
	end
	data.cash = math.max(0, math.floor(data.cash))
	data.version = SCHEMA_VERSION
	data.lock = nil
	return data
end

local function isNoAccessError(message)
	message = tostring(message)
	return string.find(message, "403") ~= nil
		or string.find(message, "Studio") ~= nil
		or string.find(message, "API Services") ~= nil
end

local function keyFor(player)
	return "u_" .. player.UserId
end

-- Load / save ---------------------------------------------------------------------------

-- Returns data, canSave, kickReason
local function loadAsync(player)
	if not store then
		return reconcile(defaultData()), false, nil
	end

	local lockedByOther = false
	for attempt = 1, LOAD_ATTEMPTS do
		local loaded
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old)
				local now = os.time()
				if old and old.lock and old.lock.session ~= SESSION_ID and now - (old.lock.time or 0) < LOCK_STALE_SECONDS then
					lockedByOther = true
					return nil -- leave the record alone
				end
				lockedByOther = false
				local data = old or defaultData()
				data.lock = { session = SESSION_ID, time = now }
				loaded = data
				return data
			end)
		end)

		if ok and loaded then
			return reconcile(deepCopy(loaded)), true, nil
		end
		if not ok then
			warn(string.format("PlayerDataService: load attempt %d for %s failed: %s", attempt, player.Name, tostring(err)))
			if isNoAccessError(err) then
				return reconcile(defaultData()), false, nil
			end
		end
		if player.Parent == nil then
			return nil, false, nil
		end
		task.wait(math.min(2 * attempt, 6))
	end

	if lockedByOther then
		return nil, false, "Your progress is still being saved by another server. Please rejoin in a moment."
	end

	warn("PlayerDataService: could not load " .. player.Name .. "; using a temporary profile that will NOT save.")
	return reconcile(defaultData()), false, nil
end

local function saveAsync(player, profile, releaseLock)
	if not store or not profile.canSave then
		return
	end

	local snapshot = deepCopy(profile.data)
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old)
				if old and old.lock and old.lock.session ~= SESSION_ID then
					-- Another server took the profile over (our lock went stale).
					return nil
				end
				snapshot.lock = (not releaseLock) and { session = SESSION_ID, time = os.time() } or nil
				return snapshot
			end)
		end)
		if ok then
			return
		end
		warn(string.format("PlayerDataService: save attempt %d for %s failed: %s", attempt, player.Name, tostring(err)))
		task.wait(attempt)
	end
end

-- Leaderstats + snapshot ------------------------------------------------------------------

local function ensureLeaderstats(player)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	for _, statName in ipairs({ "Cash", "Level", "Rep" }) do
		if not folder:FindFirstChild(statName) then
			local value = Instance.new("IntValue")
			value.Name = statName
			value.Parent = folder
		end
	end
	return folder
end

function PlayerDataService.Snapshot(player)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local data = profile.data
	local level, xpIntoLevel, xpForNext = Progression.LevelFromXP(data.xp)
	local selected = data.chassis[data.selectedChassis]
	local score = PowerScore.Driving(data.selectedChassis, selected.upgrades)

	return {
		cash = data.cash,
		reputation = data.reputation,
		xp = data.xp,
		level = level,
		xpIntoLevel = xpIntoLevel,
		xpForNext = xpForNext,
		selectedChassis = data.selectedChassis,
		chassis = deepCopy(data.chassis),
		unlockedSlots = Progression.UnlockedSlots(data.reputation),
		nextUnlockReputation = Progression.NextUnlockReputation(data.reputation),
		slotsUsed = Progression.SlotsUsed(selected.upgrades),
		powerScore = score,
		bracket = PowerScore.Bracket(score),
		stats = deepCopy(data.stats),
		saving = profile.canSave,
	}
end

local function publish(player)
	local profile = profiles[player]
	if not profile or player.Parent == nil then
		return
	end
	local data = profile.data
	local folder = ensureLeaderstats(player)
	folder.Cash.Value = data.cash
	folder.Level.Value = (Progression.LevelFromXP(data.xp))
	folder.Rep.Value = data.reputation

	ProfileUpdated:FireClient(player, PlayerDataService.Snapshot(player))
	PlayerDataService.Changed:Fire(player, data)
end

-- Public API -------------------------------------------------------------------------------

function PlayerDataService.Get(player)
	local profile = profiles[player]
	return profile and profile.data or nil
end

-- Yields until the profile is loaded. Returns nil if the player left first.
function PlayerDataService.WaitForProfile(player)
	while not profiles[player] and player.Parent ~= nil do
		task.wait(0.1)
	end
	return PlayerDataService.Get(player)
end

-- fn(data) mutates the live profile. Must not yield. Returns true if applied.
function PlayerDataService.Update(player, fn)
	local profile = profiles[player]
	if not profile then
		return false
	end
	fn(profile.data)
	profile.data.cash = math.max(0, math.floor(profile.data.cash))
	publish(player)
	return true
end

function PlayerDataService.PushSnapshot(player)
	publish(player)
end

function PlayerDataService.ResetData(player)
	return PlayerDataService.Update(player, function(data)
		local fresh = defaultData()
		for k in pairs(data) do
			data[k] = nil
		end
		for k, v in pairs(fresh) do
			data[k] = v
		end
	end)
end

-- Lifecycle ----------------------------------------------------------------------------------

local function onPlayerAdded(player)
	ensureLeaderstats(player)

	local data, canSave, kickReason = loadAsync(player)
	if kickReason then
		player:Kick(kickReason)
		return
	end
	if not data then
		return -- left while loading
	end

	local profile = { data = data, canSave = canSave }
	if player.Parent == nil then
		-- Left mid-load: release the lock we just took.
		task.spawn(saveAsync, player, profile, true)
		return
	end

	profiles[player] = profile
	publish(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	if profile then
		profiles[player] = nil
		saveAsync(player, profile, true)
	end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player, profile in pairs(profiles) do
			task.spawn(saveAsync, player, profile, false)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player, profile in pairs(profiles) do
		pending = pending + 1
		task.spawn(function()
			saveAsync(player, profile, true)
			pending = pending - 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)

return PlayerDataService
