--[[
	RemotesBootstrap.server.lua

	Creates every Garage RemoteEvent on server start. Add a new
	remote's name to REMOTE_NAMES below and it exists everywhere else
	automatically (other scripts just WaitForChild it).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GarageSystem = ReplicatedStorage:FindFirstChild("GarageSystem")
if not GarageSystem then
	GarageSystem = Instance.new("Folder")
	GarageSystem.Name = "GarageSystem"
	GarageSystem.Parent = ReplicatedStorage
end

local Remotes = GarageSystem:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = GarageSystem
end

local REMOTE_NAMES = {
	"OpenGarage",
	"GarageReady",
	"RequestSetLevel",
	"PendingLevelUpdated",
	"RequestConfirm",
	"UpgradesConfirmed",
}

for _, remoteName in ipairs(REMOTE_NAMES) do
	if not Remotes:FindFirstChild(remoteName) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = Remotes
	end
end