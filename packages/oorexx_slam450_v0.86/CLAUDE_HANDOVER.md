# SLAM 450 v0.86 — Claude takeover brief

**Architecture and requirements:** User. **Implementation to date:** ChatGPT GPT-6. **Published:** 2026-11-03.

This package is the complete source, test and evidence snapshot delivered for the user's requested Claude handover. Changes are on a dedicated Git branch and PR for review; do not merge automatically without coordination. The `src/SlamHarbour*.cls` dependencies are a bundled snapshot of the native synthetic PowerSLAM geometry; check canonical `packages/oorexx_slam_v0.1/src/` for upstream revisions before rebasing or replacing them.

## Scope and invariants

- **Aircraft A1** is a solo racer. **A2 and A3** are independent buddy pilots with private controllers, private visual/wind/battery/cost memories, bid/ACK negotiation and temporary peer leadership. A1 cannot read buddy communications.
- Shared five airborne 2m red square targets disappear when first collected. Actions are ordinary flight controls; a separate referee sees ground truth and independently audits collisions and target claims. All three pilots start together and maintain separation.
- Each pilot gets its own onboard panorama, its own restricted pitot, cup and sail measurements, and a per-turn battery report. Wind direction is fixed within each of three altitude bands; gust strength varies. The aircraft do **not** receive true position, target XYZ or actual wind vectors.
- Battery model: 900 synthetic units each; radio 0.03 per accepted message, paid remote view 3.00 (100x), cruise 1.0 per turn, fast ~5.09, climb +0.90/metre, down no incremental climb charge. Paid remote views can be requested once per aircraft per turn (supersedes original one-in-five throttle).
- The buddies exchange battery, observed consumption and provisional cost-to-target estimates with confidence and theory; proposals penalise or refuse `STRANDED` cost estimates. No shared battery, no central commander.
- Camera representations documenting results should be produced from actual PowerSLAM geometry or native top-down track logs; **do not generate artistic Sydney geography**.

## Latest accepted qualification

Read `README_TARGET_COST.md` first. The new v0.86 cost negotiation is qualified in a **20-step partial seed 45046 race**, with four independent audits passing, 18 priced target bids and 0 known-stranding assignments. A3 claimed target 5 at step 14. The native regression run was reported as **2,905 checks**. A longer cost-aware run did **not** complete; do not present it as a successful full race. The earlier v0.85 policy won the full 143-step 45046 race 4–1, but does not prove v0.86's cost bids improve results.

The scene is 125 coarse synthetic modeled solids and is **not a certified real-world harbour map**. Data in `evidence/*ORACLE_ONLY*` must remain inaccessible to pilot code. Python files in `tests/` are independent offline audit tools, not part of the flight controller.

## Claude's suggested first increment

1. Verify the published source and `MANIFEST.sha256`. Run `tests/test_target_cost450.rex`, `tests/test_buddy450.rex`, `tests/test_buddy_energy450.rex`, `tests/test_battery450.rex` using ooRexx 5.3.0 and `rxmath`; run the 20-step reproduction command from `README_TARGET_COST.md` with all four auditors.
2. Extend private cost-estimate memory with **predicted vs realised energy on completed target legs**. Observe battery at bid, start, claim and interruptions. Do not infer true distance/wind from the referee.
3. Estimate confidence intervals and detect recurring optimism, excessive pessimism and false `STRANDED` hypotheses; learn corrections across seeded courses without leaking oracle fields.
4. Run matched cold/control vs cost-aware buddy races on identical seeds and wind streams. Report 5-target completion, claims, joules (synthetic units), reserve breaches, safety, false-stranding rates and negotiation costs; never claim strategic benefit from one win.
5. Preserve leader election by peers; shared target removal; 10m launch spacing; collision checks; honest camera/battery/radio charging; source of all onboard information.

## Invocation

```sh
cd packages/oorexx_slam450_v0.86
export REXX_PATH="$PWD/src"
rexx tests/test_target_cost450.rex
rexx bin/race450_trio.rex /tmp/energy_race45046 45046 LEGACY 20 WIND BATTERY AUTO
python3 tests/audit_target_cost450.py /tmp/energy_race45046
python3 tests/audit_battery450.py /tmp/energy_race45046
python3 tests/audit_buddy_energy450.py /tmp/energy_race45046
python3 tests/audit_trio450.py /tmp/energy_race45046 --scene evidence/powerslam_v040_scene_ORACLE_ONLY.csv --camera-mode battery --out /tmp/energy_race45046_geometry.json
```

**Ownership:** The user intends Claude to take the work next; the Rasen Falcon component lane is `slam-450`. Coordinate the owner transfer explicitly rather than both agents editing the package at once.
