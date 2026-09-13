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
DamageEffectsConfig.StartBelowHealth = 0.7

-- How quickly effects catch up to health changes (higher = snappier).
DamageEffectsConfig.Smoothing = 3

-- Smoke from the hood ------------------------------------------------------------------
DamageEffectsConfig.SmokeMinRate = 3 -- particles/sec just below StartBelowHealth
DamageEffectsConfig.SmokeMaxRate = 45 -- particles/sec near 0 health
DamageEffectsConfig.BrokenDownSmokeRate = 80
DamageEffectsConfig.SmokeLightColor = Color3.fromRGB(210, 210, 210) -- light damage
DamageEffectsConfig.SmokeDarkColor = Color3.fromRGB(30, 30, 30) -- heavy damage
DamageEffectsConfig.SmokeMinSize = 2
DamageEffectsConfig.SmokeMaxSize = 7

-- Red tint over the whole bus --------------------------------------------------------------
DamageEffectsConfig.TintColor = Color3.fromRGB(255, 40, 30)
DamageEffectsConfig.TintMaxOpacity = 0.45 -- 0 = no tint, 1 = solid red
-- Below this health the tint pulses.
DamageEffectsConfig.PulseBelowHealth = 0.3
DamageEffectsConfig.PulseSpeed = 5

-- Flames --------------------------------------------------------------------------------------
DamageEffectsConfig.FireBelowHealth = 0.25
DamageEffectsConfig.FireMaxRate = 30

return DamageEffectsConfig
