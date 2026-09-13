--[[
	RemotesBootstrap.server.lua

<<<<<<< HEAD
	Creates every RemoteEvent in the game on server start, inside
	ReplicatedStorage.Remotes. Add a new remote's name to REMOTE_NAMES
	below and it exists everywhere else automatically (other scripts
	just WaitForChild it).
=======
	Creates every Garage RemoteEvent on server start. Add a new
	remote's name to REMOTE_NAMES below and it exists everywhere else
	automatically (other scripts just WaitForChild it).
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

<<<<<<< HEAD
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local REMOTE_NAMES = {
	-- Garage
	"OpenGarage",
	"CloseGarage",
	"GarageReady",
	"GarageClosed",
	"RequestSetLevel",
	"PendingLevelUpdated",
	"RequestSelectChassis",
	"ChassisPreviewUpdated",
	"RequestConfirm",
	"UpgradesConfirmed",
	"GarageError",

	-- Player data
	"ProfileUpdated",

	-- Route session
	"RequestBoard",
	"StopEvent",
	"RunStateUpdated",
	"RunResults",
=======
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
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
}

for _, remoteName in ipairs(REMOTE_NAMES) do
	if not Remotes:FindFirstChild(remoteName) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = Remotes
	end
<<<<<<< HEAD
end
=======
end
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
