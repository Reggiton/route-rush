# Route Rush — Garage System

A self-contained, config-driven garage GUI: press a button, camera moves to
a garage scene with your avatar in front of your bus, adjust placeholder
+/- upgrades per stat, hit Confirm, and your avatar jumps behind the bus,
a smoke cloud rolls in, and the bus comes back out with the new upgrade
models loaded (and the old ones gone).

Nothing here depends on a leveling/reputation/cash system yet — every
level 0–9 is currently free to pick. The spots where that gating will
plug in later are marked `TODO(gating)`.

## File map (and what each one is for)

```
src/ReplicatedStorage/GarageSystem/
  Config/UpgradeConfig.lua        <- categories, min/max level, chassis tiers
  Modules/UpgradeModelProvider.lua<- (category, level) -> Model (placeholder block for now)
  Modules/BusBuilder.lua          <- builds a bus + one attachment point per category
  Modules/BusUpgradeApplier.lua   <- welds/unwelds upgrade models onto a bus

src/ServerScriptService/GarageServer/
  RemotesBootstrap.server.lua     <- creates all RemoteEvents (only place that does)
  GarageService.server.lua        <- per-player garage stalls, upgrade state, remote handlers
  GarageSwapSequence.lua          <- the jump / smoke / swap / return animation

src/StarterPlayer/StarterPlayerScripts/GarageClient/
  GarageGuiBuilder.lua            <- builds the GUI from UpgradeConfig.Categories
  GarageController.client.lua     <- wires GUI <-> camera <-> remotes
```

Each file has exactly one job. If something needs to change, there's one
obvious place to change it (see "How to extend" below).

## Installing

**Recommended: Rojo.** `default.project.json` is already set up. Install
the [Rojo](https://rojo.space) plugin in Studio, run `rojo serve` from
this folder, and connect from the plugin. Every `.server.lua` becomes a
`Script`, every `.client.lua` becomes a `LocalScript`, and every plain
`.lua` becomes a `ModuleScript`, in the right service automatically.

**Manual (no Rojo):** create these instances in Studio's Explorer and
paste the matching file's contents in:

| File | Instance type | Parent |
|---|---|---|
| `Config/UpgradeConfig.lua` | ModuleScript named `UpgradeConfig` | `ReplicatedStorage/GarageSystem/Config` (Folders) |
| `Modules/UpgradeModelProvider.lua` | ModuleScript | `ReplicatedStorage/GarageSystem/Modules` |
| `Modules/BusBuilder.lua` | ModuleScript | `ReplicatedStorage/GarageSystem/Modules` |
| `Modules/BusUpgradeApplier.lua` | ModuleScript | `ReplicatedStorage/GarageSystem/Modules` |
| `RemotesBootstrap.server.lua` | Script | `ServerScriptService/GarageServer` |
| `GarageService.server.lua` | Script | `ServerScriptService/GarageServer` |
| `GarageSwapSequence.lua` | ModuleScript | `ServerScriptService/GarageServer` |
| `GarageGuiBuilder.lua` | ModuleScript | `StarterPlayer/StarterPlayerScripts/GarageClient` |
| `GarageController.client.lua` | LocalScript | `StarterPlayer/StarterPlayerScripts/GarageClient` |

Everything else (RemoteEvents, the GUI, the bus, the garage stalls) is
built by these scripts at runtime — there's nothing else to place by hand.

## How to extend it later

- **Add/remove/rename an upgrade category** → edit `UpgradeConfig.Categories`
  only. The GUI, the bus attachment points, and the server state all pick
  it up automatically.
- **Change max upgrade level** → edit `UpgradeConfig.MaxLevel`.
- **Swap placeholder blocks for real models** → edit
  `UpgradeModelProvider.GetModel()` only, to clone your real asset instead
  of generating a block. Nothing else needs to know.
- **Replace the placeholder bus with a real modeled one** → edit
  `BusBuilder.BuildBaseBus()`. It just needs to keep a `PrimaryPart` and
  one `Attachment` per category, named after the category.
- **Add chassis tiers 2–4** → add entries to `UpgradeConfig.ChassisTiers`
  and extend `BusBuilder.BuildBaseBus()` to branch on `chassisId`.
- **Add reputation/cash gating** → the two `TODO(gating)` comments in
  `GarageService.server.lua` are exactly where to reject a level change
  or charge cash on confirm.
- **Retime the smoke/jump sequence** → the `TIMING` table at the top of
  `GarageSwapSequence.lua`.

## Known simplifications (by design, for this first pass)

- Upgrade "models" are colored placeholder blocks with a floating label —
  swap-ready per `UpgradeModelProvider.lua` above.
- No persistence yet — confirmed upgrades reset when the player leaves.
  `GarageService.server.lua` has a TODO marking where DataStore saving
  goes.
- Garage stalls are laid out in a simple line in `workspace.GarageScene`
  so multiple players can use the garage at once without colliding —
  replace with real map spawn points once the garage has art.
