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
-- A full bus should feel like a boat: slow to wind up, late to stop, and
-- unwilling to change direction. Grip on its own is hard to feel (it only
-- bites at the moment traction breaks), so the turn rate and the steering
-- lag below carry most of the weight.
DrivingConfig.LoadPenalty = {
	topSpeed = 0.18,
	accel = 0.45,
	brakeDecel = 0.38,
	grip = 0.55,
	turnRate = 0.35,
	-- Seconds for the steering to catch up to your input at full load.
	-- At zero load steering is instant, so this is the main thing that
	-- makes a loaded bus feel heavy rather than just slow.
	steerLag = 0.28,
}

-- Engine strain ----------------------------------------------------------------------
-- Holding near your top speed cooks the engine: strain climbs while you're
-- above ThresholdFraction of top speed and bleeds off below it. At 1 the
-- bus breaks down. The Engine upgrade raises top speed, so it also raises
-- the speed you can hold before the needle starts climbing at all.
--
-- Published on the bus as the "Strain" attribute, which drives the red
-- vignette and the screen shake (DriverScreenEffects.client.lua).
DrivingConfig.Strain = {
	ThresholdFraction = 0.85,
	RisePerSecond = 0.13, -- ~8s flat out from cold to a breakdown
	FallPerSecond = 0.38, -- backing off recovers faster than pushing builds
	WarnAt = 0.4, -- vignette starts creeping in here
	ShakeAt = 0.72, -- and the screen starts shaking here
	AfterBreakdown = 0.5, -- strain left over after a strain breakdown
}

-- Post-breakdown impairment ------------------------------------------------------------
-- A breakdown used to be a flat time tax with no consequence once you were
-- rolling again. Now one system limps afterwards and recovers over
-- Seconds, so there's a reason to drive carefully on the way home --
-- without the death spiral that permanent damage would cause.
DrivingConfig.Impair = {
	Seconds = 25,
	AccelMultiplier = 0.5, -- "Accel": slow to wind back up
	SteerMultiplier = 0.45, -- "Steer": vague, slow-responding steering
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
	-- Visible lean in corners. Scales with load, so a full bus visibly
	-- wallows -- the main cue that you're carrying too many people.
	BodyRollMaxDegrees = 14,
	AlignResponsiveness = 14,
	DriveForcePerMass = 150, -- horizontal force limit = assembly mass * this
	HoverStiffness = 10, -- vertical correction toward ride height
	MaxAlignTorque = 4e7,
	HeadingResyncDegrees = 30, -- re-sync steering heading after a knock
}

-- Server-side collision & sanity --------------------------------------------------
DrivingConfig.Collision = {
	SampleInterval = 0.1, -- seconds between position samples
	HistorySeconds = 0.8, -- how much position history to keep
	RecentWindow = 0.2, -- "speed now" is measured over this many seconds...
	BeforeWindow = 0.3, -- ...and compared with the speed over this window before it
	ImpactMinSpeed = 18, -- ignore slowdowns that start below this speed (studs/s)
	ImpactMinDrop = 16, -- studs/s of slowdown beyond what the brakes explain
	BrakeSlack = 1.5, -- allowed slowdown = brakeDecel * window * BrakeSlack
	ContactMargin = 1.5, -- studs around the bus checked for something solid
	DamagePerStudPerSecond = 0.9, -- damage per studs/s of excess slowdown
	-- Damage also scales with how fast you were going when you hit, not just
	-- how hard you stopped: at this speed the rate above applies in full,
	-- half this speed does half the damage.
	DamageSpeedReference = 60,
	ImpactCooldown = 0.8, -- seconds before another impact can register
	BreakdownSeconds = 5,
	BreakdownPassengerLoss = 0.25, -- fraction of onboard passengers lost
	BreakdownRepairFraction = 0.5, -- health restored after a breakdown
	-- Contact damage (RouteWars only -- BusMonitor.Watch opts in per round).
	-- The slowdown test above needs a real drop in speed, which an arcade bus
	-- driven by a LinearVelocity constraint often doesn't have: clip a kerb or
	-- shove another bus and you barely slow, so nothing registers. In a combat
	-- mode that reads as "crashing does nothing", so there touching anything
	-- solid above ContactMinSpeed hurts on its own, scaled by that speed.
	ContactMinSpeed = 22, -- studs/s; slower contact is just a nudge
	ContactDamagePerStudPerSecond = 0.35,

	SpeedTolerance = 1.3, -- flag above topSpeed * this
	SpeedStrikesToReset = 8, -- consecutive samples over tolerance before reset
	MaxTeleportStuds = 60, -- per sample, beyond expected travel
	FallResetY = -80, -- relative to the track; reset if below
	FlipResetSeconds = 3, -- reset if on its side/roof this long
}

-- Off-road tow-back. Only runs on layouts built without curbs (TrackLayouts):
-- there is no wall to stop you leaving the road, so leaving it costs time
-- instead. Deliberately cheaper than a breakdown (5s + 25% of your passengers)
-- so crashing is never the better option.
DrivingConfig.OffRoad = {
	Margin = 8, -- studs past the road edge before you count as off it
	GraceSeconds = 1.5, -- continuously off-road before the tow fires; clipping a corner is free
	TowSeconds = 2, -- frozen while the tow truck does its work
	TowPerStudPerSecond = 0.012, -- extra freeze per studs/s you were doing when you left
	TowMaxSeconds = 3.5, -- cap, however fast you were going
	Cooldown = 5, -- seconds before another tow can trigger
	-- Shoving someone off the road would otherwise be far stronger than shoving
	-- them into a curb used to be: the victim loses seconds, the rammer loses
	-- almost nothing. Contact this recently means no tow penalty.
	ContactGraceSeconds = 2,
}

return DrivingConfig
