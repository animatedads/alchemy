# SLAM 450 v0.86 — Peer target energy proposals and reserve-risk decisions

Architecture/requirements: user. Native ooRexx implementation: ChatGPT GPT-6, 3 November 2026.

## What actually changed

Aircraft A2 and A3 now create a **five-target energy-cost proposal** from their *own* indexed onboard panorama, *own* battery report and bounded recent spending history. Every live target bid carries:

- the target's apparent visual desirability (`SCORES`) and a separate estimated synthetic energy cost (`COSTS`);
- the cost risk classification (`LOW`, `UNCERTAIN`, `CAUTION`, `HIGH`, or `STRANDED`), uncertainty (`LOW`, `MEDIUM`, `HIGH` confidence in visual range), and a labelled causal theory (`THEORIES`);
- the sender's self-reported battery remaining, target reserve allowance, and sample tick.

No target XYZ, true aircraft coordinates, true wind vectors or future oracle consumption is in any of these fields. A2 and A3 receive **independent copies** with one-tick radio latency; valid transmissions consume 0.03 synthetic energy units per sender, on top of existing camera costs. Aircraft A1 cannot access the radio.

Both buddies independently rank all **distinct** target assignments, combining visual attractiveness with cost and risk; a target whose proposed consumption could exhaust the agreed estimate of reserve is **ineligible** for that pilot. If one buddy regards all targets as unaffordable, the peer may accept a solo target while the depleted craft holds position. Leadership and target allocation are still calculated independently every 16 steps and require reciprocal ACK before becoming authoritative. Cost-aware assignments enter the *existing* `Slam450BuddyPeer~calculate` path, not a separate central team controller. Pilot flight controls remain autonomous.

New `Slam450TargetCost.cls` estimates all five target costs, and `Slam450Buddy.cls` gains validated energy-priced BID fields, bounded local and peer cost-history rings, private snapshot copies and risk-weighted consensus. The original unpriced BID path still passes its regression tests for legacy scenarios. The trio runner exports `*_team_target_costs.csv` to make every estimate, theory and proposed choice independently auditable.

## Cost hypothesis and its limitations

For a visible red target, angular size provides a *rough* range indication. A three-pixel target is too small to resolve distance reliably: the model assigns a conservative distance proxy, labels confidence `LOW`, and adds uncertainty. For an invisible target, the model assumes a longer search and labels the estimate `HIDDEN_SEARCH`. It increases the expected effort for large bearing changes, apparent climbs and recently observed heavy consumption. Cost is based on inferred travel steps multiplied by recent private battery spend, plus a predicted climb charge. The expected-cost safety margin is larger when visual confidence is lower.

These are **explicit hypotheses**, not surveyed ranges or measured future energy. They have not been calibrated against actual claim-to-claim energy expenditure under diverse winds. As a result, a `STRANDED` classification can be a false positive and a `LOW` classification is not a guarantee of success. A return-to-base reserve is not yet separately modelled. The 16-step renegotiation interval also means risk changes between rounds are not instantly communicated.

## Qualification, seed 45046, PowerSLAM 125-solid synthetic scene

A complete **20-step short replay** was recorded with v0.86 energy-price bids. Four independent auditors/tests passed: synthetic scene/aircraft geometry, battery ledger, existing peer battery exchange, and new target-energy proposal agreement. The short replay did **not** complete the five-target race.

- Step 0: A2 estimated target 3 at **65.158 energy units**; A3 estimated target 5 at **31.657**. Both peers proposed the same assignment (A2→3, A3→5), sent ACK, and committed.
- Step 14: A3 collected target 5, which was removed from the shared target scene.
- Step 16: A2's estimate for targets 1, 2 and 4 became `STRANDED`, while its estimate for target 3 was 22.296; it did not accept any `STRANDED` assignment.
- Step 17: the next mutually calculated assignment was A2→3, A3→1; both ACKs arrived at step 18.
- Step 20: one of five targets collected; zero modeled collisions; minimum swept separation **13.5886 m**; nine paid fixed-camera views.
- End-of-step-20 battery: A1 **836.967**, A2 **815.485**, A3 **858.039** units remaining (from 900 each). Both buddies paid for eight accepted radio messages.
- Bid audit: 18 individually priced live-target records in two negotiation rounds; three `STRANDED` bids; **zero** known-stranding assignments; four reciprocal ACK deliveries; **zero audit faults**.

A longer replay reached step 45 (A3 took target 5 and A2 took target 3), but the execution was interrupted at the time limit and its files were not sealed. It is **not** part of the accepted result or the distribution evidence.

After bounding peer-cost history, the new native suite passed **41 checks**. All 16 native regression suites passed **2,905 checks** in total; the unchanged legacy image-only negotiation tests remain green. The accepted 20-step evidence predates this final memory-bounding-only change, while the native regression tests cover that change. No claim is made of a finished v0.86 race or improved win rate.

## Reproduce

Requires native ooRexx 5.3.0 + rxmath. Run from the package directory:

```sh
export REXX_PATH="$PWD/src"
rexx tests/test_target_cost450.rex
rexx tests/test_buddy450.rex
rexx tests/test_buddy_energy450.rex
rexx tests/test_battery450.rex
rexx bin/race450_trio.rex /tmp/energy_race45046 45046 LEGACY 20 WIND BATTERY AUTO
# A 20-step partial race is normally exit code 5 (step limit), not an auditor fault.
python3 tests/audit_target_cost450.py /tmp/energy_race45046
python3 tests/audit_battery450.py /tmp/energy_race45046
python3 tests/audit_buddy_energy450.py /tmp/energy_race45046
python3 tests/audit_trio450.py /tmp/energy_race45046 --scene evidence/powerslam_v040_scene_ORACLE_ONLY.csv --camera-mode battery --out /tmp/energy_race45046_geometry.json
```

Python scripts are **offline independent auditors only**, never the pilot/controller. The next substantial scientific work is a matched multi-seed comparison of price-aware negotiations against a visual-only control, with actual battery-to-claim expenditure and a measured false-stranding rate.
