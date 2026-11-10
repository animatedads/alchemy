# SLAM 450 v0.88: real hover physics, a fixed-wing buddy, aircraft-type observation

- **Architecture:** Tom Dyer
- **Coding:** ChatGPT GPT-6 (v0.6–v0.86 base); Claude (Opus 5.5) (v0.87 fixes, v0.88, Physics World dev51, Maths v0.20)
- **Update written by:** Claude (Opus 5.5), 3 November 2026

SLAM 450 now gets its physics and maths from the Alchemy packages instead of its own formulas:

- **Physics World 0.1-dev51:** `MultirotorMomentumModel`, `ElectricPropellerMap`, `FixedWingFlight.cls`, and α-table inversion
- **Maths v0.20:** `MathBinary64ScalarLane` and `MathPanoramaProjector`, with a PURE lane and a NumPy lane

Anything SLAM needed that those packages lacked was added to them, not to SLAM. The patch is `alchemy_physics_dev51_maths_v020.patch`, which applies cleanly to `animatedads/alchemy` HEAD `a34a80e4`.

## 1. Hover cost fixed (physics, not a price list)

The quad (450-size: 1.2 kg, 4 × 9 in rotors, FM 0.60) is priced by momentum theory. **1 energy unit = hover electrical power for 1 s = 143.45 J.**

| Quad state | v0.84–v0.87 tariff | v0.88 physics |
|---|---:|---:|
| Hover | 0.08 | **1.000** |
| 3 m/s level | 1.00 | 0.958 (translational lift) |
| 7 m/s level | 5.09 | 0.875 (near minimum power) |
| +2 m/s climb at 3 m/s | +0.90/m | about +0.05/m |

Holding position is now the most expensive way to wait, as it is on a real multirotor. The low-battery speed cap now uses the aircraft's best-range speed instead of crawling at 3 m/s, which costs more per metre.

## 2. The fixed-wing buddy

Run with `FIXED_WING` and the team becomes **A2 = quad, A3 = fixed-wing prop**. A1 stays a solo quad.

**Physics** (all taken from the polar, none fitted):

- 1.4 kg, 0.40 m² wing, aspect ratio 7
- L/D 10.0 at 8 m/s; stall at 6.57 m/s
- Level flight at 8 m/s draws 20.6 W, or 0.144 unit/tick
- 3S 2200 mAh pack (24.42 Wh, 612.8 units)
- Wind drifts it with the full air-mass vector (a quad station-keeps)

**Natural glide:** with no thrust, the same equations give a glide at the polar's L/D. If the pack goes flat, the motor cuts and the wing glides on (`POWER_OUT_GLIDE`); it does not stop like a quad. Ditching in the water is a scene collision.

**Onboard inner loop:** turns setpoints into throttle, bank (≤30°) and flight-path angle. Airspeed comes first, there is stall protection, and dives are capped at VNE.

**Flight computer** (pilot side, image-only): it can't hover, so HOLD becomes a loiter, and searching becomes an orbit. When a target is close and outside ±70°, it is inside the turning circle, so the wing extends out and comes back round. Steep targets are reached by spiralling. It separates by turning and changing level, and only from aircraft ahead and roughly at its own altitude. On a committed final approach, only a very close threat aborts it.

## 3. Aircraft type is an observation

- **Rendering:** each aircraft is drawn with its real silhouette. The quad keeps the legacy 2.5 m square billboard; the wing is wide and flat (5 m half-span, about a 6:1 aspect).
- **Classification:** pilots read type from the pixels only (aspect ratio), with a vote memory (CANDIDATE → CONFIRMED after 3 agreeing sightings; a contradiction gives UNKNOWN). The referee's airframe table is never read.
- **Ranging:** each type is ranged by its own size. A wing ranged as a quad reads about 2× too close.
- **Sharing:** buddies relay only their *own confirmed* observation of the rival's type (`RIVAL_TYPE`) plus their own airframe (`AIRFRAME`) in OBS messages, tagged as self-reports.
- **Competition:** tactics keep separate learned contexts per rival type (`_VS_QUAD` / `_VS_WING`). A rival lined up on a target is weighted by whether it can stop on it.
- **Flight-window hints:** shared pilot knowledge, written to `<prefix>_flight_window_hints.txt`:

```
QUAD SPEED 0 TO 7      QUAD HOVER TRUE    QUAD CLIMB 4 DESCENT 4    QUAD TURN_RADIUS 0 LATERAL TRUE    QUAD STOP_ON_TARGET TRUE
FIXED SPEED 7 TO 11    FIXED HOVER FALSE  FIXED CLIMB 2 DESCENT 3   FIXED TURN_RADIUS 11 LATERAL FALSE FIXED STOP_ON_TARGET FALSE
```

Type audit:

- **Quad + quad + wing race:** 588 sightings, **0 misclassified**, 6 honestly UNKNOWN, and all 576 CONFIRMED beliefs correct.
- **All-quad race:** 768 sightings, of which **3 single sightings were misread** (probably a partly hidden or clipped silhouette) and 11 were UNKNOWN. The vote memory never confirmed a wrong type: all 750 CONFIRMED beliefs are correct. One sighting is not a fact; three agreeing ones are.

## 4. Results, seed 45046, 180-tick cap, all auditors PASS

| Race | Result | Claims | Battery left | Wall time |
|---|---|---|---|---:|
| v0.86 (as shipped) | step limit, 4/5 | — | — | 169 s |
| v0.88, 3 quads | **COMPLETE at 143**, buddies 4–1 | same sequence as v0.85 | 75.0 / 75.1 / 75.1 % | **12.0 s** |
| v0.88, quad + quad + wing | **COMPLETE at 98**, buddies 4–1 | A3 (wing) 2, A2 2, A1 1 | A1 82.9 %, A2 82.6 %, wing 87.1 % | **8.3 s** |

In the mixed race the wing flew 98 ticks on **20.8 units** of flight energy, against about 97 for each quad. Its remote camera lookups (57 units) were 73% of everything it spent, so a lookup policy tuned per airframe is the obvious next lever. The tightest swept separation was 9.11 m, and the largest single step was 11.31 m (the wing).

The speed-up comes from the Maths NumPy projector. The static scene stays resident in Python, so each frame sends the camera pose in and gets one packed string back. Panorama rendering went from 0.25 s to 0.002 s per frame. Flight physics was already only about 1% of a tick and stays native Rexx, because foreign-runtime marshalling would make it slower.

## 5. Qualification

- **Native suites:** 2,958 checks across 18 suites, all passing. New: `test_fixedwing450.rex` (19) and `test_aircraft_type450.rex` (33).
- **Physics World dev51:** 181 of 191 pass. The 10 failures are pre-existing and unchanged from the dev50.2 baseline. New: 4 tests.
- **Maths v0.20:** full suite rc=0, every v0.19 PASS retained. New: `test_fast_lanes` and `test_fast_lanes_native`. NumPy matches PURE at 16 digits on 6,000 of 6,000 extents.
- **Renderer:** the PURE lane is **bit-identical** to the v0.86 renderer, compared over whole frames.
- **Auditors** (independent Python, offboard only):
  - `audit_battery450` replays both power models from the published equations: quad exact, wing to 3×10⁻¹⁰ units.
  - `audit_buddy_energy450` reads per-airframe packs.
  - `audit_trio450` applies a per-airframe kinematic bound.
  - `audit_target_cost450` exempts ACKs still in flight at the finish.
  - New: `audit_aircraft_type450`.

**Battery checks replaced one for one.** The physics contract supersedes the v0.84 synthetic tariff:

| v0.84 check | v0.88 check |
|---|---|
| cruise = 1.000 | hover = 1.000 (unit definition) and cruise < hover |
| fast > 4 × cruise | 7 m/s cheaper than 3 m/s, and cheaper per metre |
| climb − descent = 1.8 | climb > level; descent = level (no regeneration) |
| side > hover | side 3 m/s priced as 3 m/s airspeed |
| turn > hover | yaw priced at hover (torque power below model resolution) |
| low battery caps at 3 m/s | low battery caps at the best-range speed |
| A1 debit 899, A2 debit 0.08 | debits equal the physics quote |

The 750-tick and 450-tick endurance profiles and the lookup-trade-off check still pass unchanged.

**Runner fixes found on the way:**

- It refuses a missing output directory (v0.86 wrote nothing and still exited 5).
- It clears its own old outputs for the prefix, because `lineout` appends and a rerun used to merge two races into one evidence set.
- The battery ledger now runs at 16 digits (it was 9).

## 6. Run

Requires ooRexx 5.3.0 r13196 with rxmath, a checkout of `animatedads/alchemy` with the dev51/v0.20 patch applied, and, for the NumPy lane, Foreign Runtime v0.22.6 plus NumPy. Arguments 8 and 9 are the A3 airframe (`QUAD` | `FIXED_WING`) and the projection lane (`AUTO` | `PURE` | `NUMPY`).

```
export ALCHEMY_ROOT=/path/to/alchemy
```

```
. bin/slam450_env.sh
```

```
mkdir -p /tmp/v088
```

```
rexx bin/race450_trio.rex /tmp/v088/race 45046 LEGACY 180 WIND BATTERY AUTO FIXED_WING AUTO
```

```
python3 tests/audit_battery450.py /tmp/v088/race
```

```
python3 tests/audit_aircraft_type450.py /tmp/v088/race
```

## 7. Not claimed

- Everything is a synthetic harbour model: no surveyed terrain or real flight clearance.
- No attitude or pitch dynamics, no propeller windmilling, no battery voltage sag, and no vortex-ring modelling. VRS is flagged, not modelled.
- The aircraft coefficients are plausible explicit inputs, not measurements of a real airframe.
- One seed is not a performance comparison. Showing whether quad + wing beats quad + quad needs a multi-seed study.
- The NumPy lane is binary64: across a run it may flip about 1 pixel in 50,000 box extents compared with the 9-digit reference. Use `PURE` for bit-exact reproduction.
