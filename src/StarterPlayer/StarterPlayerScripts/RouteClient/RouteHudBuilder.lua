--[[
	RouteHudBuilder.lua

	Builds the route HUD from UIKit components. Only BUILDS instances (plus
	two tiny helpers: toast() and results row management); RouteClient
	fills everything in.

	Every screen corner is one UIKit.Dock, so each corner scales with the
	screen as a unit:
	  top-center    top bar: phase + timer | cash | level + XP | rep (| fares) + toasts
	  top-left      Leave race button (in a race)
	  bottom-center Ready card (lobby) / Boarding card (inside a stop bay)
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
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Theme.Colors.PanelEdge,
		Size = props.Size or UDim2.fromOffset(2, 34),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		Parent = parent,
	})
end

function RouteHudBuilder.Build(playerGui)
	local screenGui = UIKit.Screen("RouteHud", playerGui, 5)
	local hud = { screenGui = screenGui }

	-- Top bar + toasts (top-center) -------------------------------------------------------------------
	do
		local dock = UIKit.Dock({
			Name = "TopDock",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(820, 200),
			Parent = screenGui,
		})
		UIKit.List(dock, { gap = 10, align = "Center" })

		local bar = UIKit.Panel({
			Name = "TopBar",
			Size = UDim2.fromOffset(0, 62),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 1,
			padding = { 6, 20, 8, 20 },
			tape = { "TopLeft", "TopRight" },
			Parent = dock,
		})
		local row = UIKit.Frame({
			Name = "Row",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = bar,
		})
		UIKit.List(row, { direction = "Horizontal", gap = 18, valign = "Center" })

		-- Phase + timer
		local timerBlock = UIKit.Frame({ Size = UDim2.fromOffset(112, 46), LayoutOrder = 1, Parent = row })
		local phase = UIKit.Caption({ Text = "Next route", Size = UDim2.new(1, 0, 0, 14), Parent = timerBlock })
		local timer = UIKit.Text({
			Text = "0:30",
			size = 28,
			weight = "Heavy",
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 14),
			Parent = timerBlock,
		})
		divider(row, { LayoutOrder = 2 })

		-- Cash (underlined, like a price tag)
		local cashBlock = UIKit.Frame({ Size = UDim2.fromOffset(128, 46), LayoutOrder = 3, Parent = row })
		local cash = UIKit.Text({
			Text = "$0",
			size = 28,
			weight = "Heavy",
			color = "Cash",
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromOffset(0, 4),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = cashBlock,
		})
		UIKit.Frame({
			BackgroundTransparency = 0.2,
			BackgroundColor3 = Theme.Colors.Cash,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 38),
			Size = UDim2.new(0.8, 0, 0, 2),
			Parent = cashBlock,
		})
		divider(row, { LayoutOrder = 4 })

		-- Level + XP
		local levelBlock = UIKit.Frame({ Size = UDim2.fromOffset(112, 46), LayoutOrder = 5, Parent = row })
		local level = UIKit.Text({
			Text = "Lv 1",
			size = 24,
			weight = "Heavy",
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 2),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = levelBlock,
		})
		local _, xpFill = UIKit.Bar({
			Size = UDim2.new(1, 0, 0, 7),
			Position = UDim2.fromOffset(0, 34),
			color = "Level",
			Parent = levelBlock,
		})
		divider(row, { LayoutOrder = 6 })

		-- Reputation (hand-painted)
		local repBlock = UIKit.Frame({ Size = UDim2.fromOffset(118, 46), LayoutOrder = 7, Parent = row })
		local rep = UIKit.Brush({
			Text = "Rep 0",
			size = 28,
			color = "Rep",
			tilt = -3,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = repBlock,
		})

		-- Fares (only while racing)
		local fares = UIKit.Frame({ Size = UDim2.fromOffset(132, 46), LayoutOrder = 8, Visible = false, Parent = row })
		divider(fares, { Position = UDim2.fromOffset(0, 6) })
		local _, faresValue = UIKit.Stat({
			caption = "Fares",
			value = "$0",
			color = "Cash",
			Size = UDim2.new(1, -18, 1, 0),
			Position = UDim2.fromOffset(18, 0),
			Parent = fares,
		})

		local _, progress = UIKit.Bar({
			Name = "PhaseProgress",
			Size = UDim2.new(1, 0, 0, 3),
			Position = UDim2.new(0, 0, 1, 4),
			color = "Mustard",
			Parent = bar,
		})

		hud.profile = { panel = bar, cash = cash, level = level, xpFill = xpFill, rep = rep }
		hud.status = { panel = bar, phase = phase, timer = timer, fares = fares, faresValue = faresValue, progress = progress }

		-- Toasts
		local stack = UIKit.Frame({ Name = "Toasts", Size = UDim2.fromOffset(820, 130), LayoutOrder = 2, Parent = dock })
		UIKit.List(stack, { gap = 6, align = "Center" })

		local order = 0
		function hud.toast(text, tone)
			order = order + 1
			local toast = UIKit.Panel({
				Name = "Toast",
				Size = UDim2.fromOffset(0, 38),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = order,
				padding = { 0, 18, 0, 22 },
				Parent = stack,
			})
			UIKit.Frame({
				Name = "Stripe",
				BackgroundTransparency = 0,
				BackgroundColor3 = UIKit.Color(tone or "Mustard", "Mustard"),
				Position = UDim2.new(0, -22, 0, 0),
				Size = UDim2.new(0, 6, 1, 0),
				Parent = toast,
			})
			UIKit.Text({
				Text = text,
				weight = "Bold",
				size = "Body",
				TextTruncate = Enum.TextTruncate.None,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
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

	-- Leave race (top-left, under the Roblox menu buttons) ----------------------------------------------
	do
		local dock = UIKit.Dock({
			Name = "TopLeftDock",
			Position = UDim2.fromOffset(M, 64),
			Size = UDim2.fromOffset(170, 56),
			Parent = screenGui,
		})
		hud.leaveButton = UIKit.Button({
			Name = "LeaveRace",
			Text = "Leave race",
			variant = "danger",
			size = 20,
			Size = UDim2.fromOffset(160, 46),
			Visible = false,
			Parent = dock,
		})
	end

	-- Bottom-center: Ready card (lobby) and Boarding card (in a stop bay) ------------------------------
	do
		local dock = UIKit.Dock({
			Name = "BottomDock",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -M),
			Size = UDim2.fromOffset(470, 150),
			Parent = screenGui,
		})

		-- Ready
		local ready = UIKit.Panel({
			Name = "Ready",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(390, 142),
			padding = { 14, 18, 16, 18 },
			tape = { "TopLeft", "TopRight" },
			Parent = dock,
		})
		local readyTitle = UIKit.Brush({ Text = "Next race", size = 28, Size = UDim2.new(1, 0, 0, 34), Parent = ready })
		local readyStatus = UIKit.Text({
			size = "Small",
			color = "TextMuted",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 34),
			Parent = ready,
		})
		local readyButton = UIKit.Button({
			Name = "ReadyButton",
			Text = "Ready up",
			variant = "primary",
			size = 26,
			Size = UDim2.new(1, 0, 0, 54),
			Position = UDim2.new(0, 0, 1, -54),
			Parent = ready,
		})
		hud.ready = { panel = ready, title = readyTitle, status = readyStatus, button = readyButton }

		-- Boarding
		local board = UIKit.Panel({
			Name = "Boarding",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(470, 142),
			padding = 16,
			tape = { "TopLeft" },
			Visible = false,
			Parent = dock,
		})
		local left = UIKit.Frame({ Size = UDim2.new(1, -150, 1, 0), Parent = board })
		local title = UIKit.Brush({ size = 30, color = "Mustard", Size = UDim2.new(1, 0, 0, 34), Parent = left })
		local subtitle = UIKit.Text({
			size = "Small",
			color = "TextMuted",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 34),
			Parent = left,
		})
		UIKit.Caption({ Text = "Boarding rate", Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 58), Parent = left })
		local _, rateFill = UIKit.Bar({ Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 76), color = "Positive", Parent = left })
		local hint = UIKit.Text({
			size = "Small",
			weight = "Bold",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 92),
			Parent = left,
		})

		local button = UIKit.Button({
			Name = "BoardButton",
			Text = "",
			variant = "primary",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 136, 1, 0),
			Parent = board,
		})
		local keycap = UIKit.Frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.Colors.Ink,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(44, 44),
			Parent = button,
		})
		UIKit.Corner(keycap, Theme.Radius.Medium)
		UIKit.Text({
			Text = "E",
			size = 26,
			weight = "Heavy",
			color = "Mustard",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = keycap,
		})
		local buttonLabel = UIKit.Brush({
			Text = "Board",
			size = 24,
			color = "Ink",
			tilt = -1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 62),
			Size = UDim2.new(1, -12, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
		local boardedCount = UIKit.Text({
			size = "Caption",
			weight = "Heavy",
			color = "Ink",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 92),
			Size = UDim2.new(1, -12, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})

		hud.board = {
			panel = board,
			title = title,
			subtitle = subtitle,
			rateFill = rateFill,
			hint = hint,
			button = button,
			buttonLabel = buttonLabel,
			boardedCount = boardedCount,
		}
	end

	-- Bus card (bottom-left) ---------------------------------------------------------------------------
	do
		local dock = UIKit.Dock({
			Name = "BottomLeftDock",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, M, 1, -M),
			Size = UDim2.fromOffset(320, 160),
			Parent = screenGui,
		})
		local panel = UIKit.Panel({
			Name = "Bus",
			Size = UDim2.fromScale(1, 1),
			padding = 16,
			tape = { "TopRight" },
			Visible = false,
			Parent = dock,
		})

		local function meter(captionText, y, fillColor)
			UIKit.Caption({ Text = captionText, Size = UDim2.new(0.5, 0, 0, 16), Position = UDim2.fromOffset(0, y), Parent = panel })
			local value = UIKit.Text({
				size = "Body",
				weight = "Heavy",
				Size = UDim2.new(0.5, 0, 0, 18),
				Position = UDim2.new(0.5, 0, 0, y - 1),
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = panel,
			})
			local _, fill = UIKit.Bar({ Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, y + 20), color = fillColor, Parent = panel })
			return value, fill
		end

		local passengers, loadFill = meter("Passengers", 0, "Positive")
		local health, healthFill = meter("Health", 40, "Negative")
		local stats = UIKit.Text({
			size = "Small",
			color = "TextMuted",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 84),
			Parent = panel,
		})
		local problem = UIKit.Text({
			size = "Small",
			weight = "Bold",
			color = "Warning",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 106),
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
		local dock = UIKit.Dock({
			Name = "BottomRightDock",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -M, 1, -M),
			Size = UDim2.fromOffset(200, 124),
			Parent = screenGui,
		})
		local panel = UIKit.Panel({
			Name = "Speed",
			Size = UDim2.fromScale(1, 1),
			padding = { 8, 18, 12, 18 },
			tape = { "TopLeft" },
			Visible = false,
			Parent = dock,
		})

		local value = UIKit.Text({
			Text = "0",
			size = 66,
			weight = "Heavy",
			Size = UDim2.new(1, 0, 0, 70),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = panel,
		})
		UIKit.Caption({
			Text = "Studs / sec",
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.fromOffset(0, 72),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = panel,
		})
		local sliding = UIKit.Frame({
			BackgroundTransparency = 0.05,
			BackgroundColor3 = Theme.Colors.Tape,
			Size = UDim2.fromOffset(84, 22),
			Position = UDim2.fromOffset(0, 80),
			Rotation = -4,
			Visible = false,
			Parent = panel,
		})
		UIKit.Brush({
			Text = "Sliding!",
			size = 16,
			color = "Ink",
			tilt = 0,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = sliding,
		})

		hud.speed = { panel = panel, value = value, sliding = sliding }
	end

	-- Countdown (center) ---------------------------------------------------------------------------------------
	do
		local dock = UIKit.Dock({
			Name = "CountdownDock",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.38),
			Size = UDim2.fromOffset(420, 180),
			Parent = screenGui,
		})
		local label = UIKit.Brush({
			Name = "Countdown",
			size = "Hero",
			tilt = -4,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.55,
			Visible = false,
			Parent = dock,
		})
		local pop = Instance.new("UIScale")
		pop.Parent = label
		hud.countdown = { label = label, pop = pop }
	end

	-- Results (center) -------------------------------------------------------------------------------------------
	do
		local dock = UIKit.Dock({
			Name = "ResultsDock",
			fitHeight = 0.8,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(460, 500),
			Parent = screenGui,
		})
		local panel = UIKit.Panel({
			Name = "Results",
			Size = UDim2.fromScale(1, 1),
			padding = 24,
			tape = { "TopLeft", "TopRight" },
			Visible = false,
			Parent = dock,
		})

		UIKit.Brush({ Text = "Route complete", size = 32, color = "Mustard", Size = UDim2.new(1, 0, 0, 38), Parent = panel })
		local total = UIKit.Text({
			size = 46,
			weight = "Heavy",
			color = "Cash",
			Size = UDim2.new(1, 0, 0, 50),
			Position = UDim2.fromOffset(0, 40),
			Parent = panel,
		})
		UIKit.Text({
			Text = "earned this run",
			size = "Small",
			color = "TextMuted",
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 88),
			Parent = panel,
		})
		divider(panel, { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.fromOffset(0, 116) })

		local rows = UIKit.Frame({ Size = UDim2.new(1, 0, 1, -160), Position = UDim2.fromOffset(0, 128), Parent = panel })
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
				color = tone or "TextMuted",
				weight = tone and "Bold" or "Medium",
				Size = UDim2.new(0.62, 0, 1, 0),
				Parent = row,
			})
			UIKit.Text({
				Text = valueText or "",
				weight = "Heavy",
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
