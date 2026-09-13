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
<<<<<<< HEAD
	Up = 4,
=======
	Up = 0,
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
}

GarageLayoutConfig.Player = {
	Forward = 0,
	Right = 3,
<<<<<<< HEAD
	Up = 0,
=======
	Up = -7,
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
	FacingDegrees = 160,
}

GarageLayoutConfig.Bus = {
<<<<<<< HEAD
	Forward = 3,
	Right = -2,
=======
	Forward = 4,
	Right = -3,
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
	Up = -5,
	FacingDegrees = 150,
}

GarageLayoutConfig.Behind = {
	Forward = 40,
	Right = 0,
	Up = 0,
	FacingDegrees = 180,
}

<<<<<<< HEAD
-- Peak height (studs) of the display avatar's jump arc during the swap.
GarageLayoutConfig.JumpArcHeight = 6

return GarageLayoutConfig
=======
return GarageLayoutConfig
>>>>>>> 5ebfa8a40e59ed118b29d72e4a85019bc0f8a642
