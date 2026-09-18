--[[
	DevCommands.server.lua

	STUDIO ONLY chat commands for testing progression and the session
	loop. Does nothing in a live game.

	  /cash N     add N cash (negative to remove)
	  /rep N      add N reputation
	  /xp N       add N XP
	  /resetdata  wipe your profile back to defaults
	  /skip       end the current session phase now
	  /hp N       set your bus's health to N% (during a route)
	  /map ID     vote for a track layout (no argument lists the ids)
]]

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

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
	skip = function(player)
		-- Also readies you, so /skip in an empty lobby starts a race.
		local ReadyService = require(ServerScriptService.RouteServer.ReadyService)
		ReadyService.SetReady(player, true)
		ServerSignals.SkipPhase:Fire()
	end,
	map = function(player, text)
		-- Force the next race's layout. Testing a map alone is otherwise awkward:
		-- a one-player vote works, but this saves readying up to see each one.
		local TrackLayouts = require(ReplicatedStorage.Shared.Config.TrackLayouts)
		local MapVoteService = require(ServerScriptService.RouteServer.MapVoteService)
		local wanted = text:match("^/%a+%s+(%S+)")
		if not wanted or not TrackLayouts.Get(wanted) then
			local names = {}
			for _, layout in ipairs(TrackLayouts.List) do
				table.insert(names, layout.id)
			end
			Notify:FireClient(player, "Maps: " .. table.concat(names, ", "))
			return
		end
		MapVoteService.SetVote(player, wanted)
		Notify:FireClient(player, "Voted " .. TrackLayouts.Get(wanted).name)
	end,
	hp = function(player, text)
		-- Set your bus's health to N% (during a route) to preview damage effects.
		local BusSpawner = require(ServerScriptService.RouteServer.BusSpawner)
		local bus = BusSpawner.GetBus(player)
		if bus then
			local percent = math.clamp(amountFrom(text), 0, 100)
			bus:SetAttribute("Health", math.floor((bus:GetAttribute("MaxHealth") or 100) * percent / 100))
		end
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

print("[DevCommands] Studio dev commands enabled: /cash N, /rep N, /xp N, /resetdata, /skip, /hp N, /map ID")
