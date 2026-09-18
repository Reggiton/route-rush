---
name: roblox-ui
description: How to build and edit UI in the Route Rush Roblox game, using the project's own UIKit component library and UITheme design tokens. Use this skill whenever the work touches a ScreenGui, HUD, menu, panel, button, label, bar, icon, or any on-screen element — including any file named *HudBuilder.lua or *GuiBuilder.lua, anything under StarterPlayerScripts, and any request phrased as "make the UI look better", "add a button/panel/screen", "fix the layout", "it looks wrong on mobile", or "this is off-centre". Also use it before writing UI from scratch, since this repo has an existing component library and a screen-scaling system that new code must go through rather than reinventing.
---

# Route Rush UI

This game has a complete design system — `UI/UITheme.lua` (tokens) and `UI/UIKit.lua` (components +
screen scaling). Build every piece of UI through it.

That sounds like ordinary "use the design system" advice, but there's a specific trap here: several
existing builders (`RouteHudBuilder.lua`, `WarHudBuilder.lua`, `GarageGuiBuilder.lua`) each define
their *own* private `frame`/`label`/`button`/`corner`/`bar` helpers with hardcoded colours and fixed
pixel offsets. That happened because a styling revert took the UIKit wiring out along with the visual
style. Those files are the pattern to migrate away from, not the pattern to copy. If you open one and
see `local PANEL_BG = Color3.fromRGB(25, 25, 30)` at the top, you're looking at the old way.

Both modules live in `src/StarterPlayer/StarterPlayerScripts/UI/`.

## The props convention

Every UIKit constructor takes one table, and the casing tells you where a key goes:

- **PascalCase** keys are applied as real Roblox properties — `Size`, `Position`, `AnchorPoint`,
  `Name`, `Text`, `Visible`, `LayoutOrder`, `ZIndex`. `Parent` is always set last, so children are
  fully configured before they enter the tree.
- **lowercase** keys are UIKit options — `tone`, `padding`, `variant`, `size`, `weight`, `color`,
  `tape`, `tilt`, `icon`, `radius`, `stroke`.

```lua
UIKit.Panel({ Name = "Ready", Size = UDim2.fromOffset(260, 120), tone = "Panel", padding = 12 })
```

## Screen scaling: the part that's easy to get wrong

Roblox UI has no media queries. This repo solves responsiveness with `UIKit.Dock`: the UI is designed
at 1280×720 (`Theme.ReferenceResolution`) and a `UIScale` multiplies each dock to fit the real
viewport, clamped between `Theme.MinScale` and `Theme.MaxScale`.

The rule that follows from that: **group each screen corner into one Dock and put everything for that
corner inside it.** A dock scales around its own anchor, so its contents scale together and keep their
relative spacing. Scatter elements directly on the ScreenGui with raw offsets instead and they drift
apart, overlap on large monitors, and fall off the edge on phones — each one scaling (or not scaling)
independently.

```lua
local screen = UIKit.Screen("RouteHud", playerGui)

local bottomLeft = UIKit.Dock({
    Name = "BottomLeft",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, Theme.ScreenMargin, 1, -Theme.ScreenMargin),
    Size = UDim2.fromOffset(300, 260), -- design size at 1280x720
    Parent = screen,
})
-- Offsets INSIDE the dock are design-space; the dock handles the rest.
UIKit.Panel({ Size = UDim2.fromOffset(300, 120), Position = UDim2.fromOffset(0, 140), Parent = bottomLeft })
```

For a panel tall enough to risk running off a short screen, pass `fitHeight` so it never exceeds that
fraction of the viewport height:

```lua
UIKit.Dock({ ..., Size = UDim2.fromOffset(420, 520), fitHeight = 0.8 })
```

Note the `Position` offsets on the dock itself are *not* scaled — keep them small (a screen margin),
which is what `Theme.ScreenMargin` is for.

## Use tokens, never literals

A raw `Color3.fromRGB(...)` or a magic `14` in a builder is a bug waiting to happen: it won't follow
a theme change, and it quietly drifts from everything around it. Everything you need is already named:

| Need | Token |
|---|---|
| Colours | `Theme.Colors.Panel`, `.Text`, `.TextMuted`, `.Mustard`, `.Positive`, `.Negative`, `.Warning`, `.Accent`, `.Cash`, `.Rep` |
| Text size | `Theme.TextSize.Caption` 12, `.Small` 13, `.Body` 16, `.Title` 22, `.Stat` 22, `.Display` 30, `.Hero` 120 |
| Spacing | `Theme.Spacing.XS` 4, `.S` 8, `.M` 12, `.L` 16, `.XL` 24 |
| Corner radius | `Theme.Radius.Small` 3, `.Medium` 4, `.Large` 6, `.Pill` |
| Screen edge gap | `Theme.ScreenMargin` 12 |
| Fonts | `Theme.Fonts.Brush` (Kalam, hand-painted), `.Regular`, `.Medium`, `.Bold`, `.Heavy` |

Component options take token *names* as strings — `color = "TextMuted"`, `tone = "Row"` — or a real
`Color3` when a value is computed (a lerp between two states, say).

## Set TextSize, don't use TextScaled

`TextScaled = true` fights the dock system. The dock is already scaling the element, so `TextScaled`
then re-fits the glyphs to whatever box it lands in — which means the same "body" text ends up at a
different size in every panel, and the type hierarchy dissolves. Set an explicit `size` from
`Theme.TextSize` and let the dock scale it:

```lua
UIKit.Text({ Text = "12 / 30", size = "Body", color = "Text", Parent = panel })
```

`UIKit.Text` defaults `TextTruncate` to `AtEnd`, so long strings clip rather than overflow. If a label
genuinely needs to wrap, set `TextWrapped = true` and give it the height to do so.

## Components

| Constructor | Use for | Key options |
|---|---|---|
| `UIKit.Panel` | Any surface | `tone` (`Panel`/`Row`/`Inset`), `padding`, `radius`, `stroke`, `tape` |
| `UIKit.Text` | Values, body copy | `size`, `weight`, `color` |
| `UIKit.Caption` | Small label over a value; uppercases for you | `size`, `color` |
| `UIKit.Brush` | Hand-painted headings (GARAGE, STOP 3) | `tilt` |
| `UIKit.Button` | Anything clickable | `variant`, `size`, `tilt` |
| `UIKit.Bar` → `(track, fill)` | Meters — health, XP, load | `color`, `trackColor` |
| `UIKit.Stat` → `(container, value, caption)` | Caption-over-value pairs | `caption`, `value`, `brush`, `align` |
| `UIKit.Icon` | Themed icon, `nil` if unset | `icon` (a `Theme.Icons` key) |
| `UIKit.List(parent, …)` | Auto layout | `direction`, `gap`, `align`, `valign` |

Button variants carry meaning — pick by role, not by colour:

- `primary` mustard paint, `success` green, `danger` red — painted, brush lettering, for actions
- `secondary` / `ghost` / `key` — dark hardware keys, for minor and repeated controls (`+`, `−`, `✕`)

`UIKit.Button` already handles hover, press-scale, and the disabled look. Drive enable/disable through
`button.Interactable`, not by recolouring it yourself, and swap roles at runtime with
`UIKit.SetVariant(button, "primary")`.

Move a bar with `UIKit.SetFill(fill, fraction, optionalColor)` — it tweens, and skips the tween for
sub-2% changes so a per-frame meter doesn't thrash.

## Builders build, controllers fill

The split already in use, worth keeping: `*HudBuilder.lua` / `*GuiBuilder.lua` **only construct** and
return a table of handles; `*Client.client.lua` holds the logic and writes values into those handles.
It keeps layout in one readable place and means a visual change never risks touching game logic.

When editing a builder, keep the returned handle table's shape identical unless you're updating the
client in the same pass — clients index specific keys (`hud.board.rateFill`, `hud.status.progress`,
`hud.hotbar.slots[id].count`).

## Per-frame discipline

HUD code runs on `RenderStepped`, so treat that loop as hot:

- Never create instances in it. Build once in the builder; show and hide with `Visible`.
- Animate with `UIKit.Tween` rather than setting properties every frame.
- Guard repeated writes, the way the speedometer does: `if value.Text ~= rounded then value.Text = rounded end`.
  Assigning the same string every frame still triggers property-change work.

## Touch and console

Roblox players are mostly on phones, so design for a thumb:

- Keep tap targets comfortably large — the painted `primary` buttons at `Theme.TextSize.Body` are
  about right; don't shrink interactive controls to caption size.
- Never let hover be the only thing that communicates state; it doesn't exist on touch.
- The bottom-centre is the driving thumb zone and already holds the boarding panel. Put new persistent
  UI along the edges instead.
- `UIKit.Screen` sets `IgnoreGuiInset = true`, so the very top of the screen sits under Roblox's own
  top bar — leave that strip clear of anything tappable.

## Art assets

`Theme.Images` and `Theme.Icons` hold uploaded `rbxassetid` values (source PNGs live in `assets/ui/`).
The textures are 9-sliced via `Theme.Slices`, and `UIKit.Panel` / `UIKit.Button` use them
automatically for the relevant tones and variants.

An empty id string falls back to the code-drawn version of the same look. That's deliberate and
useful, but it also means a *wrong* id fails silently and simply looks plain — so if a texture doesn't
appear, check the id rather than assuming the code is wrong. `UIKit.HasImage(slot)` tests a slot.

## Migrating an old builder

Working a file that still uses private helpers? Convert it rather than adding to it:

1. Delete its local `corner`/`frame`/`label`/`button`/`bar` helpers and its colour constants.
2. Group its elements by screen corner, one `UIKit.Dock` each.
3. Swap constructors for UIKit ones, mapping every literal to a token.
4. Replace `TextScaled = true` with an explicit `size`.
5. Keep the returned handle table byte-identical in shape, then re-check the matching client.

```lua
-- Before
local panel = frame(screenGui, "Ready", UDim2.fromOffset(260, 120), UDim2.new(0, 20, 1, -140), {
    BackgroundTransparency = 0.15,
})
corner(panel)
local title = label(panel, "Title", "Next race", UDim2.fromOffset(240, 24), UDim2.fromOffset(10, 8), {
    TextXAlignment = Enum.TextXAlignment.Left,
})

-- After
local panel = UIKit.Panel({ Name = "Ready", Size = UDim2.fromOffset(260, 120), tone = "Panel", padding = 10, Parent = bottomLeft })
local title = UIKit.Text({ Name = "Title", Text = "Next race", size = "Title", weight = "Bold", Parent = panel })
```

## Checking your work

There's no way to see the result from the terminal, so verify what you can and be honest about the
rest. `luau-analyze <file>` catches syntax errors (ignore the `Unknown global` noise for `game`,
`workspace`, `Instance` — it has no Roblox type definitions). Everything visual needs Studio, and
resolution problems only show up when the window is actually resized: check a phone aspect ratio and a
large monitor, not just the default window.
