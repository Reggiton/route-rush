--[[
	ServerSignals.lua

	Server-only BindableEvents shared between server scripts. Requiring
	this module from anywhere returns the same instances.
]]

local ServerSignals = {}

-- Fired (no args) to end the current session phase early. Used by dev
-- commands for fast testing.
ServerSignals.SkipPhase = Instance.new("BindableEvent")

return ServerSignals
