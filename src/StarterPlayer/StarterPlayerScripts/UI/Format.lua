--[[
	Format.lua

	Text formatting shared by every UI: cash, times, plurals.
]]

local Format = {}

-- 12345 -> "$12,345", -50 -> "-$50"
function Format.Cash(amount)
	amount = amount or 0
	local digits = tostring(math.floor(math.abs(amount)))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (amount < 0 and "-$" or "$") .. grouped
end

-- 75 -> "1:15"
function Format.Time(seconds)
	seconds = math.max(0, math.ceil(seconds or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- (1, "passenger") -> "1 passenger", (3, "passenger") -> "3 passengers"
function Format.Count(count, noun)
	return string.format("%d %s%s", count, noun, count == 1 and "" or "s")
end

function Format.Number(amount)
	local digits = tostring(math.floor(math.abs(amount or 0)))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return ((amount or 0) < 0 and "-" or "") .. grouped
end

return Format
