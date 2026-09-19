--[[
	DamageEffectsConfig.lua

	How damaged buses look. Effects start when a bus drops below
	StartBelowHealth and get gradually stronger as health falls, maxing
	out at 0 health / broken down. Health values are fractions of the
	bus's max health (0.7 = 70%).

	Used by RouteClient/BusDamageEffects.client.lua (purely visual,
	runs on each player's own screen for every bus they can see).
]]

local DamageEffectsConfig = {}

-- Effects begin below this much health.
DamageEffectsConfig.StartBelowHealth = 0.85

-- How quickly effects catch up to health changes (higher = snappier).
DamageEffectsConfig.Smoothing = 3

-- Smoke from the hood ------------------------------------------------------------------
-- Tuned to be unmissable: a hurt bus should be obvious from across the
-- track, not something you notice only when you go looking for it. The
-- plume also lingers longer and rises faster, so at speed it trails behind
-- you instead of being left behind in a puff.
DamageEffectsConfig.SmokeMinRate = 12 -- particles/sec just below StartBelowHealth
DamageEffectsConfig.SmokeMaxRate = 110 -- particles/sec near 0 health
DamageEffectsConfig.BrokenDownSmokeRate = 190
DamageEffectsConfig.SmokeLightColor = Color3.fromRGB(225, 225, 225) -- light damage
DamageEffectsConfig.SmokeDarkColor = Color3.fromRGB(18, 18, 18) -- heavy damage
DamageEffectsConfig.SmokeMinSize = 3.5
DamageEffectsConfig.SmokeMaxSize = 14

-- Red tint over the whole bus --------------------------------------------------------------
DamageEffectsConfig.TintColor = Color3.fromRGB(255, 40, 30)
DamageEffectsConfig.TintMaxOpacity = 0.45 -- 0 = no tint, 1 = solid red
-- Below this health the tint pulses.
DamageEffectsConfig.PulseBelowHealth = 0.3
DamageEffectsConfig.PulseSpeed = 5

-- Flames --------------------------------------------------------------------------------------
DamageEffectsConfig.FireBelowHealth = 0.35
DamageEffectsConfig.FireMaxRate = 70

return DamageEffectsConfig
