# SLAM 450 v0.85 — Two-way peer battery exchange

Architecture/requirements: user. Native ooRexx implementation and audit: ChatGPT GPT-6, 2026-11-03.

## What changed

Aircraft A2 and A3 share **self-reported** battery telemetry over the existing one-tick-latency, energy-charged buddy radio. Aircraft A1 does not have the team channel. A2/A3 still have separate batteries, controllers, visual memories, rival/wind memories and private battery-observation rings. There is no shared battery or privileged referee feed into either pilot.

New radio message kind `ENERGY`, permitted **only** A2->A3 or A3->A2, carries:

- Sender, recipient, kind, negotiation epoch, sequence, sensor sample tick.
- Current remaining synthetic energy, capacity, percentage, and estimated straight-level-cruise turns.
- Observation window length and measured **changes** in own flight, remote-camera and radio expenditures.
- Recent average drain per turn, a proposed cost explanation (`THEORY`), and a separate `CONFIDENCE` label.

Theories are a bounded vocabulary: `INITIAL_SAMPLE`, `NORMAL_CRUISE_DRAIN`, `HIGH_RECENT_DRAIN`, `CLIMB_ADDS_DRAIN`, `REMOTE_LOOKUPS_DOMINATE`, `LOW_BATTERY_RESERVE`. A reasoned consumption observation is **not** a proven wind condition or exact battery prediction. `OBSERVED_COST` means measured local ledger-category changes, not that a causal explanation or unseen condition is certified.

The local battery observation ring is capped at 48 slots; recent reported changes use at most 8 slots. The received peer-energy ring is separately bounded to 48 slots. Stored incoming observations are explicitly tagged `BUDDY_SELF_REPORTED_NOT_ORACLE`; this does **not** overwrite the receiving pilot's meter. The optional `energyInterpretation()` offers advisory assessments of peer-reported high drain or depleted reserves, but this increment does **not** autonomously change target assignments or flight commands based on peer energy theories.

## Communication and safety invariants

- Reports sent every 12 completed flight steps, including launch, if the aircraft can pay the transmission charge.
- A valid accepted report consumes **0.03 synthetic energy units** from the **sender**; rejected messages cost zero. Remote visual lookups still cost 3.00 units (100 times a message).
- Delivery occurs on the next simulation tick; stale samples are rejected by the receiving peer.
- Strict field whitelist rejects true position, exact wind, unknown fields and malformed or inconsistent battery reports.
- Receiver only knows what the peer **claims**. There is no cryptographic authentication; the simulator's two allowed radio endpoints constitute the trust boundary.
- No pilot receives another pilot's actual battery object, hidden simulator pose, collision oracle, or exact wind vector.

## Qualification: seed 45046, PowerSLAM 125-solid model

The original v0.84 battery-enabled race was replayed with `ENERGY` messages on the same seed, course, wind model and control policy.

| Item | Result |
|---|---:|
| Race result | `COMPLETE` at 143 steps; buddy team won 4–1 |
| Energy reports sent | 24 (12 A2->A3, 12 A3->A2) |
| Energy reports delivered and stored | 24 |
| Radio messages / peer, including bids, acknowledgements, wind and energy | 47 |
| Additional energy reports / peer | 12 messages = 0.36 units |
| A1 final remaining battery | 632.810284 / 900 (70.31%) |
| A2 final remaining battery | 432.056144 / 900 (48.01%) |
| A3 final remaining battery | 646.913930 / 900 (71.88%) |
| Fixed remote-camera grants | 86 |
| Model collisions and oracle audit faults | 0 |
| Native checks | 2,864 across 15 native `.rex` test suites, all passed |

At sample tick 132, Aircraft 2 self-reported 52.04% remaining and an average observed burn of 4.63 units/tick across its recent seven-turn window; Aircraft 3 reported 74.19% remaining and 3.80 units/tick. Both observations were delivered at tick 133. These values describe each aircraft's own recent energy ledger and can inform later reasoning, not guaranteed future endurance.

**Independent reports (all PASS):**

- `evidence/energy_race45046_battery_audit.json` — all three flight/meter/radio/lookup ledgers reconciled, zero faults.
- `evidence/energy_race45046_exchange_audit.json` — every battery report matched to delivery and a stored peer observation; all 24 messages accounted for, no packet mutation or unsupported sender.
- `evidence/energy_race45046_geometry_audit.json` — continuous trajectories, all five target claims, no scene or aircraft-separation collision (synthetic qualification only).

**Files to inspect:** `evidence/energy_race45046_team_energy.csv` (sent and delivered telemetry), `evidence/energy_race45046_team_radio.csv` (all charged messages), `evidence/energy_race45046_A2_received_energy.csv` and corresponding A3 file, plus per-aircraft `*_battery.csv` and `*_battery_memory.csv`.

## Reproduce (native ooRexx)

Use ooRexx 5.3.0 with rxmath and include `src/` in `REXX_PATH`.

```sh
export REXX_PATH="$PWD/src"
rexx tests/test_buddy_energy450.rex
rexx tests/test_buddy450.rex
rexx tests/test_battery450.rex
rexx bin/race450_trio.rex /tmp/slam450_energy_45046 45046 LEGACY 180 WIND BATTERY AUTO
python3 tests/audit_battery450.py /tmp/slam450_energy_45046
python3 tests/audit_buddy_energy450.py /tmp/slam450_energy_45046
python3 tests/audit_trio450.py /tmp/slam450_energy_45046 --camera-mode battery --scene evidence/powerslam_v040_scene_ORACLE_ONLY.csv
```

Python auditors are strictly offboard qualification utilities; the entire simulator, energy policy, peer messaging, observation memory and flight controller execute in native ooRexx.

### Remaining work

The radio now carries information; the pilots are not yet optimising their **joint target allocation** based on exchanged battery reports. A valid follow-on experiment would compare energy-aware buddy negotiation against the same seeded races with the new telemetry ignored, and measure claimed targets, remaining energy, camera usage and communications costs.
