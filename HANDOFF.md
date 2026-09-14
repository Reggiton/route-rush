# Route Rush — Handoff

Supersedes the earlier *Garage System Handoff*. This covers the finished garage
and the P0 Route Rush loop. For setup and the file map, see `README.md`.

## Status

| Area | State |
|---|---|
| Garage (client-only scene, 4 tiers, gating, respec, purchases) | Done, placeholder art |
| Player data (DataStore, session lock, autosave, leaderstats) | Done |
| Route session loop (intermission → countdown → run → results) | Done |
| Procedural track, stops, obstacles, lobby | Done, placeholder art |
| Arcade driving + load handling + chase camera | Done, first-pass tuning |
| Passengers, deadlines, fares, collisions, breakdowns | Done, first-pass tuning |
| Reputation / XP / Level / payout | Done, first-pass formulas |
| Driving Power Score + in-server bracket split | Done |
| Upgrade names from spreadsheet | Done (generated `UpgradeCatalog.lua`) |
| Everything in "Not built yet" (README) | Not started |

Everything was checked outside Studio (Luau syntax on all files, 195+ unit
tests on the pure math, and `rojo build`). **It has not been play-tested in
Studio yet.** Run the checklist below first; physics feel and balance numbers
will need a tuning pass.

## Key decisions (and why)

- **Client-only garage scene.** Unchanged from before: the avatar clone and
  display bus only exist on your client, so garages can't overlap or be seen by
  others. The server only validates levels and charges cash.
- **One full "garage state" payload.** Every garage remote (`GarageReady`,
  `PendingLevelUpdated`, `ChassisPreviewUpdated`, `UpgradesConfirmed`) sends the
  same table built by `buildState` in `GarageService.server.lua`. The client
  just re-renders it, so the UI can't drift from the server.
- **Slot prices depend only on slot index.** The *n*-th filled slot on a chassis
  always costs the same, so refunds (sell the top slots at 60%) need no
  purchase history. See `Progression.QuoteChange`.
- **Pending levels reset when you open or close the garage.** This fixes the old
  bug where unconfirmed changes survived a close and got committed later.
- **Arcade physics on the driver's client.** The server gives each bus's network
  ownership to its driver, and `BusDriveController` drives it with a `LinearVelocity` + `AlignOrientation`
  hover. The server never trusts the client for money: stops, boarding,
  fares, and collisions are all judged server-side from the replicated motion
  (`PassengerService`, `BusMonitor`).
- **Collisions are detected from speed drops, not `Touched`.** A drop larger than the bus's own
  brakes could produce is an impact. It's reliable for client-owned
  assemblies and doubles as a sanity check.
- **Brackets split tracks inside one server.** Real cross-server matchmaking can't be
  tested in Studio; `BracketService.Assign()` is the single seam to replace.
- **Traffic drives on the left** (Bangladesh), so stops are on the left lane.
- **Balance numbers are guesses.** The Build Plan leaves the rep formula,
  weight-vs-handling scaling, and costs open. Every number is in `Shared/Config`.

## Gotchas already hit (so you don't re-debug them)

- **`Character:Clone()` returns nil** unless `Archivable = true` first
  (handled in `GarageController`).
- **Move characters with `Model:PivotTo`**, not `HumanoidRootPart.CFrame`; the
  joints fight direct CFrame writes. The swap sequence now tweens a
  NumberValue and pivots along an arc.
- **Disable buttons with `GuiButton.Interactable`**, not `Active`; `Active = false`
  still lets clicks fire.
- **`SetNetworkOwner` errors on anchored assemblies.** Buses spawn anchored for the
  countdown, and `BusSpawner.Release` unanchors *before* handing ownership.
- **DataStores in Studio** need *Enable Studio Access to API Services*.
  Otherwise `PlayerDataService` logs a warning and gives a non-saving profile.
- **Session lock:** if you stop a Studio test abruptly and rejoin within
  seconds, your profile can still be locked. The loader retries for about 20s,
  then kicks with a "rejoin" message. A lock older than 15 minutes is ignored.
- **Rojo:** CLI and Studio plugin versions must be close. Don't mix a Rojo/Git
  workflow with Team Create on the same place.

## Manual test checklist (Studio)

1. **Solo Play.** Lobby spawn, and the top bar shows "Next route in 0:30".
2. **Garage.** Open it; +/- respect the 5 starting slots and the quote line updates.
   Confirm charges cash and plays the jump/smoke swap. Then:
   - `/rep 5000` + `/cash 99999`: more slots unlock.
   - Lower a level, confirm, and check the refund is 60% of that slot's price.
   - Press `>` to Tier 2: locked until `/xp 2000` (Lv5), then "Buy", and the display
     bus changes.
   - Stop, Play again: purchases persist (needs API access).
3. **Round.** `/skip` to start. Countdown shows you seated in your bus on the grid,
   and the garage closes. At GO:
   - Drive to a yellow stop zone and board with E without stopping. Check the
     speed tiers on the speedometer: roll through at ~30 mph and you get 2,
     brake to ~20 for 4, crawl at ~10 for the whole crowd, and above 30 mph
     nobody boards or gets off. Handling gets worse as load rises.
   - Deliver passengers: a "+$" toast, and on-time bonuses before the deadline.
   - Ram an obstacle: HP drops. At 0 you break down and lose passengers.
   - `/skip` to end: results screen with cash/rep/XP, respawn in the lobby, and
     the leaderstats update.
4. **Local Server, 4 players** (Test tab). Give two players `/cash 99999`
   `/rep 99999` and max a few stats (Power Score ≥ 30). Next round should build
   **two** tracks. With only one high-score player, everyone shares one track.
   Check that stop queues are shared (first to arrive gets first pick) and
   that no one sees another player's garage.
5. **Resilience.** Leave mid-round (bus despawns, no errors); die/reset mid-round
   (you get re-seated); fall off the map or flip over (bus resets to the road).

## Where future systems plug in

| System | Seam |
|---|---|
| Route Wars weapons | new `RouteServer/WeaponService`; `BusMonitor` already applies damage/breakdowns |
| Combat Power Score | `PowerScore.Combat()` next to `Driving()` |
| Level-10 Route Wars gate | `Progression.LevelFromXP` + a new mode check in `RouteSession` |
| Weather / hazards | `RouteConfig` modifiers read by `TrackBuilder` + `BusStats.Compute` |
| AI rival buses | a server driver that spawns through `BusSpawner` |
| VIP / family passengers | passenger fields in `PassengerService.makePassenger` + `Progression.Fare` |
| Underdog bonus | `Progression.RunPayout` (bracket position available via `BracketService`) |
| Respec tokens (monetization) | `GarageService` confirm handler (refund rate from `EconomyConfig`) |
| Real upgrade / bus / garage / lobby / route art | see README → Extending |

## Git / Rojo workflow reminder

- Each person runs their own `rojo serve` into their own Studio session.
- Share changes through Git (`git add` → `commit` → `push`; others `pull`, and
  their running `rojo serve` picks the changes up).
- `UpgradeCatalog.lua` is generated from the spreadsheet; regenerate it rather
  than hand-editing when the spreadsheet changes.
