# SLAM 450 — current version v0.92

**Read [README_V092.md](README_V092.md) first**: the HILL, PYLONS and HARBOUR courses, onboard systems as controls, the wing option, the flight book, and the visual position fix against a precomputed 50 m grid. Then [README_V091.md](README_V091.md) (QUAYSIDE on Power SLAM v0.40 ground) and [README_V090.md](README_V090.md) (moving targets, back seat, plan map).
Older: [README_V089.md](README_V089.md), [README_V088.md](README_V088.md), [README_V087_CANDIDATE.md](README_V087_CANDIDATE.md), [README_TARGET_COST.md](README_TARGET_COST.md) (v0.86), [README_ENERGY_EXCHANGE.md](README_ENERGY_EXCHANGE.md) (v0.85), [README_BATTERY.md](README_BATTERY.md) (v0.84). The v0.8 text below is kept as history; its counts and tariff are superseded.

---

# SLAM 450 v0.8 — three-aircraft peer partnership

Architecture: user. Native ooRexx implementation: ChatGPT GPT-6, 3 November 2026.
Built on the existing v0.7 SLAM 450 / PowerSLAM Harbour v0.40 synthetic world. The original two-aircraft runner remains available unchanged; new trio runner is `bin/race450_trio.rex`.

## Experiment rules

- **Aircraft 1 (A1)** remains an independent solo competitor.
- **Aircraft 2 (A2) and Aircraft 3 (A3)** fly independent controllers with separate visual, steering, wind, rival-observation, tactical and buddy-message memories. They share neither memory objects nor flight commands.
- All three start at the same simulated time, at **10 m pairwise separation** (equilateral triangle), and move through the same simulated world and three changing wind bands.
- Targets 1–5 are public visual red shades; the referee alone determines the earliest swept physical interception, awards exactly one winner and removes the claimed target from every subsequent panorama.
- Rendered onboard camera: `R` denotes the solo competitor seen by A2/A3, and `P` their visible buddy. A1 can see both but **never accesses the buddy radio**. Each onboard image comes from the real, unmodified PowerSLAM scene solids; target truth and wind truth remain in the independent referee.
- All three share the previous single fixed-camera budget: **at most one granted fixed view across the entire fleet every five completed steps**.

## Peer negotiation (`src/Slam450Buddy.cls`)

No central team commander. A2 and A3 each create an independent `BID` message from their **own onboard indexed pixels** and (where available) restricted pitot/cup/sail packet. Each bid carries five apparent-target quality scores, not true target coordinates, with low scores for unseen squares. A `Slam450BuddyRadio` transports only A2↔A3 messages, with one simulated step latency. The transport cannot originate any policy decision.

Once each has the other's bid, **both independently compute** an assignment of different targets that maximises the sum of their locally reported image scores. Each computes the same temporary coordinating peer by comparing the best bids. Equal bids are resolved by alternating the tie-break on the negotiation epoch; there is **no permanent superior**. Both send an explicit `ACK` containing the same agreement fingerprint, and assignments become actionable **only after reciprocal acknowledgement**. Thereafter each pilots its own controls; the coordinator has no ability to fly the other aircraft. The election/assignment repeats every 16 steps, and already-claimed targets immediately invalidate old assignments.

`OBS` messages transmit self-reported airspeed, cup reading, coarse sail deflection, flight band and an optional image-sighting label. There is **no field for exact wind direction, exact XYZ position or other pilots' private memory**. Each buddy retains a distinct **48-slot bounded message-observation memory**. The bus rejects messages involving A1 or unknown payload fields. These are protocol isolation tests, not cryptographic authentication.

## Qualified results

- **715 native ooRexx checks pass**: the original 673 checks, plus 42 new three-aircraft peer/referee checks.
- Seed 45045, `LEGACY`, `WIND`, **42-step partial race**: all three completed exactly 42 successive physical steps; 125 synthetic solids independently audited; **0 model structure/water/aircraft collisions**.
- **Minimum independently measured swept aircraft separation: 5.7678 m**; maximum per-step movement 7.5271 m; lowest observed altitude 16.0248 m.
- **8 globally throttled fixed-camera grants**; no early or overfrequent request.
- **A1 claimed target 1 at step 35**. Remaining four targets unclaimed at step 42. **Neither buddy claimed a target during this short qualification**—this is a working protocol and partial competition test, not proof of superior team performance.
- The two peers sent and acknowledged the same agreed assignment. The first election selected **A3**, the next selected **A2**, with another subsequent election also selecting **A2**; these transitions are visible in the `*_team_radio.csv` record. Their private buddy memories contain 14 observations each in this partial run.
- **44 recorded radio transmit/delivery events**, including target-score offers, reciprocal ACKs and actual two-way restricted wind/sensor reports. The isolated offline Python auditor reports no faults and is never invoked by the flight controllers.

## Run

Requires native ooRexx 5.3.0 + rxmath. Set `REXX_PATH` to `src` and ensure the interpreter and rxmath shared libraries are available.

```
REXX_PATH=src rexx tests/test_buddy450.rex
REXX_PATH=src rexx bin/race450_trio.rex /tmp/buddy450 45045 LEGACY 42 WIND
python3 tests/audit_trio450.py /tmp/buddy450 --scene evidence/powerslam_v040_scene_ORACLE_ONLY.csv --out /tmp/buddy450_audit.json
```

The race runner deliberately exits **5** when the step limit is reached without all five targets collected (not a test failure); it exits 4 on model collision and 0 on complete five-target race. **Do not** describe a partial run as a complete victory.

## Limitations and next steps

- Results only cover the synthetic PowerSLAM 125-solid model; it has no fully surveyed land mask, full building-height model or real-world flight clearance.
- The 42-step test qualifies radio arbitration and safe concurrent flight, not the effectiveness of tactical cooperation. A controlled teamed-vs-independent course comparison requires multiple longer seeds, complete target captures and independent scoring.
- Radio data is honest self-report from each buddy; there is no fault-tolerant network consensus for delayed, duplicated, forged or contradictory acknowledgements, and no radio-loss recovery qualification.
- Buddies can share coarse target scores and restricted wind measurements, but currently the received wind report is stored as a hypothesis; there is no proven flight-level benefit from cross-aircraft weather information. The role election is tactical and temporary, not a central controller.
- Composite scene silhouettes are synthetic indexed pixels, not demonstrated tracking of real aircraft. The independent truth and model wind fields must not become learning inputs.

## v0.84 battery update (2026-11-03)

See [README_BATTERY.md](README_BATTERY.md) for native battery and remote-lookup accounting, per-turn private meter, endurance constraints, pilot policy, tests and independent audit. The earlier five-step camera throttle now applies only to explicit `LEGACY` mode, not the new battery-paying flight.
