# SLAM 450 v0.84 — per-aircraft battery management

Architecture/requirements: user. Native implementation: ChatGPT GPT-6, 2026-11-03.

## Energy contract (synthetic units)

Every aircraft has an independent 900-unit pack, initially full. No energy can be borrowed, shared, or read from another aircraft's true battery. After **every completed simulation tick** the pilot receives a snapshot of its own meter and maintains a private 48-slot ring of energy observations/ideas. All battery state and debit authority live in the referee, not the pilot or its memory.

For an accepted requested flight command, clamped to the flight engine limits (`yaw` ±25 degrees, forward −3..7 model metres/step, climb ±4 metres/step, lateral ±3), energy per tick is:

```
E_flight = 0.08
         + 0.92 * (|requested_forward| / 3)^2
         + 0.35 * (|requested_lateral| / 3)^2
         + 0.06 * |requested_yaw| / 25
         + 0.90 * max(0, requested_climb)
```

**Cruise** is forward command `3`, level and straight: **1.00 unit/tick**. Fast forward command `7`, level and straight costs **5.0889 units/tick**. A `+2m` climb adds **1.80 units**; a `-2m` descent adds **zero *vertical* energy cost** (baseline and any forward motion still cost energy). Idle/hover costs 0.08 unit/tick. Wind affects movement and apparent airspeed, not the charge for requested propulsion; the model is a discrete synthetic energy budget, **not measured battery chemistry or aerodynamics**.

- Accepted A2↔A3 radio message: **0.03 unit**.
- Granted remote stationary 360° camera lookup: **3.00 units**, exactly 100 radio messages.
- Free onboard visual frames are part of baseline flight energy; they are not the expensive remote lookup.
- Remote lookup can now occur **on any turn**, superseding the earlier one-per-five-turn global throttle. At most one remote request per **aircraft** per tick is accepted, but different aircraft can look up on the same tick. The pilot can request `AUTO`, `FIFTH`, `EVERY` or `NONE` lookup policies.
- In `AUTO`, a high-charge pilot ordinarily looks up once per five turns, can request an earlier lookup when its target is invisible, slows remote use below 40% battery, and suspends it below 20%. Below 32% it also stops sprinting above cruise speed.

The camera service and buddy radio debit power **on acceptance**. Invalid/repeated/underpowered operations do not charge. The referee validates energy for **all three** proposed flight commands before moving any of them. If any cannot be paid, it returns `POWER_STOP` and commits no movement or flight-energy expenditure. Messages or images already accepted that turn have still been paid for. No hidden simulator wind, distance, target or opponent battery data is placed in the pilot meter.

## Required nominal endurance budgets

For **qualification** one target leg is modelled as 150 straight, level cruise ticks; the two profiles also include **100m cumulative ascent** and **100 radio messages** as reserves. This is a *defined endurance envelope*, not a guarantee of capturing any arbitrary random course with wind, obstacles, searches or fast thrust.

| Profile | Cruise | Remote | Ascent | Radio | Total | Reserve of 900 |
|---|---:|---:|---:|---:|---:|---:|
| 5 target legs, zero lookups | 750.00 | 0.00 | 90.00 | 3.00 | 843.00 | 57.00 |
| 3 target legs, lookup each 5th tick | 450.00 | 270.00 | 90.00 | 3.00 | 813.00 | 87.00 |
| 5 target legs, lookup each 5th tick | 750.00 | 450.00 | 90.00 | 3.00 | 1293.00 | Insufficient |

The same nominal budget can now incentivise trading remote imagery, fast speed, climbing, and communication against range. Due to the 0.08 idle component and variable real-flight control demands, operational battery usage must be judged from the flight's *actual* command ledger.

## Qualification and independent audit

Native ooRexx interpreter 5.3.0 with `rxmath`:

```sh
export REXX_PATH="$PWD/src"
rexx tests/test_battery450.rex
rexx tests/test_buddy450.rex
rexx tests/test_wind450.rex
rexx bin/race450_trio.rex /tmp/battery450 45046 LEGACY 180 WIND BATTERY AUTO
python3 tests/audit_battery450.py /tmp/battery450 --out /tmp/battery450_audit.json
```

The additional arguments to `race450_trio.rex` are `batteryMode` (`BATTERY` default, `LEGACY` compatibility) and `lookupMode` (`AUTO` default, `FIFTH`, `EVERY`, `NONE`). Exit `0` means five targets claimed; `4` collision/separation stop; `5` step limit with an incomplete race; `6` power stop.

Per-craft output: `_A1_battery.csv`, `_A2_battery.csv`, `_A3_battery.csv`, and three private `_battery_memory.csv` files. Each battery row includes the command actually submitted to physics, remaining energy, cumulative charges, lookup count, and radio sends, allowing offline recomputation. The independent Python audit verifies flight price, charge continuity, service-side remote and radio counts, full tick coverage, percentages, category totals and no overdraft. This Python script audits results **only**; it is not part of the native pilot or energy engine.

The existing v0.83 `LEGACY` flight mode and camera protocol remain available for regression testing, but old race results are not retroactively battery-qualified.

## Completed native race, seed 45046

Replayed `LEGACY` target course under the new `BATTERY AUTO` settings with wind enabled, 180-step cap. **COMPLETE at step 143**, all five targets claimed; buddy team A2+A3 won 4–1. This is a replay of an earlier successful course with a new energy system, not an unseen-course learning comparison.

| Craft | Battery after 143 ticks | Charge left | Flight energy | Remote lookups | Radio messages |
|---|---:|---:|---:|---:|---:|
| A1 solo | 632.81 | 70.31% | 180.19 | 29 × 3 = 87.00 | 0 |
| A2 buddy | 432.42 | 48.05% | 382.53 | 28 × 3 = 84.00 | 35 × 0.03 = 1.05 |
| A3 buddy | 647.27 | 71.92% | 164.68 | 29 × 3 = 87.00 | 35 × 0.03 = 1.05 |

Independent `tests/audit_battery450.py` status: **PASS** with zero faults, 143 consecutive energy/pose rows for each aircraft, all 86 paid remote views matching service logs and all 70 charged peer messages matching radio logs. Independent `tests/audit_trio450.py --camera-mode battery` status: **PASS_COMPLETE_SYNTHETIC**, zero faults; minimum concurrent separation 13.5886m, 125 scene solids, all five physically intercepted in recorded order (target 5 A3 step14; 3 A2 step40; 2 A2 step87; 1 A3 step125; 4 A1 step143).

No-lookup vs fifth-turn lookup **matched 16-step trials** with the same seed, wind and controller: all three aircraft each saved exactly **9.00 units** by forgoing their three remote lookups. Both independent battery audits passed. An additional 10-step `EVERY` remote stress trial confirmed per-aircraft lookup on consecutive turns (30 paid views across 3 aircraft).

The 8 original native regression suites remain green (**558 checks**). The new battery test suite passes **2,047 checks**, including 300 energy-debits to depletion and a no-motion power stop. Combined: **2,605 native checks**, zero failures. The full race passed independently in two auditors. Qualified model scope is synthetic and does not establish real-world battery capacity or collision clearance.

Reproduce the complete flight and both independent audits from package root:

```sh
export REXX_PATH="$PWD/src"
rexx bin/race450_trio.rex /tmp/battery_full45046 45046 LEGACY 180 WIND BATTERY AUTO
python3 tests/audit_battery450.py /tmp/battery_full45046 --out /tmp/battery_full45046_battery_audit.json
python3 tests/audit_trio450.py /tmp/battery_full45046 --camera-mode battery \
    --scene evidence/powerslam_v040_scene_ORACLE_ONLY.csv \
    --out /tmp/battery_full45046_geometry_audit.json
```
