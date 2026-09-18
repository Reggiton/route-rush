--[[
	GarageLayoutConfig.lua

	Every number here is in studs (Forward/Right/Up) plus a facing
	angle in degrees (FacingDegrees), measured from ONE shared origin
	point for the stall. Camera, Player, Bus, and Behind are each
	independent -- moving one never moves the others.

	The garage is a showroom: one parking spot per chassis tier, laid out
	in a row along the anchor's Right axis. The offsets below describe
	SPOT 1; every other spot is the same arrangement shifted sideways by
	SpotSpacing, so the bus, the avatar and the camera all keep their
	tuned relationship in every bay.
]]

local GarageLayoutConfig = {}

-- Studs between the centres of neighbouring parking spots, along the
-- anchor's Right axis. Negative lays the row out the other way.
GarageLayoutConfig.SpotSpacing = 31

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
	Forward = 8,
	Right = 7,
	Up = -10,
	FacingDegrees = 160,
}

-- Up is the GARAGE FLOOR, not the bus's centre: the model is placed with its
-- lowest point resting on this plane (GarageLayout.GroundModel), so every bus
-- sits on the ground whatever its height. Raise or lower this one number to
-- move the floor; no bus ever needs its own offset.
GarageLayoutConfig.Bus = {
	Forward = 13,
	Right = 1,
	Up = -13,
	FacingDegrees = 155,
}

GarageLayoutConfig.Behind = {
	Forward = 40,
	Right = 0,
	Up = 0,
	FacingDegrees = 180,
}

-- Seconds for the camera (and the avatar) to travel between parking spots.
GarageLayoutConfig.SpotPanTime = 0.55

-- Peak height (studs) of the display avatar's jump arc during the swap.
GarageLayoutConfig.JumpArcHeight = 6

return GarageLayoutConfig
