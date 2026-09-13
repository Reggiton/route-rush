# Route Rush

A Roblox bus-racing game set on chaotic Bangladeshi city routes. Race rival
buses to each stop, choose how many passengers to cram aboard (more fares,
worse handling), deliver them for cash, and spend it upgrading your bus in
the garage.

This repo contains the **P0 core loop** from the Build Plan:

- **Garage**: a private, client-only scene. Upgrade 5 stats across 4 chassis
  tiers, with reputation-gated slots, cash costs, a 60% refund on respec,
  and chassis purchases.
- **Player data**: cash, reputation, XP/level, and per-chassis upgrades,
  saved to DataStores with session locking.
- **Route sessions**: server-wide rounds (intermission → countdown → 5-minute
  timed route → results) on a procedurally generated loop with 8 stops.
- **Driving**: an arcade bus controller where upgrades and passenger load
  change acceleration, braking, top speed and grip. Collisions cause damage
  and breakdowns.
- **Passengers and payout**: shared stop queues, drop-off deadlines, on-time
  and clean-run bonuses, and reputation computed from efficiency.
- **Fair lobbies**: the Driving Power Score splits the server into two
  bracket tracks when both brackets have enough players.

---

## Quick start

1. Install [Rojo](https://rojo.space) (CLI + Studio plugin, versions close to each other).
2. From this folder run `rojo serve`, then connect from the Studio plugin.
3. **Game Settings → Security → Enable Studio Access to API Services** (so
   progress saves in Studio; without it you get a working non-saving profile).
4. Press Play. You spawn in the lobby and the intermission timer runs.

Nothing needs to be placed by hand: the lobby, tracks, stops, buses, GUI and
remotes are all built at runtime. You can replace the placeholders with
real art later (see *Extending*).

### Studio dev commands (only work in Studio)

| Command | Effect |
|---|---|
| `/cash N` | add N cash (negative removes) |
| `/rep N` | add N reputation (unlocks slots) |
| `/xp N` | add N XP (unlocks chassis tiers) |
| `/resetdata` | wipe your profile |
| `/skip` | end the current session phase now |

### Controls

| | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Throttle / brake-reverse | W / S | left stick | thumbstick |
| Steer | A / D | left stick | thumbstick |
| Handbrake | Space | X | — |
| Board passengers | E (Z / X to change count) | A (D-pad to change count) | Board button |
| Toggle chase camera | C | R3 | — |

---

## How a session works

```
Intermission (30s) ──► Countdown (5s) ──► Running (300s) ──► Results (12s) ──┐
   lobby, garage open    tracks built,       drive, load,        payout,        │
                         buses spawned,      deliver             back to lobby  │
                         garage closed                                          │
      ▲─────────────────────────────────────────────────────────────────────────┘
```

- **Stops:** a bus is *at a stop* when it's inside the yellow zone and nearly
  stopped. Passengers for that stop get off automatically and pay
  `FareBase + FarePerStop × stops travelled`, plus 25% if delivered before
  their deadline. Boarding is your choice: pick how many to take.
- **Load:** each passenger pushes the bus toward the full-load penalties
  (−15% top speed, −35% accel, −30% brakes, −40% grip). Handles upgrades
  soften the grip penalty.
- **Collisions:** a speed drop larger than your brakes could cause counts
  as an impact. Damage is reduced by the Health upgrade. At 0 HP the bus
  breaks down for 5s and 25% of passengers walk off. Any collision resets
  your clean streak and cancels the clean-run bonus.
- **Payout:** fares + clean-run bonus as cash. Reputation =
  fares/min × on-time factor × clean-streak factor. XP is based on cash
  and deliveries.

## Progression rules

- **Reputation** is earned only by efficient driving. It unlocks skill
  slots in batches: 5 to start, +5 at each threshold, up to 45 per chassis.
- **Cash** fills unlocked slots. The *n*-th slot on a chassis costs
  `100 × tierMultiplier × 1.08^(n-1)`.
- **Respec:** lowering a level refunds 60% of that slot's price.
- **Player Level** (from XP) gates chassis purchases: Tier 2 at Lv5 ($5k),
  Tier 3 at Lv12 ($20k), Tier 4 at Lv20 ($60k).
- Confirming in the garage on a chassis you own also makes it the bus
  you drive.

---

## File map

```
src/ReplicatedStorage/
  GarageSystem/
    Config/UpgradeConfig.lua         categories, max level, chassis tiers (stats, prices, body shapes)
    Config/UpgradeCatalog.lua        GENERATED names/visuals for all 180 upgrades (from the spreadsheet)
    Config/GarageLayoutConfig.lua    garage camera/player/bus/behind offsets
    Modules/BusBuilder.lua           builds a tier's bus: Root + visuals + one Attachment per category
    Modules/BusUpgradeApplier.lua    welds/unwelds upgrade models onto a bus
    Modules/UpgradeModelProvider.lua (category, level) -> Model  (placeholder blocks)
    Modules/GarageLayout.lua         anchor CFrame -> camera/player/bus/behind CFrames
  Shared/
    Config/EconomyConfig.lua         cash, slot prices, rep thresholds, XP curve, run rewards
    Config/DrivingConfig.lua         upgrade gains, load penalties, controller + collision tuning
    Config/RouteConfig.lua           phase timings, track generation, stops/passengers, brackets
    Modules/Progression.lua          pure math: levels, slots, quotes/refunds, fares, payout, reputation
    Modules/BusStats.lua             pure math: (chassis, levels, passengers) -> driving stats
    Modules/PowerScore.lua           pure math: Driving Power Score + bracket

src/ServerScriptService/
  GarageServer/RemotesBootstrap.server.lua  creates every RemoteEvent (only place that does)
  GarageServer/GarageService.server.lua     validates garage changes, charges/refunds, buys chassis
  Services/PlayerDataService.lua            profiles: load/save/lock, leaderstats, ProfileUpdated
  Services/ServerSignals.lua                shared server BindableEvents
  DevTools/DevCommands.server.lua           Studio-only chat commands
  RouteServer/RouteSession.server.lua       the round state machine (entry point)
  RouteServer/LobbyBuilder.lua              finds or builds the lobby spawn
  RouteServer/TrackBuilder.lua              builds a track (RouteMap template or procedural loop)
  RouteServer/BusSpawner.lua                spawn/seat/release/reset/despawn buses
  RouteServer/BusMonitor.lua                server collisions, breakdowns, anti-cheat resets
  RouteServer/PassengerService.lua          stop queues, boarding, drop-offs, fares
  RouteServer/RunScoring.lua                per-run stats -> payout + RunResults
  RouteServer/BracketService.lua            groups players into bracket tracks

src/StarterPlayer/StarterPlayerScripts/
  GarageClient/GarageController.client.lua  local garage scene + GUI wiring
  GarageClient/GarageGuiBuilder.lua         builds the garage GUI
  GarageClient/GarageSwapSequence.lua       jump / smoke / swap animation
  RouteClient/RouteClient.client.lua        HUD, boarding, results, starts driving + camera
  RouteClient/RouteHudBuilder.lua           builds the route HUD
  RouteClient/BusDriveController.lua        arcade driving physics (client-owned)
  RouteClient/ChaseCamera.lua               follow camera

tools/test/                                 unit tests for the pure modules (see Testing)
```

One rule keeps this maintainable: **each file has one job, and every
tunable number lives in a Config file.**

## Extending

| Want to... | Edit only... |
|---|---|
| Rebalance prices, rep thresholds, XP, rewards | `Shared/Config/EconomyConfig.lua` |
| Rebalance driving, load, collisions | `Shared/Config/DrivingConfig.lua` |
| Change phase lengths, stop count, brackets | `Shared/Config/RouteConfig.lua` |
| Add/rename a category or change max level | `UpgradeConfig.Categories` / `MaxLevel` (+ `DrivingConfig.PerLevel`, `RouteConfig.PowerWeights`) |
| Add or retune a chassis tier | `UpgradeConfig.ChassisTiers` |
| Real upgrade models | `UpgradeModelProvider.GetModel()` |
| Real bus models | `BusBuilder.BuildBaseBus()` (keep the contract in its header) |
| A real garage room | add `Workspace.GarageScene.GarageAnchor` (Part) |
| A real lobby | add `Workspace.Lobby` with a SpawnLocation |
| A hand-built route | add `Workspace.RouteMap` (Model); tag stop parts `RouteStop` + `Index` attribute, optional grid parts `RouteGrid` + `Index` |
| Cross-server matchmaking | replace `BracketService.Assign()` |
| Retime the garage swap animation | `TIMING` in `GarageSwapSequence.lua` |
| Upgrade names changed in the spreadsheet | regenerate `UpgradeCatalog.lua` (don't hand-edit) |

## Testing

- **Unit tests** (pure modules: quotes/refunds, slots, levels, payout,
  stats, brackets): requires Node and the
  [Luau CLI](https://github.com/luau-lang/luau/releases).
  ```
  node tools/test/bundle.js src tools/test/bundle.lua
  luau tools/test/bundle.lua
  ```
- **Syntax:** `luau-compile --null <file>` on every `.lua`.
- **Build:** `rojo build default.project.json -o RouteRush.rbxlx`.
- **In Studio:** see `HANDOFF.md` → *Manual test checklist*.

## Not built yet (by design)

Route Wars (weapons), Ranked, weather/hazard modifiers, AI traffic and
rival buses, VIP/family passenger types, underdog bonuses, cross-server
matchmaking, real art, and monetization. The config and module boundaries
leave a spot for each (see `HANDOFF.md`).
