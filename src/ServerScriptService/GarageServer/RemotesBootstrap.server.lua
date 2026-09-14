--[[
	RemotesBootstrap.server.lua

	Creates every RemoteEvent in the game on server start, inside
	ReplicatedStorage.Remotes. Add a new remote's name to REMOTE_NAMES
	below and it exists everywhere else automatically (other scripts
	just WaitForChild it).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	"SetReady",
	"SetMapVote",
	"Notify",
}

for _, remoteName in ipairs(REMOTE_NAMES) do
	if not Remotes:FindFirstChild(remoteName) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = Remotes
	end
end
