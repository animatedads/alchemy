# oorexx_diplomacy_claude_review v0.1-dev2

Independent review material for the LLM Diplomacy competition engine.

- Architecture: Tom Dyer.
- Engine implementation: ChatGPT (GPT-6.2), packages `oorexx_diplomacy_v0.1-*`.
- This package (reviews, fixtures, stress tools, decision record): Claude (Opus 5.5).

It holds no engine code. Everything here is published so that every designer can
repeat every check.

## Contents

| File | What it is |
| --- | --- |
| `DECISIONS-2026-11-27.md` | Decision record written while Rasen Falcon was offline: Meta Muse takes Meta's seat and the rules-audit role; open rulings |
| `review/REVIEW-dev4.md` | Referee review (DATC v3.4 additions, fuzz and mutation results, F1-F4) |
| `review/REVIEW-dev5.md` | Step-5 controller review (570 audited games, N1-N4) |
| `review/REVIEW-dev6.md` | Step-6 press review: seat-order bias (P1), tie-break counting received mail (P2), volume (P3) |
| `review/megaphone.rex`, `review/DiplomacyMegaphoneSource.cls` | Press measurement: rank of each sender in every inbox, and the share of a loud sender |
| `review/datc-v3.4-additions-movement.txt` | 10 DATC v3.4 movement cases, with the strict-coast results for 6.B.16/6.B.17 |
| `review/datc-v3.4-additions-season.txt` | 3 season cases, including the civil-disorder name tie-break |
| `review/fuzz.rex` | Random-board stress test of the movement adjudicator |
| `review/mutate.rex` | Mutation stress test around fixture positions |
| `review/game_audit.rex` | Full-game auditor: run, rerun, replay, then re-derive the rules from the journal |
| `review/DiplomacyRichStubSource.cls` | Adversarial test player for full games |
| `review/regex_probe.rex`, `review/regex_timing.rex` | Measured behaviour of ooRexx `RegularExpression` for the revision regex rule |

## Running

The tools run from the root of an engine package. `tests/run.sh` does that against
`packages/oorexx_diplomacy_v0.1-dev6`, at sizes that finish in a few minutes:

```sh
ALCHEMY_REPO_ROOT=/path/to/estate sh tests/run.sh
```
