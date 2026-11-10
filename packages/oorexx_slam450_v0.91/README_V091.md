# SLAM 450 v0.91 — QUAYSIDE course on Power SLAM v0.40 real ground

Architecture: Tom Dyer
Coding: ChatGPT/Claude
Written by: Claude (Opus 5.5), 2026-11-03

v0.91 moves the race to an obstructed, larger field and puts it on real ground.

1. **QUAYSIDE course** (`course=QUAYSIDE`). A fixed 380 × 380 m field over Circular Quay
   (x −170..210, y −1190..−810; 1.43× the LEGACY target area), with targets at 8–60 m.
   It contains the Salesforce tower, wharves CQ2–CQ6, the station and Cahill expressway (plus its
   east extension) and the Cahill berm. At least 2 of the 5 targets must be hidden from the start.
   The start is over open water on the east side; moving targets stay inside the field.
2. **Real ground** (`groundMode=GROUND`). Power SLAM v0.40's 50 m AHD71 heights and the
   `harbour_water.words` L/W/X grid (PR #126) are loaded through the estate's own classes,
   wired exactly as the water README prescribes:
   `HarbourWordsRoleEvidence~setCell` for every L/W cell, then
   `HarbourWordsSceneTile~new(heights, 0.9, roles)`.
3. **Land in every pilot's panorama.** A new Maths v0.21 lane, `MathTerrainPanorama`, draws it.
4. **The LLM map shows real coastline and land.** Same rules as before: a fixed crop per course,
   north-up, unlabelled, no "you are here".

Defaults stay as before (`NOGROUND`, LEGACY). Byte-identity was checked file by file:
- a static LEGACY race is byte-identical to the v0.89 control;
- a QUAYSIDE race with `NOGROUND` is byte-identical to the boxes-only QUAYSIDE run.

## Ground design (with reasons)

| Choice | Why |
|---|---|
| **One surface, nearest cell** (the adapter's own rule): L = AHD height, W = sea at 0 m, X / nodata / outside = **no-fly** | Collision, target routing, sight lines, the panorama and the map all read the same surface, so nothing can be visible but not solid. Interpolating a resampled 50 m grid would invent detail. X fails closed, as the v0.22 tracer does |
| **Verified affine fast path** | `HarbourWordsSceneTile` runs a full TM projection per call, which is too slow for per-tick collision. Least squares on 49 adapter points gives max residual **0.25 m** over a 3 × 3 km region. At start-up, 392 random points match the adapter exactly on cell, role and height; 8 within the residual of a cell edge are excluded. The race refuses to start at ≥ 1 m |
| **Exact segment test** (DDA over the grid cells crossed) | The segment's lowest point in each crossed cell is compared with that cell's surface, so there are no sampling gaps. Craft and targets keep the scene's existing margins: 2 m on the centre line and on 2 m horizontal offsets |
| **Ground at construction** | Target generation and start slots must respect the ground. `Slam450World~new(seed, course, wind, ground)` |
| **Structures still drawn over land** | A hill does not hide a building behind it. This is rare at harbour level and is a documented limit |

The independent auditor (`tests/ground_audit450.py`) reads both words files itself and uses its
own GDA94 Transverse Mercator (Krüger series), not the race's affine. At Observatory Hill,
Fort Denison and the scene origin it matches the estate's `mgaOf` (Snyder) to the centimetre. It
samples every craft and target segment every ≤ 1 m on the centre line and the four offsets.
Within 1 m of a cell edge it uses the lower neighbouring cell, so a fault can never come from the
two projections picking neighbours.

## Results (180 ticks max; 2 seeds; 20 races; 80 / 80 audits PASS)

| | Seed 45046, boxes only | Seed 45046, real ground | Seed 45047, boxes only | Seed 45047, real ground |
|---|---|---|---|---|
| Control (SLAM flies all) | 3/5 @180 | 2/5 @180 | 5/5 @161 | 5/5 @161 |
| Haiku back seat | 5/5 @172 (A3/H1 collision) | **5/5 @118, H1 claims 2** | 3/5 @180 (A3/H2 collision) | **5/5 @116, H1 claims 1** |
| Back seat + map | 5/5 @125 | 5/5 @118, H1 claims 1 | 5/5 @118, H2 claims 1 | 3/5 @180 (A3/H1 collision) |
| Haiku in seat | 3/5, H1 and H2 hit scenery | 2/5, H1 hits ground | 5/5 @154, H2 hits scenery | 4/5 @180 |
| In seat + map | 3/5, H2 hits scenery | 3/5, H2 into the sea | 5/5 @93 (A1/H1 collision) | 5/5 @122 |

API: boxes-only $0.17 (920 calls, 1 fault); real ground $0.24 (1,338 calls, 0 faults).

**Findings, for 2 seeds** (indicative, not proof):

- **SLAM never hit the ground.** The field is 68% land but low: 16.6 m at most around the Quay,
  the Rocks and the CBD edge. SLAM-flown craft kept ≥ 5.2 m above it. SLAM has no
  scenery avoidance at all (its only avoidance is for rival aircraft), so a higher field is the
  real test.
- **Haiku in the seat still makes zero claims,** now over 17 races. Both real-ground crashes were
  Haiku's own descents: H1 settled onto 4.5 m land east of the Quay ("gentle descent"), and H2 flew into
  Sydney Cove from 3 m while "descending slowly toward targets".
- **The back seat keeps helping.** On real ground, 3 of 4 back-seat races finished by tick 118 (controls
  161–180), and the Haiku-advised H1 claimed in 3 of them. With boxes only, RED claimed nothing in
  any of the 10 QUAYSIDE races; on real ground RED claimed in 4 of 10.
- **The map shows no clear effect.** It helped on one seed and not the other.
- **Targets on real ground:** 170 legs, ≥ 4.8 m above the ground, routing around structures (the
  Salesforce tower; the station/Cahill block at 9 m). Every track was identical across runs until claimed.

## Dependencies (supersede the v0.89 / v0.90 chain)

| Package | Why |
|---|---|
| `oorexx_maths_v0.21` | `MathTerrainPanorama` (NUMPY = PURE on 929,280 / 929,280 real-harbour pixels; 26 ms vs 7.4 s per 960 × 242 frame) |
| `oorexx_compress_v0.1-dev5` | dev4 + `IndexedPngEncoder` / `ForeignPngProvider`. My earlier "dev3" submission collided with an existing dev3, and dev5 supersedes it. v0.89 / v0.90 pointed at that broken dev3 path |
| `oorexx_slam_v0.1` (Power SLAM v0.40) | `HarbourWordsMGA`, `HarbourWordsRoleEvidence`, `HarbourWordsSceneTile`, `mgaOf` |
| `oorexx_slam_toprope_v0.1/examples/harbour` | `harbour_heights.words` (3243f644…), `harbour_water.words` (dd6c0bad…) |
| `oorexx_physics_world_v0.1-dev51`, `oorexx_ai_provider_anthropic_v0.3` | unchanged (submitted earlier today) |

## Running it

```
. bin/slam450_env.sh
```
```
rexx bin/race450_squad.rex out/race 45046 QUAYSIDE 180 WIND BATTERY AUTO LIVE EYES AUTO OFF BACKSEAT MOVING MAP GROUND
```
```
python3 tests/audit_squad450.py out/race --scene evidence/powerslam_v040_scene_ORACLE_ONLY.csv --ground "$SLAM450_HARBOUR_WORDS"
```
```
rexx bin/render450_squad_topdown.rex 'out/plan.svg 45046:QUAYSIDE:GROUND out/race "title"'
```

New tests: `test_ground450.rex` (known places, fail-closed, exact segments, starts clear) and
`test_quayside450.rex` (field, hidden targets, movers confined, map identical across seeds, LEGACY
unchanged). There is also a 6-tick real-ground race through all four auditors with `--ground`.

## Pictures (`evidence/v091_pictures`)

- `slam450_v091_ground_plan_45046.png` / `_45047.png`: plan views on real ground.
- `slam450_v091_quayside_plan_*`: the same races with boxes only.
- `slam450_v091_quayside_ground_map.png`: the map Haiku now gets.
- `v091_pano_stack.png`: four pilot panoramas with land.

## Self-score: 8/10

Solid:
- the estate's v0.40 classes are the authority, and the fast path is verified against them at every start;
- the segment checks are exact;
- there's an independent auditor with its own projection;
- byte-identity is preserved;
- the new Maths lane is in the right package, at 100% parity.

Weak:
- 2 seeds per cell;
- QUAYSIDE's ground is too low to test SLAM's missing terrain avoidance;
- structures are drawn over hills;
- the compress dev3 collision was mine. It's fixed here, but it cost the v0.89 / v0.90 submissions.
