--[[
	BusSpawner.lua

	Creates, seats, releases, resets, and removes each player's drivable
	bus for a route. Uses the same BusBuilder + BusUpgradeApplier as the
	garage, so a bus looks identical in both places.

	Bus attributes set here (read by the client controller, HUD, and
	server monitor):
	  OwnerUserId, TrackId, ChassisId, Lv_<Category>,
	  MaxHealth, Health, Capacity, Passengers, BrokenDown
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local UpgradeConfig = require(ReplicatedStorage.GarageSystem.Config.UpgradeConfig)
local BusBuilder = require(ReplicatedStorage.GarageSystem.Modules.BusBuilder)
local BusUpgradeApplier = require(ReplicatedStorage.GarageSystem.Modules.BusUpgradeApplier)
local BusStats = require(ReplicatedStorage.Shared.Modules.BusStats)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local BusSpawner = {}

-- [Player] = { bus, track, chassisId, levels, released, connections }
local records = {}

local function seatPlayer(player, record)
	local bus = record.bus
	if not bus.Parent then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = bus:FindFirstChild("DriverSeat")
	if not humanoid or humanoid.Health <= 0 or not seat then
		return
	end
	if seat.Occupant == humanoid then
		return
	end
	if seat.Occupant then
		seat.Occupant.Sit = false
	end
	humanoid.Sit = false
	character:PivotTo(seat.CFrame * CFrame.new(0, 2.5, 0))
	seat:Sit(humanoid)
end

-- Builds the player's bus on a grid slot, anchored, with them seated.
function BusSpawner.Spawn(player, track, slotIndex)
	local data = PlayerDataService.Get(player)
	if not data then
		return nil
	end
	BusSpawner.Despawn(player)

	local chassisId = data.selectedChassis
	local levels = {}
	for _, category in ipairs(UpgradeConfig.Categories) do
		levels[category] = data.chassis[chassisId].upgrades[category] or 0
	end
	local stats = BusStats.Compute(chassisId, levels, 0)

	local bus = BusBuilder.BuildBaseBus(chassisId, { anchored = true, withSeat = true })
	BusUpgradeApplier.ApplyState(bus, levels)
	bus.Name = "Bus_" .. player.UserId
	-- With StreamingEnabled, send the whole bus to clients at once so the
	-- driver never sees a bus without its Root.
	pcall(function()
		bus.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)

	for category, level in pairs(levels) do
		bus:SetAttribute("Lv_" .. category, level)
	end
	bus:SetAttribute("OwnerUserId", player.UserId)
	bus:SetAttribute("TrackId", track.id)
	bus:SetAttribute("MaxHealth", stats.maxHealth)
	bus:SetAttribute("Health", stats.maxHealth)
	bus:SetAttribute("Capacity", stats.capacity)
	bus:SetAttribute("Passengers", 0)
	bus:SetAttribute("BrokenDown", false)

	local ground = track.grid[slotIndex] or track.grid[#track.grid]
	bus:PivotTo(ground + Vector3.new(0, bus:GetAttribute("RootHeight"), 0))
	bus.Parent = track.busesFolder
	task.spawn(pcall, function()
		player:RequestStreamAroundAsync(ground.Position, 5)
	end)

	local record = {
		bus = bus,
		track = track,
		chassisId = chassisId,
		levels = levels,
		released = false,
		connections = {},
	}
	records[player] = record
	player:SetAttribute("InRace", true)

	seatPlayer(player, record)

	table.insert(record.connections, player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		task.wait(0.2)
		if records[player] == record then
			seatPlayer(player, record)
		end
	end))

	local seat = bus:FindFirstChild("DriverSeat")
	table.insert(record.connections, seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == nil then
			task.delay(0.6, function()
				if records[player] == record and seat.Occupant == nil then
					seatPlayer(player, record)
				end
			end)
		end
	end))

	return bus
end

-- GO: unanchor and hand physics to the driver's client.
function BusSpawner.Release(player)
	local record = records[player]
	if not record or not record.bus.Parent then
		return
	end
	BusBuilder.SetAnchored(record.bus, false)
	record.released = true

	local root = record.bus.PrimaryPart
	local canSet, reason = root:CanSetNetworkOwnership()
	if not canSet then
		warn("BusSpawner: can't give " .. player.Name .. " control of their bus: " .. tostring(reason))
		return
	end
	local ok, err = pcall(function()
		root:SetNetworkOwner(player)
	end)
	if not ok then
		warn("BusSpawner: could not give network ownership to " .. player.Name .. ": " .. tostring(err))
	end
end

-- Server takes the bus back, places it at a ground CFrame, then returns it.
function BusSpawner.ResetTo(player, groundCFrame)
	local record = records[player]
	if not record or not record.bus.Parent then
		return
	end
	local root = record.bus.PrimaryPart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	record.bus:PivotTo(groundCFrame + Vector3.new(0, record.bus:GetAttribute("RootHeight"), 0))
	seatPlayer(player, record)

	task.delay(1, function()
		if records[player] == record and record.released and root.Parent then
			pcall(function()
				root:SetNetworkOwner(player)
			end)
		end
	end)
end

function BusSpawner.GetRecord(player)
	return records[player]
end

function BusSpawner.GetBus(player)
	local record = records[player]
	return record and record.bus or nil
end

function BusSpawner.Despawn(player)
	local record = records[player]
	if not record then
		return
	end
	records[player] = nil
	player:SetAttribute("InRace", false)
	for _, connection in ipairs(record.connections) do
		connection:Disconnect()
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
	end
	record.bus:Destroy()
end

function BusSpawner.DespawnAll()
	for player in pairs(records) do
		BusSpawner.Despawn(player)
	end
end

-- Iterates { [Player] = record } (read-only).
function BusSpawner.All()
	return records
end

return BusSpawner
