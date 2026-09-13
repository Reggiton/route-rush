--[[
	LobbyBuilder.lua

	Makes sure there is somewhere for players to stand between routes.
	Uses, in order:
	  1. a Model/Folder named "Lobby" in Workspace (with a SpawnLocation inside)
	  2. any SpawnLocation already in Workspace (e.g. the default baseplate place)
	  3. a generated placeholder platform + SpawnLocation at the origin
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RouteConfig = require(ReplicatedStorage.Shared.Config.RouteConfig)

local LobbyBuilder = {}

local spawnLocation

local function findSpawn(container)
	for _, item in ipairs(container:GetDescendants()) do
		if item:IsA("SpawnLocation") then
			return item
		end
	end
	return nil
end

local function buildPlaceholder()
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"

	local size = RouteConfig.LobbySize
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(size, 2, size)
	floor.CFrame = CFrame.new(0, RouteConfig.LobbyHeight - 1, 0)
	floor.Material = Enum.Material.Concrete
	floor.Color = Color3.fromRGB(120, 120, 125)
	floor.Parent = folder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, RouteConfig.LobbyHeight + 0.5, 0)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = folder

	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.Size = Vector3.new(30, 10, 1)
	sign.CFrame = CFrame.new(0, RouteConfig.LobbyHeight + 8, -size / 2 + 6)
	sign.Color = Color3.fromRGB(230, 170, 40)
	sign.Parent = folder

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back
	surface.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "ROUTE RUSH"
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = Color3.fromRGB(30, 30, 30)
	text.Parent = surface

	folder.Parent = workspace
	return spawn
end

function LobbyBuilder.Ensure()
	if spawnLocation and spawnLocation.Parent then
		return spawnLocation
	end
	local lobby = workspace:FindFirstChild("Lobby")
	spawnLocation = (lobby and findSpawn(lobby)) or findSpawn(workspace) or buildPlaceholder()
	return spawnLocation
end

-- Respawns the player at the lobby (also clears any seat/vehicle state).
function LobbyBuilder.SendToLobby(player)
	LobbyBuilder.Ensure()
	if player.Parent == Players then
		player:LoadCharacter()
	end
end

return LobbyBuilder
