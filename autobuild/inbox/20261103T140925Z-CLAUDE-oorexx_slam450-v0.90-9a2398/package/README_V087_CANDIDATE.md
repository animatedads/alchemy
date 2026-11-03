# SLAM 450 v0.87 candidate: false-stranding and last-target fixes

- Architecture: Tom Dyer
- v0.86 native ooRexx implementation: ChatGPT GPT-6
- v0.87 patch (3 small edits, ooRexx + auditor rule): Claude (Opus 5.5)
- Written by: Claude (Opus 5.5), 3 November 2026

This is a candidate. The v0.86 package is unchanged and still sits next to this one.

## Problem found in v0.86

The full 180-step race, seed 45046 (`LEGACY WIND BATTERY AUTO`), fails on v0.86. Only 4 of 5 targets are claimed, and the run exits 5. v0.84 and v0.85 completed the same course at step 143. Batteries at the end were A2 61% and A3 70%, so no aircraft was ever short of energy.

The cause is two bugs.

1. **False STRANDED.** `Slam450TargetCost` multiplied `distance/3` (ticks at cruise speed) by the *recent per-tick drain*. A2 was climbing at +4 m/tick, which costs 3.6 units per tick for the climb alone, so its drain was high. That drain was then applied to future *level* legs, and the leg climb was also added a second time. On top of that, a hidden target was assumed to be 420 m away on a course about 350 m across. Result: 14 of 62 bids were STRANDED, and all 14 were false (checked offline against oracle truth; true cruise costs were 40–130 units while 566–823 units remained). At 91% charge A2 priced level targets at 537–564 units, against true cruise costs of 41–65.
2. **Last-target grounding.** `calculate` required `t2 \== t3`. With one target left there is no valid pair, so the code took the solo branch: one buddy pursued and the other was committed to `PEER_ENERGY_RESERVE_HOLD` with theory `NO_AFFORDABLE_TARGET`. That label is wrong, because nothing was unaffordable. The hold repeated every 16-tick epoch (ticks 130, 146, 162, 178) while A1 and one buddy failed to close on target 4.

## Changes

| File | Change |
|---|---|
| `src/Slam450TargetCost.cls` | Legs priced at the published cruise tariff (1.00/tick at 3 m/tick). Climb charged once at 0.9/m. Observed drain is kept only as the theory label. |
| `src/Slam450TargetCost.cls` | Climb = range × tan(elevation), not `el*range/100`, which under-read climb by about 43% at small angles. A weak range keeps its `IMAGE_RANGE_WEAK` label. |
| `src/Slam450TargetCost.cls` | Hidden-target range prior changed from 420 m to 240 m. With the 1.9× LOW-confidence margin, the worst case still covers 456 m. |
| `src/Slam450Buddy.cls` | Targets stay exclusive, except that both buddies may contest the single remaining target. |
| `tests/audit_target_cost450.py` | Same rule: shared target allowed only when exactly one live target exists in that epoch. |

## Results

| | v0.86 | v0.87 candidate |
|---|---:|---:|
| Seed 45046, 180-step race | 4/5, exit 5 (step limit) | **COMPLETE at 143**, buddy 4–1 |
| STRANDED bids / false | 14 / 14 | 0 / 0 |
| Energy holds | 7 | 0 |
| Median estimate ÷ true cruise cost, level legs | 4.29 | 3.31 |
| Median estimate ÷ true cruise cost, climb legs | 1.70 | 1.65 |
| Native checks | 2,905 / 16 suites | 2,905 / 16 suites |
| Auditors (battery, energy exchange, target cost, geometry) | PASS | PASS (`PASS_COMPLETE_SYNTHETIC`, min swept separation 13.5886 m) |

The evidence is in `evidence/v087_race45046/`.

## What this does NOT show

The v0.87 race matches v0.85 tick for tick: same claims, same final batteries. On this seed the energy layer now changes no decision, which is correct because nobody got near empty. It does **not** show that cost-aware negotiation helps. To test that you need a seed or capacity where energy really runs short, for example a 450-unit pack or `EVERY` lookups, compared against a visual-only control. Level-leg estimates are still about 3× too high. The 3-pixel range proxy (300 m) and the `150/(w-2)` angular-range curve are uncalibrated. An offboard auditor could fit width-to-range from the `*_ORACLE_ONLY` truth files, and the pilot would then ship only the fitted table.

## Reproduce

Run from the package root:

```
export REXX_PATH="$PWD/src"
```

```
rexx bin/race450_trio.rex /tmp/v087/race 45046 LEGACY 180 WIND BATTERY AUTO
```

Create `/tmp/v087` first. The runner writes nothing, and reports nothing, if the prefix directory is missing.
