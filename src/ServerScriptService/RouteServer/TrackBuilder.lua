--[[
	TrackBuilder.lua

	Builds one route track instance and describes it (stops, start grid,
	road polyline). Knows nothing about passengers or buses.

	Source, in order:
	  1. Workspace.RouteMap template (a Model you build in Studio).
	     Stops = parts tagged "RouteStop" with a number attribute "Index"
	     (LookVector = driving direction). Optional grid = parts tagged
	     "RouteGrid" with "Index". Road polyline = stops in order.
	  2. A procedural closed loop (placeholder art) from RouteConfig.
	     Every track uses the same seed so bracket tracks are identical.

	Track table:
	  { id, folder, busesFolder, length, points = {Vector3},
	    stops = { {index, cframe, position, distance, marker} },
	    grid = {CFrame at ground level, facing forward} }

	Traffic drives on the LEFT (Bangladesh), so stops sit on the left lane.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RouteConfig = require(ReplicatedStorage.Shared.Config.RouteConfig)

local TrackBuilder = {}

local ASPHALT = Color3.fromRGB(50, 50, 55)
local CURB = Color3.fromRGB(190, 190, 190)
local GRASS = Color3.fromRGB(90, 130, 70)
local DASH = Color3.fromRGB(240, 200, 60)
local RING_COLOR = Color3.fromRGB(255, 205, 70)

local function getInstancesFolder()
	local folder = workspace:FindFirstChild("RouteInstances")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RouteInstances"
		folder.Parent = workspace
	end
	return folder
end

local function makePart(parent, name, size, cframe, props)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props or {}) do
		part[key] = value
	end
	part.Parent = parent
	return part
end

-- Polyline helpers --------------------------------------------------------------------

local function buildCumulative(points)
	local cumulative = { 0 }
	for i = 1, #points do
		local a = points[i]
		local b = points[i % #points + 1]
		cumulative[i + 1] = cumulative[i] + (b - a).Magnitude
	end
	return cumulative, cumulative[#points + 1]
end

-- Position and forward direction at an arc distance along a closed polyline.
local function pointAtDistance(points, cumulative, length, distance)
	distance = distance % length
	for i = 1, #points do
		if distance < cumulative[i + 1] then
			local a = points[i]
			local b = points[i % #points + 1]
			local segmentLength = cumulative[i + 1] - cumulative[i]
			local t = segmentLength > 0 and (distance - cumulative[i]) / segmentLength or 0
			return a:Lerp(b, t), (b - a).Unit
		end
	end
	return points[1], (points[2] - points[1]).Unit
end

local function laneCFrame(position, direction, lateral)
	local base = CFrame.lookAt(position, position + direction)
	local lanePosition = position + base.RightVector * lateral
	return CFrame.lookAt(lanePosition, lanePosition + direction)
end

--[[
	An invisible anchor above a stop's ring. Clients find these by the
	"StopMarker" tag and draw their own billboard on it (StopBillboards.lua),
	so each player sees their own drop-offs and deadlines.
	Attributes: TrackId, StopIndex, Waiting (kept up to date by PassengerService).
]]
local function addStopMarker(track, index, position)
	local marker = Instance.new("Part")
	marker.Name = "StopMarker_" .. index
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	marker.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0))
	marker:SetAttribute("TrackId", track.id)
	marker:SetAttribute("StopIndex", index)
	marker:SetAttribute("Waiting", 0)
	CollectionService:AddTag(marker, "StopMarker")
	marker.Parent = track.markers
	return marker
end

-- A glowing rectangular bay on the road marking a stop's boarding area:
-- a painted outline, a faint fill, and low light walls along its sides.
-- bayCFrame: ground-level center of the bay, facing the driving direction.
local function addStopBay(parent, bayCFrame)
	local width = RouteConfig.StopBayWidth
	local length = RouteConfig.StopBayLength
	local height = RouteConfig.StopGlowHeight
	local line = 0.6

	local bay = Instance.new("Model")
	bay.Name = "Bay"
	bay.Parent = parent

	local function glow(name, size, offset, transparency)
		local part = makePart(bay, name, size, bayCFrame * offset, {
			Color = RING_COLOR,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		part.Transparency = transparency or 0
		return part
	end

	-- Outline
	glow("EdgeLeft", Vector3.new(line, 0.2, length), CFrame.new(-width / 2, 0.12, 0))
	glow("EdgeRight", Vector3.new(line, 0.2, length), CFrame.new(width / 2, 0.12, 0))
	glow("EdgeFront", Vector3.new(width + line, 0.2, line), CFrame.new(0, 0.12, -length / 2))
	glow("EdgeBack", Vector3.new(width + line, 0.2, line), CFrame.new(0, 0.12, length / 2))

	-- Faint fill + light
	local fill = glow("Fill", Vector3.new(width, 0.1, length), CFrame.new(0, 0.06, 0), 0.86)
	local light = Instance.new("PointLight")
	light.Color = RING_COLOR
	light.Range = length * 0.6
	light.Brightness = 1.2
	light.Parent = fill

	-- Low light walls along both sides
	if height > 0 then
		for _, side in ipairs({ -1, 1 }) do
			glow("GlowWall", Vector3.new(0.15, height, length), CFrame.new(side * width / 2, height / 2, 0), 0.8)
		end
	end

	return bay
end

-- Procedural loop -------------------------------------------------------------------------

local function generateLoopPoints(center)
	local rng = Random.new(RouteConfig.TrackSeed)
	local phase1 = rng:NextNumber(0, math.pi * 2)
	local phase2 = rng:NextNumber(0, math.pi * 2)
	local segments = RouteConfig.TrackSegments

	local points = {}
	for i = 0, segments - 1 do
		local angle = i / segments * math.pi * 2
		local noise = RouteConfig.TrackRadiusNoise * (0.6 * math.sin(2 * angle + phase1) + 0.4 * math.sin(3 * angle + phase2))
		points[i + 1] = center
			+ Vector3.new(math.cos(angle) * RouteConfig.TrackRadiusX * (1 + noise), 0, math.sin(angle) * RouteConfig.TrackRadiusZ * (1 + noise))
	end
	return points, rng
end

local function buildProcedural(track, center)
	local folder = track.folder
	local roadFolder = Instance.new("Folder")
	roadFolder.Name = "Road"
	roadFolder.Parent = folder

	local points, rng = generateLoopPoints(center)
	local cumulative, length = buildCumulative(points)
	track.points = points
	track.length = length

	local width = RouteConfig.RoadWidth
	local groundY = RouteConfig.TrackY

	-- Ground
	makePart(
		roadFolder,
		"Grass",
		Vector3.new(RouteConfig.TrackRadiusX * 2.6 + RouteConfig.GrassMargin, 1, RouteConfig.TrackRadiusZ * 2.6 + RouteConfig.GrassMargin),
		CFrame.new(center.X, groundY - 0.9, center.Z),
		{ Color = GRASS, Material = Enum.Material.Grass }
	)

	-- Road, corner fillers, curbs, lane dashes
	for i = 1, #points do
		local a = points[i]
		local b = points[i % #points + 1]
		local segmentLength = (b - a).Magnitude
		local mid = (a + b) / 2
		local along = CFrame.lookAt(mid, b)

		makePart(roadFolder, "Road", Vector3.new(width, 2, segmentLength + 1), along * CFrame.new(0, -1, 0), {
			Color = ASPHALT,
			Material = Enum.Material.Asphalt,
		})
		makePart(roadFolder, "Corner", Vector3.new(2, width, width), CFrame.new(a + Vector3.new(0, -1, 0)) * CFrame.Angles(0, 0, math.rad(90)), {
			Shape = Enum.PartType.Cylinder,
			Color = ASPHALT,
			Material = Enum.Material.Asphalt,
		})
		for _, side in ipairs({ -1, 1 }) do
			makePart(
				roadFolder,
				"Curb",
				Vector3.new(1, RouteConfig.CurbHeight, segmentLength),
				along * CFrame.new(side * (width / 2 + 0.5), RouteConfig.CurbHeight / 2, 0),
				{ Color = CURB, Material = Enum.Material.Concrete }
			)
		end
		makePart(roadFolder, "LaneDash", Vector3.new(0.4, 0.1, segmentLength * 0.45), along * CFrame.new(0, 0.05, 0), {
			Color = DASH,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end

	-- Start grid (behind the start distance), two columns, one per lane.
	local startDistance = RouteConfig.GridRowSpacing * math.ceil(RouteConfig.GridSlots / 2) + 40
	for slot = 1, RouteConfig.GridSlots do
		local row = math.floor((slot - 1) / 2)
		local column = (slot - 1) % 2
		local position, direction = pointAtDistance(points, cumulative, length, startDistance - row * RouteConfig.GridRowSpacing)
		local lateral = (column == 0 and -1 or 1) * width / 4
		track.grid[slot] = laneCFrame(position, direction, lateral)
	end

	-- Stops, evenly spaced between the start line and the back of the grid
	-- (so no stop zone overlaps parked buses), on the left lane.
	local stopsFolder = Instance.new("Folder")
	stopsFolder.Name = "Stops"
	stopsFolder.Parent = folder

	local gridBack = startDistance - (math.ceil(RouteConfig.GridSlots / 2) - 1) * RouteConfig.GridRowSpacing
	local firstStop = startDistance + 80
	local usable = (length + gridBack - 80) - firstStop
	for index = 1, RouteConfig.StopCount do
		local distance = (firstStop + (index - 1) * usable / math.max(RouteConfig.StopCount - 1, 1)) % length
		local position, direction = pointAtDistance(points, cumulative, length, distance)
		local stopCF = laneCFrame(position, direction, -width / 4) -- bay in the left lane

		local stopModel = Instance.new("Model")
		stopModel.Name = "Stop_" .. index
		stopModel.Parent = stopsFolder

		addStopBay(stopModel, stopCF)
		local shelterCF = laneCFrame(position, direction, -(width / 2 + 6))
		makePart(stopModel, "Platform", Vector3.new(8, 1, 20), shelterCF * CFrame.new(0, 0.5, 0), {
			Color = Color3.fromRGB(160, 160, 160),
			Material = Enum.Material.Concrete,
		})
		makePart(stopModel, "Pole", Vector3.new(0.6, 10, 0.6), shelterCF * CFrame.new(2.5, 6, -8), {
			Color = Color3.fromRGB(40, 120, 60),
		})
		makePart(stopModel, "Roof", Vector3.new(8, 0.5, 20), shelterCF * CFrame.new(0, 9, 0), {
			Color = Color3.fromRGB(40, 120, 60),
		})

		track.stops[index] = {
			index = index,
			cframe = stopCF,
			position = stopCF.Position,
			distance = distance,
			marker = addStopMarker(track, index, stopCF.Position),
		}
	end

	-- Parked obstacles (rickshaws / broken-down trucks), away from stops and the grid.
	local obstaclesFolder = Instance.new("Folder")
	obstaclesFolder.Name = "Obstacles"
	obstaclesFolder.Parent = folder

	local function nearReserved(distance)
		if distance <= startDistance + 40 then
			return true
		end
		for _, stop in ipairs(track.stops) do
			local gap = math.abs(distance - stop.distance)
			if math.min(gap, length - gap) < 70 then
				return true
			end
		end
		return false
	end

	for i = 1, #points do
		local distance = cumulative[i] + (cumulative[i + 1] - cumulative[i]) / 2
		if rng:NextNumber() < RouteConfig.ObstacleChance and not nearReserved(distance) then
			local position, direction = pointAtDistance(points, cumulative, length, distance)
			local isTruck = rng:NextNumber() < 0.35
			local size = isTruck and Vector3.new(8, 9, 16) or Vector3.new(3.5, 5, 6)
			local side = rng:NextNumber() < 0.5 and -1 or 1
			local lateral = side * (width / 2 - size.X / 2 - 1)
			makePart(obstaclesFolder, isTruck and "BrokenTruck" or "Rickshaw", size, laneCFrame(position, direction, lateral) * CFrame.new(0, size.Y / 2, 0), {
				Color = isTruck and Color3.fromRGB(110, 100, 90) or Color3.fromRGB(40, 150, 80),
			})
		end
	end
end

-- Template map --------------------------------------------------------------------------------

local function buildFromTemplate(track, template, center)
	local map = template:Clone()
	map.Name = "Map"
	if map:IsA("Model") then
		map:PivotTo(CFrame.new(center))
	end
	map.Parent = track.folder

	local stopParts, gridParts = {}, {}
	for _, item in ipairs(map:GetDescendants()) do
		if item:IsA("BasePart") then
			if CollectionService:HasTag(item, "RouteStop") then
				table.insert(stopParts, item)
			elseif CollectionService:HasTag(item, "RouteGrid") then
				table.insert(gridParts, item)
			end
		end
	end
	local function byIndex(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end
	table.sort(stopParts, byIndex)
	table.sort(gridParts, byIndex)
	assert(#stopParts >= 2, "TrackBuilder: RouteMap needs at least 2 parts tagged RouteStop")

	for i, part in ipairs(stopParts) do
		track.points[i] = part.Position
	end
	local cumulative, length = buildCumulative(track.points)
	track.length = length

	for i, part in ipairs(stopParts) do
		local ground = part.Position - Vector3.new(0, part.Size.Y / 2, 0)
		local look = Vector3.new(part.CFrame.LookVector.X, 0, part.CFrame.LookVector.Z)
		local bayCF = CFrame.lookAt(ground, ground + (look.Magnitude > 0.01 and look.Unit or -Vector3.zAxis))
		addStopBay(part.Parent or map, bayCF)
		track.stops[i] = {
			index = i,
			cframe = bayCF,
			position = part.Position,
			distance = cumulative[i],
			marker = addStopMarker(track, i, part.Position),
		}
	end

	if #gridParts > 0 then
		for i, part in ipairs(gridParts) do
			track.grid[i] = part.CFrame
		end
	else
		local first = track.stops[1].cframe
		for slot = 1, RouteConfig.GridSlots do
			local row = math.floor((slot - 1) / 2)
			local column = (slot - 1) % 2
			track.grid[slot] = first * CFrame.new((column == 0 and -1 or 1) * RouteConfig.RoadWidth / 4, 0, (row + 1) * RouteConfig.GridRowSpacing)
		end
	end
end

-- Public API ---------------------------------------------------------------------------------------

function TrackBuilder.Build(trackIndex)
	local center = Vector3.new(RouteConfig.TrackOriginX + (trackIndex - 1) * RouteConfig.TrackSpacing, RouteConfig.TrackY, 0)

	local folder = Instance.new("Folder")
	folder.Name = "Track_" .. trackIndex

	local busesFolder = Instance.new("Folder")
	busesFolder.Name = "Buses"
	busesFolder.Parent = folder

	-- Stop markers are always streamed to every client (billboards need them
	-- even when the stop is far away).
	local markers = Instance.new("Model")
	markers.Name = "StopMarkers"
	pcall(function()
		markers.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	markers.Parent = folder

	local track = {
		id = trackIndex,
		folder = folder,
		busesFolder = busesFolder,
		markers = markers,
		center = center,
		length = 0,
		points = {},
		stops = {},
		grid = {},
	}

	local template = workspace:FindFirstChild("RouteMap")
	if template then
		buildFromTemplate(track, template, center)
	else
		buildProcedural(track, center)
	end

	folder:SetAttribute("TrackId", trackIndex)
	folder.Parent = getInstancesFolder()
	return track
end

function TrackBuilder.Destroy(track)
	if track and track.folder then
		track.folder:Destroy()
	end
end

-- Arc distance travelling forward from one stop to another (a full lap if equal).
function TrackBuilder.DistanceBetween(track, fromIndex, toIndex)
	local gap = (track.stops[toIndex].distance - track.stops[fromIndex].distance) % track.length
	return gap > 0 and gap or track.length
end

-- Ground-level CFrame on the road nearest to a position, facing forward.
function TrackBuilder.NearestRoadCFrame(track, position)
	local bestIndex, bestDistance = 1, math.huge
	for i, point in ipairs(track.points) do
		local distance = (point - position).Magnitude
		if distance < bestDistance then
			bestIndex, bestDistance = i, distance
		end
	end
	local point = track.points[bestIndex]
	local nextPoint = track.points[bestIndex % #track.points + 1]
	return laneCFrame(point, (nextPoint - point).Unit, -RouteConfig.RoadWidth / 4)
end

return TrackBuilder
