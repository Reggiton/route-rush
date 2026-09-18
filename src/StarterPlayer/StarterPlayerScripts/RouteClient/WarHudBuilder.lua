--[[
	WarHudBuilder.lua

	Builds the RouteWars HUD, in the same plain style as RouteHudBuilder
	(dark panels, Gotham, grey buttons, green actions) but laid out to
	share the screen with it rather than collide:

	  top-right      War status pill (phase/timer) + Armory button
	  bottom-right   Ready-for-war card (lobby) / Leave-war button (racing)
	  above the regular boarding panel   item hotbar (1-5), war racing only
	  center-right   Armory shop panel (toggled by the Armory button)
	  full-screen    water-splash overlay + wiper button

	Only BUILDS instances; WarClient.client.lua fills everything in.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmoryConfig = require(ReplicatedStorage.Shared.Config.ArmoryConfig)

local WarHudBuilder = {}

local PANEL_BG = Color3.fromRGB(25, 25, 30)
local ROW_BG = Color3.fromRGB(40, 40, 45)
local MUTED = Color3.fromRGB(170, 170, 180)
local GREEN = Color3.fromRGB(120, 220, 140)
local YELLOW = Color3.fromRGB(250, 210, 60)
local BLUE = Color3.fromRGB(90, 160, 240)
local RED = Color3.fromRGB(230, 90, 80)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

local function frame(parent, name, size, position, props)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = PANEL_BG
	f.BorderSizePixel = 0
	for key, value in pairs(props or {}) do
		f[key] = value
	end
	f.Parent = parent
	return f
end

local function label(parent, name, text, size, position, props)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for key, value in pairs(props or {}) do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function button(parent, name, text, size, position, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color or ROW_BG
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 6)
	b:GetPropertyChangedSignal("Interactable"):Connect(function()
		b.TextTransparency = b.Interactable and 0 or 0.5
		b.BackgroundTransparency = b.Interactable and 0 or 0.4
	end)
	return b
end

function WarHudBuilder.Build(playerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WarHud"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local hud = { screenGui = screenGui }

	-- Status pill (top-right) --------------------------------------------------------------
	do
		local panel = frame(screenGui, "WarStatus", UDim2.fromOffset(230, 46), UDim2.new(1, -20, 0, 8), {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 0.15,
		})
		corner(panel)
		local phase = label(panel, "Phase", "ROUTE WARS", UDim2.fromOffset(140, 20), UDim2.fromOffset(12, 4), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = RED,
		})
		local timer = label(panel, "Timer", "", UDim2.fromOffset(140, 18), UDim2.fromOffset(12, 24), {
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local armoryButton = button(panel, "ArmoryButton", "Armory", UDim2.fromOffset(80, 34), UDim2.fromOffset(140, 6), Color3.fromRGB(150, 60, 55))
		hud.status = { panel = panel, phase = phase, timer = timer }
		hud.armoryButton = armoryButton
	end

	-- Ready-for-war card (bottom-right, lobby) ---------------------------------------------
	do
		local panel = frame(screenGui, "WarReady", UDim2.fromOffset(240, 100), UDim2.new(1, -20, 1, -120), {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 0.15,
		})
		corner(panel)
		local title = label(panel, "Title", "RouteWars", UDim2.fromOffset(220, 20), UDim2.fromOffset(10, 8), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = RED,
		})
		local status = label(panel, "Status", "Walk into the RouteWars zone", UDim2.fromOffset(220, 34), UDim2.fromOffset(10, 30), {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
			Font = Enum.Font.Gotham,
			TextWrapped = true,
		})
		hud.warReady = { panel = panel, title = title, status = status }
	end

	-- Leave war (bottom-right, racing) -------------------------------------------------------
	hud.leaveWarButton = button(screenGui, "LeaveWar", "Leave war", UDim2.fromOffset(140, 44), UDim2.new(1, -20, 1, -64), Color3.fromRGB(150, 50, 45))
	hud.leaveWarButton.AnchorPoint = Vector2.new(1, 0)
	hud.leaveWarButton.Visible = false

	-- Item hotbar (sits just above the regular boarding panel, war racing only) --------------
	do
		local SLOT = 84
		local count = #ArmoryConfig.Items
		local width = count * SLOT + (count - 1) * 8
		local panel = frame(screenGui, "Hotbar", UDim2.fromOffset(width, 96), UDim2.new(0.5, -width / 2, 1, -256), {
			BackgroundTransparency = 1,
			Visible = false,
		})

		local slots = {}
		for index, item in ipairs(ArmoryConfig.Items) do
			local x = (index - 1) * (SLOT + 8)
			local slot = frame(panel, item.id, UDim2.fromOffset(SLOT, 96), UDim2.fromOffset(x, 0), {
				BackgroundTransparency = 0.1,
			})
			corner(slot)
			label(slot, "Key", tostring(index), UDim2.fromOffset(24, 18), UDim2.fromOffset(4, 2), {
				TextColor3 = MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			label(slot, "Name", item.name, UDim2.new(1, -8, 0, 30), UDim2.fromOffset(4, 18), {
				TextWrapped = true,
				TextScaled = true,
			})
			local count_ = label(slot, "Count", "0", UDim2.new(1, -8, 0, 26), UDim2.fromOffset(4, 62), {
				TextColor3 = GREEN,
			})
			slots[item.id] = { frame = slot, count = count_ }
		end

		hud.hotbar = { panel = panel, slots = slots }
	end

	-- Armory shop panel (toggled) --------------------------------------------------------------
	do
		local panel = frame(screenGui, "Armory", UDim2.fromOffset(460, 420), UDim2.new(0.5, 0, 0.5, 0), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 0.05,
			Visible = false,
		})
		corner(panel, 12)
		label(panel, "Title", "ARMORY", UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 10), {
			Font = Enum.Font.GothamBlack,
			TextColor3 = RED,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local cash = label(panel, "Cash", "$0", UDim2.fromOffset(140, 34), UDim2.new(1, -150, 0, 10), {
			TextColor3 = GREEN,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local closeButton = button(panel, "Close", "X", UDim2.fromOffset(34, 34), UDim2.new(1, -44, 0, 10), Color3.fromRGB(150, 50, 45))

		local rows = Instance.new("Frame")
		rows.Name = "Rows"
		rows.Size = UDim2.new(1, -24, 1, -60)
		rows.Position = UDim2.fromOffset(12, 50)
		rows.BackgroundTransparency = 1
		rows.Parent = panel
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = rows

		local items = {}
		for index, item in ipairs(ArmoryConfig.Items) do
			local row = frame(rows, item.id, UDim2.new(1, 0, 0, 62), UDim2.new(), {
				BackgroundColor3 = ROW_BG,
				LayoutOrder = index,
			})
			corner(row, 8)
			label(row, "Name", item.name, UDim2.fromOffset(220, 20), UDim2.fromOffset(10, 6), {
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			label(row, "Description", item.description, UDim2.new(0, 270, 0, 30), UDim2.fromOffset(10, 26), {
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = MUTED,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextScaled = false,
				TextSize = 12,
			})
			local owned = label(row, "Owned", "Owned 0", UDim2.fromOffset(110, 16), UDim2.new(1, -230, 0, 6), {
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = GREEN,
				Font = Enum.Font.Gotham,
			})
			local buyButton = button(row, "Buy", "$" .. item.price, UDim2.fromOffset(110, 34), UDim2.new(1, -120, 1, -40), Color3.fromRGB(50, 140, 70))
			items[item.id] = { row = row, owned = owned, buyButton = buyButton }
		end

		hud.armory = { panel = panel, cash = cash, closeButton = closeButton, items = items }
	end

	-- Water-splash overlay (full-screen) ----------------------------------------------------------
	do
		local overlay = frame(screenGui, "WaterSplash", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), {
			BackgroundColor3 = Color3.fromRGB(60, 130, 210),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 50,
		})

		-- A handful of blobby "droplets" for texture; their combined
		-- transparency is driven by the same fraction as the overlay.
		local droplets = {}
		local rng = Random.new(7)
		for i = 1, 14 do
			local size = rng:NextNumber(60, 160)
			local drop = frame(overlay, "Drop" .. i, UDim2.fromOffset(size, size), UDim2.fromScale(rng:NextNumber(), rng:NextNumber()), {
				BackgroundColor3 = Color3.fromRGB(200, 225, 245),
				BackgroundTransparency = 0.5,
				ZIndex = 51,
			})
			corner(drop, size / 2)
			table.insert(droplets, drop)
		end

		local wipeButton = button(overlay, "Wipe", "WIPE  [Click / Space]", UDim2.fromOffset(260, 60), UDim2.new(0.5, -130, 1, -120), Color3.fromRGB(255, 255, 255))
		wipeButton.ZIndex = 52
		wipeButton.TextColor3 = Color3.fromRGB(30, 30, 40)

		hud.waterSplash = { overlay = overlay, droplets = droplets, wipeButton = wipeButton }
	end

	return hud
end

return WarHudBuilder
