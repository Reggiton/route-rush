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
	Up = 4,
}

GarageLayoutConfig.Player = {
	Forward = 0,
	Right = 3,
	Up = 0,
	FacingDegrees = 160,
}

-- Up is the GARAGE FLOOR, not the bus's centre: the model is placed with its
-- lowest point resting on this plane (GarageLayout.GroundModel), so every bus
-- sits on the ground whatever its height. Raise or lower this one number to
-- move the floor; no bus ever needs its own offset.
GarageLayoutConfig.Bus = {
	Forward = 3,
	Right = -2,
	Up = -10,
	FacingDegrees = 150,
}

GarageLayoutConfig.Behind = {
	Forward = 40,
	Right = 0,
	Up = 0,
	FacingDegrees = 180,
}

-- Peak height (studs) of the display avatar's jump arc during the swap.
GarageLayoutConfig.JumpArcHeight = 6

return GarageLayoutConfig
