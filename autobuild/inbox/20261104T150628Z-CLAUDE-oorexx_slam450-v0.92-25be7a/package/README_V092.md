# SLAM 450 v0.92 — harder ground, onboard systems, flight book, visual position fix

Architecture: Tom Dyer
Coding: Claude (Opus 5.5) (all v0.92 SLAM 450 code, tests, auditors and runs); ChatGPT (Power SLAM scene v0.40, harbour words); Claude (Opus 5.5) (Power SLAM v0.41 bridge arch, PR #127, merged)
Written by: Claude (Opus 5.5), 2026-11-04

All runs: Anthropic cloud workspace, ooRexx 5.3.0 r13196, 2 cores. LLM: Claude Haiku 5.5 and Claude Sonnet 5.5 through `oorexx_ai_provider_anthropic_v0.4`.
Evidence from earlier versions stays in `oorexx_slam450_v0.91/evidence`; this package carries only what its tests need plus v0.92 evidence.

## What changed

1. **Courses.**
   - HILL: Observatory Hill, 420 × 420 m, needs real ground.
   - PYLONS: the bridge span; targets in pylon gaps and under the deck.
   - HARBOUR: Circular Quay to Blues Point tower inclusive, 900 × 1,510 m. One target in each of five zones: Blues tower, under the deck, Walsh Bay wharves, Observatory Hill, Circular Quay wharves. At least 2 hidden at the start. 420-tick races.
2. **Scene.**
   - Structures are drawn by class colour (Opera House, pylons, deck, Salesforce, Blues tower, wharves, Cahill, arch, other).
   - The Power SLAM v0.41 bridge arch is applied (86 solids).
   - The plan map scales itself: 0.75 px/m and a 100 m bar for fields over 700 m.
3. **Onboard systems** (scanner, radio altimeter, GPS).
   - They are controls like yaw and climb. They start off, nothing switches them on for the pilot, and each costs battery while on.
   - The scanner and radio altimeter feed the warning callouts (GPWS, the ground-proximity warning system); SLAM and the LLM may ignore a PULL UP when deliberately approaching a target they can see.
   - The briefing has a COSTS table for every action.
4. **Bug fix: LLM switches and lookups.**
   - `.JSON` gives a `JsonBoolean` for true/false. It overrides `=` but not `==`.
   - So every LLM `"lookup": true` and every system switch was silently dropped from v0.90 to v0.92. Sonnet asked 38 times and Haiku 25.
   - Fixed with `jsonTrue`, which has a regression test.
5. **Named cameras.** `lookup` may name a fixed camera: CAFE_SYDNEY, OPERA_WEST_WALK, KIRRIBILLI, NORTH_PTZ or BLUES_PT.
6. **Wing option for the LLM-crewed aircraft** (the `QUAD|WING` argument).
   - A fly-by-wire envelope blocks stall, hover, reversing and side-slip, and limits bank and climb. It is protection only, not an autopilot, and every override is logged and told to the pilot.
   - LLM-crewed wings start stacked 12 m and 18 m above their slot, so they can't fly into a hovering quad on tick 1.
7. **Identification range** (argument, e.g. `500`). Within the range an object is drawn normally. Out to 1.6× the range it shows as one pixel. Beyond that it isn't drawn at all. The fixed cameras follow the same rule.
8. **Flight book** (`Slam450Belief`), one per aircraft, never fed truth.
   - **Position:** SLAM dead-reckons from its known start and its own commands. The LLM reports `where`, `sure` and `seen` in map pixels.
   - **Coverage:** the searched space is the 50 m cells that came within the identification range of a believed position.
   - **Sightings:** from SLAM's own view, triangulated bearings (`SLAM_TRIANG`) and navigator entries.
   - **Search modes:** `SWEEP` sends SLAM to its least-searched sector. `RECALL` adds flying back to the book's entry when the chosen target is out of view.
   - **Scoring:** truth goes only to `_belief_ORACLE_ONLY.csv` and `_sightings_ORACLE_ONLY.csv`.
9. **Visual position fix** (`Slam450VisualFix`, argument `ON|OFF`).
   - **Precompute:** a one-time render of the HARBOUR area on a 50 m grid at 15, 40 and 70 m, facing north, scene only. Each view becomes a 96 × 24 feature surface (4 bits per point, ±45° band).
   - **Every 10 s:** SLAM converts its own view, matches it within 300 m and ±30° of its book, and resets the book's position and heading.
   - **Altimeter on:** the fix is refined from the nearest landmark top within 300 m, using its elevation angle in a 960 × 242 detail frame. The grid and landmark fixes are averaged.
   - **Charge:** 0.03 per grid fix and 0.03 per detail request (one radio message), in a new VISUAL battery category with its own ledger.
10. **Auditors.**
    - `audit_belief450.py` rebuilds every dead-reckoned step from the aircraft's own logged commands, the LLM's reports and the fix log. A belief that tracked truth fails it.
    - `audit_battery450.py` checks the SENSOR and VISUAL ledgers.
11. **Tests updated:** `test_course450` and `test_obstructed450` now count the v0.40 base (125 solids) and the v0.41 arch (86) separately. They had asserted 125 in total and failed once the arch was applied.
12. **Visual-fix grid data:** `data/harbour_visualfix_50m_alt{15,40,70}.txt`, VISUALFIX2 format, one letter a..m per point, 4.0 MB. It is rebuilt by `bin/precompute450_visualfix.rex` (about 2½ min per layer).

## Results

### Sonnet 5.5 against Haiku 5.5 (HILL + PYLONS, arch world, map on, 2 seeds, 16 races)
- **Sonnet as pilot:** 1 claim and 5 crashes in 8 races, at $0.65–2.12 per race. Retired from the pilot seat.
- **Navigating from the back seat:** Sonnet 2 claims in 4 races ($0.23–0.44 per race); Haiku 5 claims in 4.
- **Pictures:** `evidence/v092_pictures/`.

### Haiku as pilot
0 claims in every v0.92 seat race: quad and wing, HILL, PYLONS and HARBOUR. With the switch fix, Haiku now turns the scanner and altimeter on. It never used GPS.

### Haiku as navigator (SLAM flying), HILL + PYLONS, 6 seeds, paired with SLAM-only twins
Haiku-navigated aircraft made 18 claims against 10 for the same aircraft with SLAM alone (7 races better, 1 worse, 4 tied). Whole-race claims fell from 54 to 48: Haiku mostly takes targets its own teammates would have claimed.

### Crash-warning sensors on (8 paired races)
The SLAM-flown aircraft were knocked out 7 times with the sensors on against 13 with them off.

### HARBOUR, quad against wing (4 seeds, 500 m range, sweep)
Claims by Haiku's two aircraft, whole-race claims in brackets:

| | Quad | Wing |
|---|---|---|
| SLAM alone | 4 (13) | 8 (14) |
| Haiku navigating | 7 (16) | 9 (13) |
| Haiku flying | 0 (13) | 0 (11, one race void from the start collision, since fixed) |

### Visual position fix (HARBOUR, SLAM alone, 4 seeds per row, 16 races)

| | Fix off | Fix on |
|---|---|---|
| Quads: median position error | 147 m | 20 m |
| Quads: time within 50 m | 17% | 90% |
| Wings: median position error | 164 m | 24 m |
| Wings: time within 50 m | 17% | 89% |

- **Bench** (80 poses): grid fix median 19–20 m; with the landmark averaged in (when within 300 m), 15 m.
- **Grid size:** 2.01 MB raw, 799 KB with the V5V codec (`packages/oorexx_vision`, exact round trip on all 1,746 surfaces).

### Recall from the flight book (HARBOUR, 4 seeds, visual fix on)
Claims by Haiku's two aircraft out of 20 targets:

| | SLAM alone, sweep | SLAM alone, recall | Haiku navigating, recall |
|---|---|---|---|
| Quads | 2 | 2 | 7 |
| Wings | 8 | 8 | 16 |

126 of the 137 recall flights went to targets Haiku had written into the book as `seen`. SLAM's own triangulation is weak: median error 100–111 m.

### Audits
All race matrices pass the squad, battery, target-movement and flight-book auditors. That's 72 checks on the quad-against-wing matrix, 64 on the visual-fix comparison and 32 each on the recall and Haiku-recall batches. Integration tests: see `integration.json` (33 entries).

## Known limits
- **Haiku's position reports** copy the dead-reckoned position the book shows it about 98% of the time; `sure` sits flat at about 0.3. It doesn't yet work out where it is for itself.
- **Triangulation** needs wider spacing between bearing lines and averaging over several crossings.
- **Visual-fix grid** exists only for HARBOUR. Other courses need `bin/precompute450_visualfix.rex` run first.
- **V5V codec defect:** `oorexx_vision_v0.1-dev14`'s codec calls a missing `VisionSurfaceDelta~between`. It was fixed upstream in `packages/oorexx_vision` (dev15-repaired1 onward), which this package's tool uses.

## Self-score
8/10.
- **For:** the results are measured, paired and audited. The visual fix is a large, clean gain, and recall plus a Haiku navigator doubles the wing claims.
- **Against:**
  - The JSON boolean bug sat unnoticed from v0.90.
  - Three runtime faults (methods with no return value, a `'...'(` abuttal) each cost a rerun.
  - My first visual-fix design (full 180° band) was wrong until the bench caught it.
