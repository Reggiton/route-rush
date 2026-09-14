# Route Rush UI images

Textures and icons for the garage-grunge UI, made to match the garage concept
art (`bbd_ui_ref.png`).

- `icons/`: cut straight from the concept art as white glyphs on transparent
  backgrounds. The game tints them with `ImageColor3`.
- `textures/`: rebuilt from colors sampled out of the art, so they have no baked-in
  text and scale cleanly. They're rendered at **3×** the size they appear on screen.

The game works without these; anything not uploaded falls back to a
code-drawn version. **Upload them for the real look.**

## 1. Upload

Studio → **View → Asset Manager** → **Bulk Import** → select every PNG in
`textures/` and `icons/`. Or upload each one on the Creator Hub under
*Development Items → Decals*.

For each image, copy its id: right-click it in Asset Manager →
*Copy ID to Clipboard*. It looks like `rbxassetid://1234567890`.

## 2. Paste the ids

Open `src/StarterPlayer/StarterPlayerScripts/UI/UITheme.lua` and fill in:

| `Theme.Images` / `Theme.Icons` key | File |
|---|---|
| `Images.PanelFrame` | `textures/panel.png` |
| `Images.PaintButton` | `textures/button_paint.png` |
| `Images.Tape` | `textures/tape.png` |
| `Images.BrushStrip` | `textures/brush_strip.png` |
| `Images.TopBar` | `textures/topbar.png` |
| `Icons.Garage` | `icons/garage.png` |
| `Icons.Timer` | `icons/timer.png` |
| `Icons.Map` | `icons/map.png` |
| `Icons.Missions` | `icons/missions.png` |
| `Icons.Settings` | `icons/settings.png` |
| `Icons.Engine` | `icons/engine.png` |
| `Icons.Accel` | `icons/accel.png` |
| `Icons.Brakes` | `icons/brakes.png` |
| `Icons.Handles` | `icons/handles.png` |
| `Icons.Health` | `icons/health.png` |
| `Icons.Wrench` | `icons/wrench.png` |
| `Icons.Crown` | `icons/crown.png` |

Commit `UITheme.lua` so everyone gets the ids.

## Replacing an image

Keep the same pixel size: textures at 3× their design size (panel 240×240,
button 900×162, tape 180×60, brush strip 1200×240, top bar 1680×138).
The 9-slice margins are in `Theme.Slices` (design pixels). If your
replacement's borders are a different width, change them there.
