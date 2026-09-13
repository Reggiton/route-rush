--[[
	DrivingConfig.lua

	How upgrades and passenger load change a bus's driving stats, plus
	the arcade controller and collision constants. Base stats per
	chassis live in UpgradeConfig.ChassisTiers. The math lives in
	BusStats.lua (stats), BusDriveController.lua (client physics), and
	BusMonitor.lua (server collisions).
]]

local DrivingConfig = {}

-- Fractional gain per upgrade level (Lv9 Engine = +40.5% top speed, etc.)
DrivingConfig.PerLevel = {
	Engine = { topSpeed = 0.045 },
	Accel = { accel = 0.06 },
	Brakes = { brakeDecel = 0.06 },
	-- Handles: cornering + capacity. Lv9 = 2x base capacity (spreadsheet
	-- "double-capacity"); each level also shaves the load grip penalty.
	Handles = { grip = 0.04, capacity = 1 / 9, loadPenaltyReduction = 0.05 },
	Health = { maxHealth = 0.1, damageReduction = 0.05 },
}

-- Penalty at 100% load (full capacity). Scales linearly with load.
DrivingConfig.LoadPenalty = {
	topSpeed = 0.15,
	accel = 0.35,
	brakeDecel = 0.30,
	grip = 0.40,
	turnRate = 0.20,
}

-- Arcade controller -------------------------------------------------------------
DrivingConfig.Controller = {
	ReverseSpeedFraction = 0.3, -- reverse top speed as a fraction of topSpeed
	CoastDecel = 8, -- studs/s^2 when no throttle
	HandbrakeDecel = 30, -- studs/s^2 while handbraking
	HandbrakeGripFactor = 0.45, -- grip multiplier while handbraking
	FullSteerSpeed = 25, -- below this speed steering scales down to 0
	HighSpeedSteerFactor = 0.55, -- turn rate multiplier at top speed
	SlideGripFactor = 0.35, -- grip multiplier once the bus breaks traction
	GripRecoverTime = 0.6, -- seconds of calm driving to regain traction
	LateralDamping = 6, -- how fast sideways velocity is killed while gripping
	GroundRayLength = 12, -- studs below the root to look for ground
	BodyRollMaxDegrees = 6,
	AlignResponsiveness = 14,
	DriveForcePerMass = 150, -- horizontal force limit = assembly mass * this
	HoverStiffness = 10, -- vertical correction toward ride height
	MaxAlignTorque = 4e7,
	HeadingResyncDegrees = 30, -- re-sync steering heading after a knock
}

-- Server-side collision & sanity --------------------------------------------------
DrivingConfig.Collision = {
	SampleInterval = 0.1, -- seconds between velocity samples
	ImpactMinDrop = 14, -- studs/s drop in one sample (beyond braking) to count
	BrakeSlack = 1.6, -- allowed drop = brakeDecel * interval * BrakeSlack
	DamagePerStudPerSecond = 1.5, -- damage per studs/s of excess drop
	ImpactCooldown = 0.6, -- seconds before another impact can register
	BreakdownSeconds = 5,
	BreakdownPassengerLoss = 0.25, -- fraction of onboard passengers lost
	BreakdownRepairFraction = 0.5, -- health restored after a breakdown
	SpeedTolerance = 1.3, -- flag above topSpeed * this
	SpeedStrikesToReset = 8, -- consecutive samples over tolerance before reset
	MaxTeleportStuds = 60, -- per sample, beyond expected travel
	FallResetY = -80, -- relative to the track; reset if below
	FlipResetSeconds = 3, -- reset if on its side/roof this long
}

return DrivingConfig
