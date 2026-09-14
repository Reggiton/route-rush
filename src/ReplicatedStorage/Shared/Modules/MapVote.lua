--[[
	MapVote.lua

	Pure tally and tie-break for the lobby map vote (no Roblox instances), so
	the part that decides which map everyone races can be tested directly.
	MapVoteService wraps this with players, attributes and the remote.

	Deliberately boring rules, because a vote that surprises people feels
	broken:
	  - most votes wins
	  - a tie goes to the default layout if it is among the tied, otherwise to
	    whichever tied layout comes first in the registry
	  - nobody voted, or every vote was for something unknown -> the default

	So an idle server keeps racing the map it has always raced.
]]

local TrackLayouts = require(script.Parent.Parent.Config.TrackLayouts)

local MapVote = {}

-- votes: { [anyKey] = layoutId }. Unknown or non-string ids are ignored.
-- Returns counts keyed by layout id, and how many votes actually counted.
function MapVote.Tally(votes)
	local counts = {}
	local total = 0
	for _, layoutId in pairs(votes or {}) do
		if TrackLayouts.Get(layoutId) then
			counts[layoutId] = (counts[layoutId] or 0) + 1
			total = total + 1
		end
	end
	return counts, total
end

-- The winning layout id. Never returns nil.
function MapVote.Resolve(counts)
	counts = counts or {}

	local best = 0
	for _, count in pairs(counts) do
		if count > best then
			best = count
		end
	end
	if best == 0 then
		return TrackLayouts.DefaultId
	end

	-- Registry order decides ties, and the default sits first in the registry,
	-- so this also covers "the default was among the tied".
	for _, layout in ipairs(TrackLayouts.List) do
		if (counts[layout.id] or 0) == best then
			return layout.id
		end
	end
	return TrackLayouts.DefaultId
end

-- Convenience for callers that just want the answer.
function MapVote.Winner(votes)
	local counts = MapVote.Tally(votes)
	return MapVote.Resolve(counts)
end

return MapVote
