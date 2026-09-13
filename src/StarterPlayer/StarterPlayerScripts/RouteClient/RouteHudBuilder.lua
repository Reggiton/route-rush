--[[
	RouteHudBuilder.lua

	Builds the route HUD from UIKit components. Only BUILDS instances (plus
	two tiny helpers: toast() and results row management); RouteClient
	fills everything in.

	Layout (each cluster scales with the screen):
	  top-left      profile card: cash, level + XP, reputation
	  top-left      Leave race button (under the profile, in a race)
	  top-center    status pill: phase + timer (+ fares while racing)
	  top-center    toast stack
	  bottom-center Ready card (lobby) / Boarding card (inside a stop ring)
	  bottom-left   bus card: passengers, health, run stats
	  bottom-right  speedometer
	  center        countdown, results
]]

local UI = script.Parent.Parent:WaitForChild("UI")
local UIKit = require(UI:WaitForChild("UIKit"))
local Theme = UIKit.Theme

local RouteHudBuilder = {}

local M = Theme.ScreenMargin

local function divider(parent, props)
	return UIKit.Frame({
		Name = "Divider",
		BackgroundTransparency = 0.88,
		BackgroundColor3 = Theme.Colors.Stroke,
		Size = props.Size,
		Position = props.Position,
		Parent = parent,
	})
end

function RouteHudBuilder.Build(playerGui)
	local screenGui = UIKit.Screen("RouteHud", playerGui, 5)
	local hud = { screenGui = screenGui }

	-- Profile (top-left) --------------------------------------------------------------------------
	do
		local panel = UIKit.Panel({
			Name = "Profile",
			Size = UDim2.fromOffset(362, 66),
			Position = UDim2.fromOffset(M, 10),
			padding = { 10, 16, 10, 16 },
			Parent = screenGui,
		})
		UIKit.AutoScale(panel)

		local _, cash = UIKit.Stat({ caption = "Cash", value = "$0", color = "Positive", Size = UDim2.fromOffset(118, 46), Parent = panel })

		divider(panel, { Size = UDim2.fromOffset(1, 34), Position = UDim2.fromOffset(128, 6) })

		local levelBlock = UIKit.Frame({ Size = UDim2.fromOffset(84, 46), Position = UDim2.fromOffset(142, 0), Parent = panel })
		UIKit.Caption({ Text = "Level", Size = UDim2.new(1, 0, 0, 14), Parent = levelBlock })
		local level = UIKit.Text({
			Text = "1",
			size = "Stat",
			weight = "Heavy",
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.fromOffset(0, 14),
			Parent = levelBlock,
		})
		local _, xpFill = UIKit.Bar({ Size = UDim2.new(1, 0, 0, 4), Position = UDim2.fromOffset(0, 42), color = "Info", Parent = levelBlock })

		divider(panel, { Size = UDim2.fromOffset(1, 34), Position = UDim2.fromOffset(236, 6) })

		local _, rep = UIKit.Stat({
			caption = "Rep",
			value = "0",
			color = "Accent",
			Size = UDim2.fromOffset(80, 46),
			Position = UDim2.fromOffset(250, 0),
			Parent = panel,
		})

		hud.profile = { panel = panel, cash = cash, level = level, xpFill = xpFill, rep = rep }
	end

	hud.leaveButton = UIKit.Button({
		Name = "LeaveRace",
		Text = "Leave race",
		variant = "danger",
		Size = UDim2.fromOffset(132, 40),
		Position = UDim2.fromOffset(M, 86),
		Visible = false,
		Parent = screenGui,
	})
	UIKit.AutoScale(hud.leaveButton)

	-- Status pill (top-center) -------------------------------------------------------------------
	do
		local panel = UIKit.Panel({
			Name = "Status",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(200, 70),
			padding = { 10, 18, 12, 18 },
			Parent = screenGui,
		})
		UIKit.AutoScale(panel)

		local phase = UIKit.Caption({ Text = "Next route", Size = UDim2.new(0, 150, 0, 14), Parent = panel })
		local timer = UIKit.Text({
			Text = "0:30",
			size = "Display",
			weight = "Heavy",
			Size = UDim2.new(0, 150, 0, 36),
			Position = UDim2.fromOffset(0, 12),
			Parent = panel,
		})

		local fares = UIKit.Frame({ Size = UDim2.fromOffset(110, 48), Position = UDim2.fromOffset(170, 0), Visible = false, Parent = panel })
		divider(fares, { Size = UDim2.fromOffset(1, 36), Position = UDim2.fromOffset(-12, 6) })
		local _, faresValue = UIKit.Stat({
			caption = "Fares",
			value = "$0",
			color = "Positive",
			Size = UDim2.fromScale(1, 1),
			Parent = fares,
		})

		local _, progress = UIKit.Bar({
			Size = UDim2.new(1, 0, 0, 3),
			Position = UDim2.new(0, 0, 1, 1),
			color = "Accent",
			Parent = panel,
		})

		hud.status = { panel = panel, phase = phase, timer = timer, fares = fares, faresValue = faresValue, progress = progress }
	end

	-- Toast stack (under the status pill) ------------------------------------------------------------
	do
		local stack = UIKit.Frame({
			Name = "Toasts",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 92),
			Size = UDim2.fromOffset(520, 150),
			Parent = screenGui,
		})
		UIKit.AutoScale(stack)
		UIKit.List(stack, { gap = 6, align = "Center" })

		local order = 0
		function hud.toast(text, tone)
			order = order + 1
			local toast = UIKit.Panel({
				Name = "Toast",
				Size = UDim2.fromOffset(0, 38),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = order,
				radius = Theme.Radius.Pill,
				padding = { 0, 18, 0, 16 },
				Parent = stack,
			})
			local dot = UIKit.Frame({
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.Colors[tone or "Accent"] or Theme.Colors.Accent,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(8, 8),
				Parent = toast,
			})
			UIKit.Corner(dot, Theme.Radius.Pill)
			UIKit.Text({
				Text = text,
				weight = "Bold",
				TextTruncate = Enum.TextTruncate.None,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Position = UDim2.fromOffset(18, 0),
				Parent = toast,
			})

			local pop = Instance.new("UIScale")
			pop.Scale = 0.85
			pop.Parent = toast
			UIKit.Tween(pop, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)

			-- Keep at most 3 on screen.
			local toasts = {}
			for _, child in ipairs(stack:GetChildren()) do
				if child.Name == "Toast" then
					table.insert(toasts, child)
				end
			end
			table.sort(toasts, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			for i = 1, #toasts - 3 do
				toasts[i]:Destroy()
			end

			task.delay(2.6, function()
				if toast.Parent then
					UIKit.Tween(pop, { Scale = 0 }, 0.18)
					task.delay(0.2, function()
						toast:Destroy()
					end)
				end
			end)
		end
	end

	-- Ready card (bottom-center, lobby) ------------------------------------------------------------------
	do
		local panel = UIKit.Panel({
			Name = "Ready",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -24),
			Size = UDim2.fromOffset(380, 132),
			padding = 16,
			Parent = screenGui,
		})
		UIKit.AutoScale(panel)

		local title = UIKit.Text({ Text = "Next race", size = "Title", weight = "Heavy", Size = UDim2.new(1, 0, 0, 24), Parent = panel })
		local status = UIKit.Text({
			size = "Small",
			color = "TextMuted",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 26),
			Parent = panel,
		})
		local button = UIKit.Button({
			Name = "ReadyButton",
			Text = "Ready up",
			variant = "primary",
			size = "Title",
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.new(0, 0, 1, -48),
			Parent = panel,
		})

		hud.ready = { panel = panel, title = title, status = status, button = button }
	end

	-- Bus card (bottom-left) ---------------------------------------------------------------------------
	do
		local panel = UIKit.Panel({
			Name = "Bus",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, M, 1, -M),
			Size = UDim2.fromOffset(300, 148),
			padding = 14,
			Visible = false,
			Parent = screenGui,
		})
		UIKit.AutoScale(panel)

		local function meter(captionText, y, fillColor)
			UIKit.Caption({ Text = captionText, Size = UDim2.new(0.5, 0, 0, 16), Position = UDim2.fromOffset(0, y), Parent = panel })
			local value = UIKit.Text({
				size = "Small",
				weight = "Bold",
				Size = UDim2.new(0.5, 0, 0, 16),
				Position = UDim2.new(0.5, 0, 0, y),
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = panel,
			})
			local _, fill = UIKit.Bar({ Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, y + 20), color = fillColor, Parent = panel })
			return value, fill
		end

		local passengers, loadFill = meter("Passengers", 0, "Positive")
		local health, healthFill = meter("Health", 38, "Negative")
		local stats = UIKit.Text({
			size = "Small",
			color = "TextMuted",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 78),
			Parent = panel,
		})
		local problem = UIKit.Text({
			size = "Small",
			weight = "Bold",
			color = "Warning",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 100),
			Visible = false,
			Parent = panel,
		})

		hud.bus = {
			panel = panel,
			passengers = passengers,
			loadFill = loadFill,
			health = health,
			healthFill = healthFill,
			stats = stats,
			problem = problem,
		}
	end

	-- Speedometer (bottom-right) --------------------------------------------------------------------------
	do
		local panel = UIKit.Panel({
			Name = "Speed",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -M, 1, -M),
			Size = UDim2.fromOffset(180, 112),
			padding = { 10, 18, 12, 18 },
			Visible = false,
			Parent = screenGui,
		})
		UIKit.AutoScale(panel)

		local value = UIKit.Text({
			Text = "0",
			size = 64,
			weight = "Heavy",
			Size = UDim2.new(1, 0, 0, 62),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = panel,
		})
		UIKit.Caption({
			Text = "Studs / sec",
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.fromOffset(0, 62),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = panel,
		})
		local sliding = UIKit.Frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.Colors.Warning,
			Size = UDim2.fromOffset(72, 18),
			Position = UDim2.fromOffset(0, 70),
			Visible = false,
			Parent = panel,
		})
		UIKit.Corner(sliding, Theme.Radius.Pill)
		UIKit.Text({
			Text = "SLIDING",
			size = "Caption",
			weight = "Heavy",
			color = "OnAccent",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = sliding,
		})

		hud.speed = { panel = panel, value = value, sliding = sliding }
	end

	-- Boarding card (bottom-center, inside a stop ring) ------------------------------------------------------
	do
		local panel = UIKit.Panel({
			Name = "Boarding",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -M),
			Size = UDim2.fromOffset(440, 128),
			padding = 14,
			stroke = false,
			Visible = false,
			Parent = screenGui,
		})
		UIKit.Stroke(panel, { color = "Accent", transparency = 0.35, thickness = 1.5 })
		UIKit.AutoScale(panel)

		local left = UIKit.Frame({ Size = UDim2.new(1, -140, 1, 0), Parent = panel })
		local title = UIKit.Text({ size = "Title", weight = "Heavy", color = "Accent", Size = UDim2.new(1, 0, 0, 24), Parent = left })
		local subtitle = UIKit.Text({
			size = "Small",
			color = "TextMuted",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 24),
			Parent = left,
		})
		UIKit.Caption({ Text = "Boarding rate", Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 50), Parent = left })
		local _, rateFill = UIKit.Bar({ Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, 68), color = "Positive", Parent = left })
		local hint = UIKit.Text({
			size = "Small",
			weight = "Bold",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 82),
			Parent = left,
		})

		local button = UIKit.Button({
			Name = "BoardButton",
			Text = "",
			variant = "primary",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 126, 1, 0),
			radius = Theme.Radius.Large,
			Parent = panel,
		})
		local keycap = UIKit.Frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.Colors.OnAccent,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(40, 40),
			Parent = button,
		})
		UIKit.Corner(keycap, Theme.Radius.Medium)
		UIKit.Text({
			Text = "E",
			size = "Title",
			weight = "Heavy",
			color = "Accent",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = keycap,
		})
		local boarded = UIKit.Text({
			Text = "BOARD",
			size = "Body",
			weight = "Heavy",
			color = "OnAccent",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 62),
			Size = UDim2.new(1, -12, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
		local boardedCount = UIKit.Text({
			size = "Caption",
			weight = "Bold",
			color = "OnAccent",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 80),
			Size = UDim2.new(1, -12, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})

		hud.board = {
			panel = panel,
			title = title,
			subtitle = subtitle,
			rateFill = rateFill,
			hint = hint,
			button = button,
			buttonLabel = boarded,
			boardedCount = boardedCount,
		}
	end

	-- Countdown (center) ---------------------------------------------------------------------------------------
	do
		local label = UIKit.Text({
			Name = "Countdown",
			size = "Hero",
			weight = "Heavy",
			color = "Text",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.38),
			Size = UDim2.fromOffset(400, 140),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.7,
			Visible = false,
			Parent = screenGui,
		})
		local pop = Instance.new("UIScale")
		pop.Parent = label
		hud.countdown = { label = label, pop = pop }
	end

	-- Results (center) -------------------------------------------------------------------------------------------
	do
		local panel = UIKit.Panel({
			Name = "Results",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(440, 480),
			padding = 24,
			Visible = false,
			Parent = screenGui,
		})
		UIKit.AutoScale(panel)

		UIKit.Caption({ Text = "Route complete", color = "Accent", Size = UDim2.new(1, 0, 0, 14), Parent = panel })
		local total = UIKit.Text({
			size = 44,
			weight = "Heavy",
			color = "Positive",
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.fromOffset(0, 18),
			Parent = panel,
		})
		UIKit.Text({
			Text = "earned this run",
			size = "Small",
			color = "TextMuted",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 64),
			Parent = panel,
		})
		divider(panel, { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 94) })

		local rows = UIKit.Frame({ Size = UDim2.new(1, 0, 1, -140), Position = UDim2.fromOffset(0, 108), Parent = panel })
		UIKit.List(rows, { gap = 4 })

		local footer = UIKit.Caption({
			Text = "Returning to lobby",
			color = "TextDim",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 14),
			Parent = panel,
		})

		local rowOrder = 0
		local results = { panel = panel, total = total, footer = footer }

		function results.clear()
			rowOrder = 0
			for _, child in ipairs(rows:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
		end

		function results.addRow(labelText, valueText, tone)
			rowOrder = rowOrder + 1
			local row = UIKit.Frame({ Size = UDim2.new(1, 0, 0, 24), LayoutOrder = rowOrder, Parent = rows })
			UIKit.Text({
				Text = labelText,
				color = tone and tone or "TextMuted",
				weight = tone and "Bold" or "Medium",
				Size = UDim2.new(0.62, 0, 1, 0),
				Parent = row,
			})
			UIKit.Text({
				Text = valueText or "",
				weight = "Bold",
				color = tone or "Text",
				Size = UDim2.new(0.38, 0, 1, 0),
				Position = UDim2.fromScale(0.62, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = row,
			})
		end

		hud.results = results
	end

	return hud
end

return RouteHudBuilder
