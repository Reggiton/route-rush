--[[
	ArmoryService.server.lua

	Handles buying RouteWars items with cash. There's no "open/close" scene
	like the Garage -- the shop is just a list backed by ArmoryConfig, and
	the client already gets cash + warInventory on every ProfileUpdated
	(PlayerDataService.Snapshot), so a purchase only needs one remote in and
	the existing ProfileUpdated reply to confirm it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArmoryConfig = require(ReplicatedStorage.Shared.Config.ArmoryConfig)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestBuyArmoryItem = Remotes:WaitForChild("RequestBuyArmoryItem")
local Notify = Remotes:WaitForChild("Notify")

local PURCHASE_COOLDOWN = 0.2
local lastPurchase = {}

RequestBuyArmoryItem.OnServerEvent:Connect(function(player, itemId, quantity)
	if type(itemId) ~= "string" then
		return
	end
	quantity = math.clamp(math.floor(tonumber(quantity) or 1), 1, 20)

	local item = ArmoryConfig.Get(itemId)
	local data = PlayerDataService.Get(player)
	if not item or not data then
		return
	end

	local now = os.clock()
	if lastPurchase[player] and now - lastPurchase[player] < PURCHASE_COOLDOWN then
		return
	end
	lastPurchase[player] = now

	local cost = item.price * quantity
	if data.cash < cost then
		Notify:FireClient(player, "Not enough cash for " .. quantity .. "x " .. item.name .. ".")
		return
	end

	PlayerDataService.Update(player, function(mutable)
		mutable.cash = mutable.cash - cost
		mutable.warInventory[item.id] = (mutable.warInventory[item.id] or 0) + quantity
	end)
	Notify:FireClient(player, string.format("Bought %dx %s.", quantity, item.name))
end)

Players.PlayerRemoving:Connect(function(player)
	lastPurchase[player] = nil
end)
