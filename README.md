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
4. Press Play. You spawn in the lobby. Click **Ready up** (bottom-left) to
   join the next race; players who aren't Ready just stay in the lobby.

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
| `/skip` | end the current session phase now (also marks you Ready) |
| `/hp N` | set your bus's health to N% during a route (preview damage effects) |
| `/map ID` | vote for a track layout; no argument lists the ids |

### Controls

| | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Throttle / brake-reverse | W / S | left stick | thumbstick |
| Steer | A / D | left stick | thumbstick |
| Handbrake | Space | X | — |
| Board passengers (inside a stop bay) | press or hold E | A | Board button |
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

- **Map vote:** the lobby panel above the Ready card lists the track layouts;
  click one to vote, click it again to take your vote back. The tally is live
  for everyone. The vote closes the moment the countdown starts, so a late
  voter still counts, and both bracket tracks always use the same layout.
  Nobody voting (or a tie) keeps the default City Loop, so an idle server
  behaves exactly as it always has.

  | Layout | Road | Edges |
  | --- | --- | --- |
  | City Loop | 2 lanes | hard curbs |
  | Wide Boulevard | 4 lanes | **no curbs** — off-road gets you towed back |
  | Hill Circuit | 2 lanes | hard curbs, two climbs and two descents |

  Layouts live in `TrackLayouts.lua`: a name, a road width, whether to build
  curbs, how many grid columns, and one function returning the closed ring of
  points. Adding a fourth is that table plus a `points()`.
- **Tow-back:** on a layout built without curbs there is no wall to stop you
  leaving the road. Drift off for more than `OffRoad.GraceSeconds` (1.5s) and
  a tow puts you back on the tarmac, frozen for a couple of seconds — longer
  the faster you were going, capped. It is a time penalty, not damage: no
  health lost and no passengers lost, so it always stays cheaper than a
  breakdown. Getting shoved off by another bus within the last 2s doesn't
  count, so ramming someone into the grass isn't a free win.
- **Ready up:** only players who click **Ready** race. Everyone else stays
  in the lobby (garage available).
  - At least `MinReadyToStart` (1) player must be Ready. If the 30s
    intermission runs out with nobody Ready, the server waits. Once someone
    readies up, a 10s countdown starts.
  - If every player in the server is Ready, the race starts after 3s.
  - Readying up *during* a race drops you straight in (unless under 20s are
    left). **Leave race** sends you back to the lobby, paid for what you've
    delivered so far.
  - Ready players stay Ready round after round. Racers who sat idle for a
    whole race (barely drove, delivered nobody) are set back to Not Ready.
  - All of this is tunable in `RouteConfig.lua` → *Ready-up*.
- **Stops:** every stop is a glowing rectangular bay in the left lane. Steer
  the bus into it (it's narrower than the road). You don't have to stop:
  - **Boarding:** drive through and press or hold **E** to board passengers.
    Your speed through the bay sets how many you may pick up there:

    | Speed | You can pick up |
    | --- | --- |
    | 30 mph or under | 2 |
    | 20 mph or under | 4 |
    | 10 mph or under | as many as the bus will hold |
    | over 30 mph | nobody |

    The cap counts everyone boarded during that visit, so you can take 2 at
    30, brake to 20 and take 2 more. That's the trade-off: blast through at
    30 when you only need to shed one passenger, or slow right down and pay
    the time to fill the bus.
  - **Waiting passengers:** each stop still has a limited queue that refills
    over time.
  - **Drop-offs:** passengers for that stop get off automatically while you're
    in the bay at 30 mph or under. They pay `FareBase + FarePerStop × stops
    travelled`, plus 25% if delivered before their deadline.
  - **Speedometer:** the bottom-right dial reads in mph, and its tick marks
    are coloured by those tiers, so you can see what the bay is worth at your
    current speed without doing the arithmetic.
  - All of this is tunable in `RouteConfig.lua` → *Boarding on the move*.
  - **Stop list:** the left edge of the screen lists the stops coming up on
    your track, visible only to you: how many people are waiting, how far
    away each one is, how many of *your* passengers get off there, and a
    live countdown to their deadline (amber when close, red when late).
    Stops you owe a drop-off to stay listed even once you've passed them,
    and the most urgent one gets a yellow border.
- **Load:** each passenger pushes the bus toward the full-load penalties
  (−15% top speed, −35% accel, −30% brakes, −40% grip). Handles upgrades
  soften the grip penalty.
- **Collisions:** an impact needs both a sharp slowdown and something solid
  (curb, obstacle, another bus) touching the bus. Damage is reduced by the
  Health upgrade. At 0 HP the bus breaks down for 5s and 25% of passengers
  walk off. Any collision resets your clean streak and cancels the
  clean-run bonus.
- **Damage visuals:** below 70% health a bus starts smoking from the hood and
  turns red. Both get gradually stronger as health drops, with flames under
  25% and a pulsing tint when critical. Tune in `Shared/Config/DamageEffectsConfig.lua`.
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
    Config/RestorationConfig.lua     which upgrade unrusts which part of the bus, at which levels
    Modules/BusRestoration.lua       swaps rusted parts for pristine ones on a built bus
    Modules/BusBuilder.lua           builds a tier's bus: Root + visuals + one Attachment per category
    Modules/BusUpgradeApplier.lua    welds/unwelds upgrade models onto a bus
    Modules/UpgradeModelProvider.lua (category, level) -> Model  (placeholder blocks)
    Modules/GarageLayout.lua         anchor CFrame -> camera/player/bus/behind CFrames
  Shared/
    Config/EconomyConfig.lua         cash, slot prices, rep thresholds, XP curve, run rewards
    Config/DrivingConfig.lua         upgrade gains, load penalties, controller + collision tuning
    Config/RouteConfig.lua           phase timings, track generation, stops/passengers, brackets
    Config/TrackLayouts.lua          the selectable track layouts (road width, curbs, shape)
    Config/DamageEffectsConfig.lua   smoke / red tint / flames thresholds for damaged buses
    Modules/Restoration.lua          pure math: restoration slices, % restored, fare bonus
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
  RouteServer/TrackBuilder.lua              builds a track (RouteMap template or a TrackLayouts layout)
  RouteServer/MapVoteService.lua            lobby map vote: per-player votes, tally, winner
  RouteServer/BusSpawner.lua                spawn/seat/release/reset/despawn buses
  RouteServer/BusMonitor.lua                server collisions, breakdowns, anti-cheat resets
  RouteServer/PassengerService.lua          stop queues, boarding, drop-offs, fares
  RouteServer/RunScoring.lua                per-run stats -> payout + RunResults
  RouteServer/BracketService.lua            groups players into bracket tracks
  RouteServer/ReadyService.lua              who is Ready (player attribute), SetReady remote

src/StarterPlayer/StarterPlayerScripts/
  GarageClient/GarageController.client.lua  local garage scene + GUI wiring
  GarageClient/GarageGuiBuilder.lua         builds the garage GUI
  GarageClient/GarageSwapSequence.lua       jump / smoke / swap animation
  RouteClient/RouteClient.client.lua        HUD, boarding, results, starts driving + camera
  RouteClient/RouteHudBuilder.lua           builds the route HUD
  RouteClient/BusDriveController.lua        arcade driving physics (client-owned)
  RouteClient/ChaseCamera.lua               follow camera
  RouteClient/BusDamageEffects.client.lua   smoke, red tint and flames on damaged buses
  RouteClient/StopPanel.lua                 per-player stop list (left edge): waiting, your drop-offs, deadlines
  UI/UITheme.lua                            design tokens: colors, fonts, text sizes, radii, spacing
  UI/UIKit.lua                              UI components (panels, text, buttons, bars, stats, scaling)
  UI/Format.lua                             cash / time / count formatting

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
| Real bus models | put a Model named `Tier1`–`Tier4` in `ReplicatedStorage.GarageAssets.Buses` (see *Using your bus models*) |
| A real garage room | add `Workspace.GarageScene.GarageAnchor` (Part) |
| A real lobby | add `Workspace.Lobby` with a SpawnLocation |
| A hand-built route | add `Workspace.RouteMap` (Model); tag stop parts `RouteStop` + `Index` attribute, optional grid parts `RouteGrid` + `Index` |
| Cross-server matchmaking | replace `BracketService.Assign()` |
| Retime the garage swap animation | `TIMING` in `GarageSwapSequence.lua` |
| Restyle the garage / HUD / stop cards (plain original style) | `GarageGuiBuilder.lua`, `RouteHudBuilder.lua`, `StopPanel.lua` |
| Resize stop bays | `RouteConfig.StopBayWidth` / `StopBayLength` / `StopGlowHeight` |
| Add a track layout to the vote | `TrackLayouts.lua` (one table entry + a `points()` returning a closed ring) |
| Retune the off-road tow penalty | `DrivingConfig.OffRoad` |
| Upgrade names changed in the spreadsheet | regenerate `UpgradeCatalog.lua` (don't hand-edit) |

## Using your bus models

`BusBuilder` uses real models for any tier that has them and a block
placeholder for tiers that don't. It works for both the garage and the
drivable bus.

### Rusted → pristine buses (two models per tier)

1. In Studio, create a **Folder** named after the tier (`Tier1` … `Tier4`)
   inside **ReplicatedStorage → GarageAssets → Buses**. This folder is set to
   `ignoreUnknownInstances`, so Rojo won't delete what you put there.
2. Put the two models inside it, named exactly **`Rusted`** and **`Pristine`**:
   ```
   ReplicatedStorage/GarageAssets/Buses/Tier1/
     Rusted     (Model)
     Pristine   (Model)
   ```
   They don't need to be in the same spot; each is centered automatically
   and their wheel bottoms are lined up. They should be the same size and
   face the same way.
3. **Share it with the team:** right-click the `Tier1` folder → *Save to File…* →
   save as `src/ReplicatedStorage/GarageAssets/Buses/Tier1.rbxm` and commit it.

As upgrades level up, parts of the rusted bus are swapped for the matching
parts of the pristine one. **Which upgrade restores which area, and at which
levels, is set in `GarageSystem/Config/RestorationConfig.lua`:**

| Upgrade | Area it restores (default) | Levels (default) |
|---|---|---|
| Brakes | wheels & undercarriage | 1, 3, 5, 7, 9 |
| Handles | roof | 1, 3, 5, 7, 9 |
| Engine | front & engine | 1, 3, 5, 7, 9 |
| Accel | rear | 1, 3, 5, 7, 9 |
| Health | body panels | every level |

Each number in `levels` unrusts the next slice of that area, so `{ 2, 5, 9 }`
means three slices at levels 2, 5 and 9. To hand-pick instead, set
`RestoreLevel` (number) and optionally `RestoreCategory` (e.g. `"Engine"`)
attributes on a part, or on a Model/Folder grouping parts, **in both**
models. A more restored bus also earns higher fares: up to
`MaxFareBonus` (+25%) when fully pristine.

### A single model per tier

Put one Model named `Tier1` (etc.) straight into `GarageAssets/Buses`. It's
always shown as-is, with the placeholder upgrade blocks attached.

The model doesn't need any setup: it's centered, fitted with an invisible
collision box, welded, and made non-colliding automatically, and scripts
inside it are removed. Optional tweaks (attributes on the Model):

| Attribute | Default | Use when... |
|---|---|---|
| `FrontAxis` | `"-Z"` | the bus drives backwards or sideways; try `"+Z"`, `"+X"`, `"-X"` |
| `Scale` | `1` | the bus is too big or small |
| `RideHeight` | 15% of height | the bus floats or sinks into the road |

Optional children: `Attachment`s named `Engine`/`Accel`/`Brakes`/`Handles`/`Health`
(where upgrade parts attach) and a `Seat` named `DriverSeat` (where the driver sits).

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
