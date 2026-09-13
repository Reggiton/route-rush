--[[
	GarageLayoutConfig.lua

	Every number here is in studs (Forward/Right/Up) plus a facing
	angle in degrees (FacingDegrees), measured from ONE shared origin
	point for the stall. Camera, Player, Bus, and Behind are each
	independent -- moving one never moves the others.
]]

local GarageLayoutConfig = {}

GarageLayoutConfig.Camera = {
	Forward = -16,
	Right = 5,
	Up = -7,
}

GarageLayoutConfig.CameraAim = {
	Forward = 12,
	Right = 0,
	Up = 0,
}

GarageLayoutConfig.Player = {
	Forward = 0,
	Right = 3,
	Up = -7,
	FacingDegrees = 160,
}

GarageLayoutConfig.Bus = {
	Forward = 4,
	Right = -3,
	Up = -5,
	FacingDegrees = 150,
}

GarageLayoutConfig.Behind = {
	Forward = 40,
	Right = 0,
	Up = 0,
	FacingDegrees = 180,
}

return GarageLayoutConfig