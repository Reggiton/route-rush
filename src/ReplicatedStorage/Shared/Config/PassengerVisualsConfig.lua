--[[
	PassengerVisualsConfig.lua

	The look and limits of the visible passengers: noob figures riding in
	the windows, clinging to the roof at full load, and waiting at stops.

	These are drawn entirely on each client (BusPassengerVisuals /
	StopCrowdVisuals) from attributes the server already replicates --
	Passengers/Capacity on a bus, Waiting on a stop marker -- so nothing
	here costs network traffic, and nothing here can affect gameplay.

	SCALE: a Tier 4 bus with maxed Handles seats 72, and a grid holds 24
	buses. Drawing one figure per passenger would be ~1700 models, so the
	bus shows as many as physically FIT (window seats + roof slots) and
	fills them proportionally. Stops are different: WaitingCap is 12, so a
	stop crowd shows the real number waiting.
]]

local PassengerVisualsConfig = {}

-- Classic noob: yellow head and arms, blue torso, green legs.
PassengerVisualsConfig.Colors = {
	Head = Color3.fromRGB(245, 205, 48),
	Torso = Color3.fromRGB(13, 105, 172),
	Arm = Color3.fromRGB(245, 205, 48),
	Leg = Color3.fromRGB(75, 151, 75),
}

-- Cartoon outline. One Highlight per GROUP (a bus's riders, a stop's
-- crowd), never one per figure: Roblox stops rendering highlights past
-- roughly 31 at once, and per-figure would blow through that instantly.
PassengerVisualsConfig.Outline = {
	Enabled = true,
	Color = Color3.fromRGB(0, 0, 0),
	Transparency = 0.15,
}

-- Figure proportions, in studs (roughly R6).
PassengerVisualsConfig.Figure = {
	HeadSize = Vector3.new(1.2, 1.2, 1.2),
	TorsoSize = Vector3.new(1.6, 1.8, 0.9),
	ArmSize = Vector3.new(0.5, 1.7, 0.7),
	LegSize = Vector3.new(0.6, 1.8, 0.8),
}

-- Bus riders -------------------------------------------------------------------------
PassengerVisualsConfig.Bus = {
	-- Load fraction at which riders start appearing in the windows, and the
	-- fraction by which every window seat is taken.
	WindowStartLoad = 0.5,
	WindowFullLoad = 1,
	WindowSeatsPerSide = 3,
	-- Riders are turned to face out of their window and tipped forward so
	-- they read as leaning on the glass. Without this they look like
	-- upright figures floating inside the bus.
	SeatLeanDegrees = 12,
	SeatHeightOffset = -0.35,

	-- Roof clingers only show once the bus is nearly full -- that's the
	-- whole read: "there is no room left inside".
	RoofStartLoad = 0.92,
	RoofSlots = 4,

	-- Wind: roof clingers lie face down gripping the roof, and the faster
	-- you drive the harder they struggle -- legs kicking, body slipping.
	WindReferenceSpeed = 70,
	-- How much they squirm even when the bus is barely moving, so a
	-- stationary bus doesn't look like it's carrying mannequins.
	StruggleFloor = 0.25,

	-- Someone getting on or off: a figure hops at the door over this long.
	-- One press can board several people at once, so a few hops are
	-- staggered rather than fired all at the same instant.
	HopSeconds = 0.55,
	HopHeight = 2.2,
	MaxHopsPerEvent = 3,
	HopStagger = 0.12,

	-- Don't draw riders on buses further away than this (studs).
	RenderDistance = 320,
}

-- Breakdown ------------------------------------------------------------------------------
-- A breakdown shouldn't look like a tidy drop-off. Passengers are flung
-- clear and pieces of the bus fly off with them.
--
-- Both are thrown on a hand-simulated arc (anchored parts moved by CFrame)
-- rather than by real physics: unanchored local debris could shove the
-- driver's own client-owned bus around, which would turn a cosmetic effect
-- into a gameplay one.
PassengerVisualsConfig.Breakdown = {
	EjectMin = 2,
	EjectMax = 3,
	DebrisCount = 7,

	LifeSeconds = 2.2,
	FadeAfter = 0.55, -- fraction of life before they start fading out
	Gravity = 90,
	-- Thrown up and outward from the bus, with a bit of its own speed.
	LaunchUp = 42,
	LaunchOut = 26,
	InheritSpeed = 0.55,
	SpinDegrees = 520,
}

-- Stop crowds ---------------------------------------------------------------------------
PassengerVisualsConfig.Stop = {
	-- Rows of waiting figures on the platform, filled front row first.
	PerRow = 4,
	RowGap = 2.2,
	ColumnGap = 1.8,
	-- Small random offset so a queue doesn't look like a grid of clones.
	Jitter = 0.35,
	RenderDistance = 400,
}

return PassengerVisualsConfig
