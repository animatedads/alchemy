# Independent review — ooRexx Diplomacy v0.1-dev5 (step 5, game controller)

Architecture: Tom Dyer. Implementation under review: ChatGPT (GPT-6.2).
Review, auditor and test player: Claude (Opus 5.5). Sent as REQ-00006391.

## Verdict

PASS for step 5. Proceed to step 6 (press).

## What was run

- `tests/run.sh` from a verified copy: 3,374 checks, 0 failures, lint 0.
- `review/game_audit.rex`: for each seed, run the game, run it again from scratch and
  replay it; all three journals must be byte-identical. Then re-derive the rules from the
  journal using only the public map (one unit per province, unit types on legal nodes,
  34 centres, ownership changes only after Fall retreats, movement removes exactly the
  dislodged units, legal retreats, legal builds, units within centres after Winter,
  correct retreat and winter calls, results match orders byte for byte, END rule).
- Self-test: three faults planted in a real journal (illegal build, Spring ownership
  change, army at sea); all three reported.

| Batch | Games | Failures | Notes |
| --- | --- | --- | --- |
| RICH (adversarial player), seeds 1000-1199, 2000-2199 | 400 | 0 | 3,519 dislodgements, 3,750 civil-disorder disbands, 3 solos, ~3,350 failed calls |
| RANDOM (dev5 stub), seeds 3000-3149 | 150 | 0 | 6 solos, zero dislodgements |
| HOLD (dev5 stub), seeds 4000-4019 | 20 | 0 | |

570 games, 1,710 full runs, all byte-identical across run, rerun and replay.

## Findings

- **N1 coverage.** The dev5 RANDOM stub never supports, never convoys and only builds
  armies: zero dislodgements in 150 games, so the full-game gate never exercises retreats.
  Add `game_audit.rex 5 1000 RICH` to the gate.
- **N2 estate rule.** `DiplomacyGame.cls` lines 19-21 use `+ 0` coercion.
- **N3 estate rule, step-7 risk.** The `failed:` and `badCall:` handlers do not announce
  the condition. `badCall` would turn an engine plug-in exception into a silent ERROR.
  Log rc, sigl, condition('C'), condition('D') through oorexx_logging; leave the journal
  line unchanged.
- **N4 for Tom.** Order calls with an empty task (power with centres, no units).

Known limit of the auditor: the convoy-origin retreat exception assumes the DISLODGED
convoy flag is written as `1`.
