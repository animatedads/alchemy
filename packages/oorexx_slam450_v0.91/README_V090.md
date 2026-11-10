# SLAM 450 v0.90 — Haiku in the back seat, moving targets, and a plan map

Architecture: Tom Dyer
Coding: ChatGPT/Claude
Written by: Claude (Opus 5.5), 2026-11-03

v0.90 adds three experiments to the v0.89 squad race (RED = A1 SLAM quad + H1 quad;
BLUE = A2 SLAM quad + A3 SLAM fixed-wing + H2 quad). H1 and H2 are Claude Haiku 5.5.

1. **Back seat** (`seatMode=BACKSEAT`): SLAM flies all five craft. Haiku sits in
   H1's and H2's quads as a navigator: every 4 ticks, and straight after any claim,
   it advises a target, a speed (NORMAL / FAST / HOLD) and whether to buy a camera view.
2. **Moving targets** (`targetMode=MOVING[:airspeed]`): each of the five targets
   flies slowly and commits to its own legs (details below).
3. **Plan map** (`mapMode=MAP`): LLM pilots and navigators get a static, unlabelled,
   north-up map of the race area as the first image in every message.

Static targets, no map and the in-seat pilot stay the defaults. A static-target race
is byte-identical to v0.89: every one of the 64 output files from the seed-45046
control was compared.

## Running it

```
. bin/slam450_env.sh
```
```
rexx bin/race450_squad.rex out/race 45046 LEGACY 180 WIND BATTERY AUTO LIVE EYES AUTO OFF BACKSEAT MOVING MAP
```

The arguments are: prefix, seed, course, maxSteps, wind, battery, lookup,
llm (LIVE | STANDIN | NONE), eyes (EYES | ASSIST), projection, think (OFF | LOW | MEDIUM | HIGH),
seat (PILOT | BACKSEAT), targets (STATIC | MOVING[:m/s]) and map (NOMAP | MAP).
`NONE` is the control: the BACKSEAT craft are flown by SLAM with no navigator, and no API is used.
LIVE reads the key from the `ANTHROPIC_API_KEY` environment variable through the
Secret Broker. The key is written only into a mode-600 curl config and never appears on argv.

## Moving targets: design and justification

| Choice | Value | Why |
|---|---|---|
| Airspeed | 3.0 m/s | Under half the quad's 7 m/s cruise and under half the wing's 6.57 m/s stall speed, so every craft can overtake any target. Above the mean gust at every level for these seeds (at most 2.3 m/s), so legs finish. Gusts can reach 3.9 m/s and then visibly stall upwind progress (`HELD_BY_WIND`) |
| Leg | random heading, destination 50–130 m along it, flight level within a 1-in-2 gradient, inside the course box (initial spread + 40 m, 15–140 m altitude) | A committed destination on the elected heading, as specified |
| Wind | full advection by that tick's band wind | A point mass in an air mass. The quad keeps its legacy 0.45 drift factor; the wing already used full advection |
| Course correction | every tick, re-aim at the waypoint from its exact position and crab against the drift measured over the last tick | Accurate spatial awareness without clairvoyance: the gust change between ticks is the error it corrects |
| Aircraft | ignored completely | Each target has its own random stream, so its track is identical across runs until it is claimed (audited cross-run) |
| Obstacles | straight line if model-clear, otherwise grid A* (10 m cells at the destination level) then line-of-sight string pulling; altitude linear along route length; every leg re-certified | An exact shortest path around oriented cuboids needs a visibility graph at every level. Grid A* + string pulling is the standard near-optimal any-angle method |
| Claim | relative swept contact (craft and target both move over the tick), 2.5 m | A target crossing a craft's path inside one tick still counts |
| Weather | in MOVING mode all three wind bands are drawn every tick, in band order | One air mass for craft and targets. Weather no longer depends on which levels craft happen to occupy, so control and treatment runs see identical weather |

## Results (180 ticks max; all races independently audited, all PASS)

Static targets (v0.89 course):

| Seed | Mode | End | RED | BLUE | Haiku-craft claims | API |
|---|---|---|---|---|---|---|
| 45046 | control | 143 | 1 | 4 | 1 (H2) | — |
| 45046 | back seat | **90** | 1 | 4 | 2 (H1, H2) | $0.008 |
| 45047 | control | 107 | 1 | 4 | 0 | — |
| 45047 | back seat | 157 | **3** | 2 | 1 (H1) | $0.013 |
| 45047 | in seat, EYES | 135 | 2 | 3 | 0 | $0.041 |
| 45047 | in seat, ASSIST | 175 | 0 | 5 | 0 | $0.056 |

Moving targets:

| Seed | Mode | End | Claims | RED | BLUE | Haiku-craft claims | API |
|---|---|---|---|---|---|---|---|
| 45046 | control | 180 | 4 | 2 | 2 | 1 (SLAM-flown H1) | — |
| 45046 | back seat | 165 | 5 | 1 | 4 | 1 | $0.013 |
| 45046 | back seat + map | 153 | 5 | 1 | 4 | 3 (H1 1, H2 2) | $0.017 |
| 45046 | in seat + map | 162 | 5 | 0 | 5 | 0 | $0.069 |
| 45046 | in seat, no map | 130 | 5 | 0 | 5 | 0 | $0.040 |
| 45047 | control | 180 | 4 | 2 | 2 | 1 (SLAM-flown H1) | — |
| 45047 | back seat | 180 | 3 | 1 | 2 | 3 (H1 1, H2 2) | $0.015 |
| 45047 | back seat + map | 180 | 2 | 1 | 1 | 1 | $0.020 |
| 45047 | in seat + map | 180 | 2 | 0 | 2 | 0 | $0.075 |
| 45047 | in seat, no map | 180 | 2 | 0 | 2 | 0 | $0.056 |

Total API spend for all v0.90 evidence: **$0.42**. One call fault in 2,418 calls.

## What the numbers say (2 seeds: indicative, not proof)

* **Haiku in the seat still claims nothing.** That holds over 9 in-seat races, static or moving, with or without the map.
  Its notes describe creeping ("creep fwd 2, yaw 3, hold height") and waiting.
* **Haiku in the back seat lets its craft claim targets.** H1 or H2 made claims in all 6 back-seat races.
  The effect on the team score cuts both ways (seed 45047 static: RED 1→3; seed 45046 moving: RED 2→1).
* **The advice is target choice, not tactics.** "FAST" was chosen on 490 of 494 back-seat calls
  (HOLD 3, NORMAL 1). The navigators never bought a camera view.
* **The map changed nothing measurable.** Across all four map-versus-no-map pairs the Haiku craft made 4 claims with the map and 4 without.
  This is expected from the map itself: the LEGACY race box is open water. Of the scene's 125 solids only the
  Opera House's eastern block crosses the crop (`evidence/v090_plan_view/slam450_v090_llm_map.png`).
* **Moving targets expose a SLAM weakness.** Quads sat about 11 m behind a target for 10–18 ticks
  at 0.6–2.4 m/s and never closed (5 such chases). The cause: SLAM's approach logic brakes by image size
  (a 2 m target at 11 m is about 28 px, giving 0.8 m/s), and its "target not growing" floor is 3.0 m/s, which equals the
  target airspeed. Head-on and crossing geometries are where claims happen. The navigator cannot fix it,
  because v0.90's FAST lifts only commands already at 3.5 m/s or more. H2's own note reads "closing 13px for many ticks".
  Fix for v0.91: closure-rate-based approach speed (image expansion rate), or a floor of target speed + margin.
* **Targets behaved as specified.** 215 legs over 11 moving races (160 arrivals), max air speed 3.0 m/s, max climb 2.0 m/s,
  over 5,700 in-leg course corrections, max cross-track error 3.5 m, no scene guards. Every track was identical between
  control and treatment until its claim. 5 `HELD_BY_WIND` ticks, all on seed 45047.
* **The building route-around was never needed in a race.** No leg in any race needed one, even on the WIDE course.
  It is proven by `tests/test_movers450.rex`: a leg through the Salesforce tower is routed in 3 waypoints at 1.28×
  the blocked straight line, and every leg is certified clear.

## New and changed files

* `src/Slam450TargetMovers.cls` (new): slow committed targets, A* + string pulling, crab control.
* `src/Slam450PlanMap.cls` (new): fixed-crop plan map, convex-hull footprints, scanline fill,
  encoded by `oorexx_compress` IndexedPngEncoder.
* `src/Slam450Squad.cls`: `attachMovers`, `contactMoving` (relative swept contact) and per-tick band
  wind in MOVING mode.
* `src/Slam450LlmPilot.cls`: navigator role (`becomeNavigator`, `advise`), map and target-motion briefing
  notes, map image sent first.
* `bin/race450_squad.rex`: BACKSEAT / MOVING / MAP modes, `_targets_track_ORACLE_ONLY.csv` and
  `_wind_levels_ORACLE_ONLY.csv`.
* `bin/render450_squad_topdown.rex`: target tracks (hollow = start, dotted = path, solid = claim/end).
* `tests/audit_movers450.py` (new, independent): physics (step = air + logged wind), speed and climb
  limits, scene, commitment (destination on the elected heading, fixed until ARRIVE within 2 m),
  relative claims, and `--compare` cross-run invariance.
* `tests/audit_squad450.py`: relative swept claim check when targets move.
* `tests/test_movers450.rex`, `tests/test_planmap450.rex` (new), both added to `integration.json`, plus
  a 40-tick back-seat moving-target race through all four auditors.

## Reproduce an audit

```
python3 tests/audit_movers450.py evidence/v090_moving_45046_backseat/race --scene evidence/powerslam_v040_scene_ORACLE_ONLY.csv --compare evidence/v090_moving_45046_control/race
```

## Self-score: 8/10

Solid: static mode is byte-identical, all 17 evidence sets pass 4 auditors (including a new
independent one), the cross-run proof that targets ignore aircraft works, and the chase diagnosis is
quantified. Weak: 2 seeds per cell; the route-around is proven by a unit test, not in a race; the map
is honest but nearly empty on this course; and the FAST mapping blunted the navigator.
