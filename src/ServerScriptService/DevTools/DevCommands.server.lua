--[[
	DevCommands.server.lua

	STUDIO ONLY chat commands for testing progression and the session
	loop. Does nothing in a live game.

	  /cash N     add N cash (negative to remove)
	  /rep N      add N reputation
	  /xp N       add N XP
	  /resetdata  wipe your profile back to defaults
	  /skip       end the current session phase now
]]

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local ServerSignals = require(ServerScriptService.Services.ServerSignals)

local function amountFrom(text)
	local number = tonumber(string.match(text, "%-?%d+"))
	return number and math.floor(number) or 0
end

local COMMANDS = {
	cash = function(player, text)
		PlayerDataService.Update(player, function(data)
			data.cash = data.cash + amountFrom(text)
		end)
	end,
	rep = function(player, text)
		PlayerDataService.Update(player, function(data)
			data.reputation = math.max(0, data.reputation + amountFrom(text))
		end)
	end,
	xp = function(player, text)
		PlayerDataService.Update(player, function(data)
			data.xp = math.max(0, data.xp + amountFrom(text))
		end)
	end,
	resetdata = function(player)
		PlayerDataService.ResetData(player)
	end,
	skip = function()
		ServerSignals.SkipPhase:Fire()
	end,
}

local function run(player, text)
	local name = string.match(text, "^/(%a+)")
	local handler = name and COMMANDS[string.lower(name)]
	if handler then
		handler(player, text)
		print(string.format("[DevCommands] %s ran %s", player.Name, text))
	end
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	for name in pairs(COMMANDS) do
		local command = Instance.new("TextChatCommand")
		command.Name = "Dev_" .. name
		command.PrimaryAlias = "/" .. name
		command.Parent = TextChatService
		command.Triggered:Connect(function(textSource, unfilteredText)
			local player = Players:GetPlayerByUserId(textSource.UserId)
			if player then
				run(player, unfilteredText)
			end
		end)
	end
else
	local function hook(player)
		player.Chatted:Connect(function(message)
			run(player, message)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
end

print("[DevCommands] Studio dev commands enabled: /cash N, /rep N, /xp N, /resetdata, /skip")
