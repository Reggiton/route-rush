--[[
	WarClient.client.lua

	Client side of RouteWars: the war status pill, the Ready-for-war /
	Leave-war card, the Armory shop, the item hotbar, and the water-gun
	splash overlay. Runs alongside RouteClient.client.lua (regular racing)
	as an independent LocalScript; the two share the ProfileUpdated and
	Notify remotes but otherwise don't know about each other.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmoryConfig = require(Shared.Config.ArmoryConfig)

local UI = script.Parent.Parent:WaitForChild("UI")
local Format = require(UI:WaitForChild("Format"))

local WarHudBuilder = require(script.Parent.WarHudBuilder)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProfileUpdated = Remotes:WaitForChild("ProfileUpdated")
local RequestBuyArmoryItem = Remotes:WaitForChild("RequestBuyArmoryItem")
local RequestUseWarItem = Remotes:WaitForChild("RequestUseWarItem")
local WaterSplash = Remotes:WaitForChild("WaterSplash")

local hud = WarHudBuilder.Build(playerGui)

local snapshot -- last ProfileUpdated payload (cash, warInventory)
local armoryOpen = false

local function inWar()
	return player:GetAttribute("InWar") == true
end

-- Everything this HUD draws belongs to the war lobby, so it's only on
-- screen while you're standing in the RouteWars zone or racing a war.
local function warContext()
	return inWar() or player:GetAttribute("InWarZone") == true
end

-- Profile / inventory ------------------------------------------------------------------------------

ProfileUpdated.OnClientEvent:Connect(function(newSnapshot)
	snapshot = newSnapshot
	if armoryOpen then
		hud.armory.cash.Text = Format.Cash(snapshot.cash)
	end
	for itemId, row in pairs(hud.armory.items) do
		row.owned.Text = "Owned " .. tostring((snapshot.warInventory or {})[itemId] or 0)
	end
	for itemId, slot in pairs(hud.hotbar.slots) do
		slot.count.Text = tostring((snapshot.warInventory or {})[itemId] or 0)
	end
end)

-- Armory -----------------------------------------------------------------------------------------------

local function setArmoryOpen(open)
	armoryOpen = open
	hud.armory.panel.Visible = open
	if open and snapshot then
		hud.armory.cash.Text = Format.Cash(snapshot.cash)
	end
end

hud.armoryButton.MouseButton1Click:Connect(function()
	setArmoryOpen(not armoryOpen)
end)
hud.armory.closeButton.MouseButton1Click:Connect(function()
	setArmoryOpen(false)
end)

for itemId, row in pairs(hud.armory.items) do
	row.buyButton.MouseButton1Click:Connect(function()
		RequestBuyArmoryItem:FireServer(itemId, 1)
	end)
end

-- The shop is for kitting out before a war: in the zone, out of a race.
local function refreshArmoryButton()
	local available = warContext() and not player:GetAttribute("InRace")
	hud.armoryButton.Visible = available
	if not available then
		setArmoryOpen(false)
	end
end
player:GetAttributeChangedSignal("InRace"):Connect(refreshArmoryButton)
player:GetAttributeChangedSignal("InWar"):Connect(refreshArmoryButton)
player:GetAttributeChangedSignal("InWarZone"):Connect(refreshArmoryButton)
refreshArmoryButton()

-- Hotbar --------------------------------------------------------------------------------------------

local ITEM_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
}

local function useItem(itemId)
	if inWar() then
		RequestUseWarItem:FireServer(itemId)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	for index, keyCode in ipairs(ITEM_KEYS) do
		if input.KeyCode == keyCode then
			local item = ArmoryConfig.Items[index]
			if item then
				useItem(item.id)
			end
			return
		end
	end
end)

-- Water splash ---------------------------------------------------------------------------------------

local WIPE_SECONDS = 0.9
local splashUntil, splashDuration = 0, 0

local function wipe()
	if splashUntil <= os.clock() then
		return
	end
	splashUntil = math.max(os.clock(), splashUntil - WIPE_SECONDS)
end

hud.waterSplash.wipeButton.MouseButton1Down:Connect(wipe)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Space and splashUntil > os.clock() then
		wipe()
	end
end)

WaterSplash.OnClientEvent:Connect(function(payload)
	local seconds = tonumber(payload and payload.seconds) or 4
	splashDuration = seconds
	splashUntil = os.clock() + seconds
end)

-- Per-frame ------------------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	hud.hotbar.panel.Visible = inWar()

	-- Water splash overlay: decays on its own, wipes clear it faster.
	local now = os.clock()
	local remainingSplash = math.max(0, splashUntil - now)
	local fraction = splashDuration > 0 and math.clamp(remainingSplash / splashDuration, 0, 1) or 0
	local overlay = hud.waterSplash
	if fraction > 0 then
		overlay.overlay.Visible = true
		overlay.overlay.BackgroundTransparency = 1 - fraction * 0.5
		for _, drop in ipairs(overlay.droplets) do
			drop.BackgroundTransparency = 1 - fraction * 0.5
		end
	elseif overlay.overlay.Visible then
		overlay.overlay.Visible = false
	end
end)
