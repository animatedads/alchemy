# Independent review — ooRexx Diplomacy v0.1-dev4 referee

Architecture: Tom Dyer. Implementation under review: ChatGPT (GPT-6.2).
Review, fixtures and stress tools: Claude (Opus 5.5). Answers REQ-00006149.

Update: Tom ruled F2 STRICT. B.16/B.17 fixtures now expect the strict results; all 10 v3.4 movement cases pass on dev4.

## Verdict

PASS for the step-4 gate, with one fix required before step 5 (F1) and one
ruling for Tom (F2). The solver held up under every stress test I could build.

## What I ran

| Check | Result |
| --- | --- |
| Full `tests/run.sh` from a clean extraction, estate lint hash-pinned (dev9) | 2,840/2,840, lint 0 findings |
| DATC v3.4 movement cases missing from the v3.0 corpus (10 cases, 93 checks) | 8 cases pass; B.16 and B.17 fail (F2) |
| DATC v3.4 season case 6.H.16 + civil-disorder tie-break cases (3 cases, 36 checks) | 2 pass; name tie-break fails (F1) |
| Random positions, mixed (60,000 positions, ~900,000 orders) | 0 exceptions, 0 invariant failures |
| Random positions, convoy-dense (30,000) | 0 exceptions, 0 invariant failures |
| Mutations of DATC paradox and cycle positions (8,000; 1,334 resolved a Szykman paradox) | 0 exceptions, 0 invariant failures |

Invariants checked on every random position: no exception; units conserved;
identical result with reversed insertion order; every dislodged province is
reoccupied; every successful mover is at its destination and never dislodged.
The 4,096-trial cap was never reached.

Interpreter: ooRexx built here from the GitHub mirror head (5.3.0, Nov 2026),
not Tom's r13196 debug build. The code uses no catch/finally, so the result
should carry over, but the official qualification remains the r13196 run.

## The three flagged interpretations

All three match the DATC v3.4 preferred options:

1. Retreat into a convoyed attacker's origin: allowed — DATC 4.A.5 option 2. Correct.
2. Civil-disorder distance: to owned centres, counting adjacency whatever the unit
   type, fleets before armies — DATC 4.D.8 (2023 rules). Correct, except the last
   tie-break (F1).
3. Excess adjustment orders: first legal used — DATC 4.D.4, 4.D.5, 4.D.6. Correct.

## Findings

**F1 — Fix. Final civil-disorder tie-break uses province codes; DATC uses English
province names.** `automaticChoice` keeps the first unit in code order. DATC
4.D.8 breaks the last tie alphabetically by province name. The orders differ
wherever code and name sort differently, e.g. F MAO vs F MAR at equal distance:
DATC removes F Marseilles ("Marseilles" < "Mid-Atlantic Ocean"); dev4 removes
F MAO. Cause: the build brief (written by Claude) said "alphabetically by
province code". The brief was wrong, not the implementation. Fix: order the
tie by `board~node(code)['NAME']`. Test: `CD-NAME-TIEBREAK`.

**F2 — Ruling for Tom. Supports naming the wrong coast are invalid in dev4;
DATC 4.B.5 prefers them valid.** 6.B.16 (hold support naming SPA/NC for a fleet
in SPA/SC) and 6.B.17 (move support naming the wrong departure coast) fail.
Dev4 is strict, consistent with the brief ("parsing forgives case and spacing
only") and with invalid orders being legal play. Options: (a) keep strict,
add `SUPPORT_COAST=STRICT` to rules.conf and record B.16/B.17 as deliberate
deviations with strict expected results; (b) follow DATC and ignore the coast
in support orders. Claude's view: (a), because a wrong-coast support is
exactly the kind of deniable slip the competition wants to keep.

**F3 — Coverage. The corpus is DATC v3.0; v3.4 is current.** Missing: 6.B.16–19,
6.D.35, 6.F.26–30, and v3.4's 6.H.16 (no coastal crawl from Portugal).
Numbering shifted: dev4's 6.H.16 is v3.4's 6.H.17, and dev4's 6.J.9a/9b/10/11
are v3.4's 6.J.9–12 (v3.4 uses A Albania where the v3.0 corpus uses A Greece;
same expected removals). Add `datc-v3.4-additions-movement.txt` and
`datc-v3.4-additions-season.txt` to `run.sh` (expected counts 10 and 3), with
B.16/B.17 adjusted per F2.

**F4 — Note for step 5.** `movement` raises syntax 93.900 when a position is
unresolved or hits the trial cap. It never happened in 98,000 positions, but
the game loop must trap it, log it through oorexx_logging, and stop the game
rather than publish a board.

## Files

- `datc-v3.4-additions-movement.txt` — 10 cases, runner: `rexx tests/movement.rex review/datc-v3.4-additions-movement.txt 10`
- `datc-v3.4-additions-season.txt` — 3 cases, runner: `rexx tests/season.rex review/datc-v3.4-additions-season.txt 3`
- `fuzz.rex` — random-position stress test: `rexx review/fuzz.rex <positions> <seed> [MIXED|CONVOY]`
- `mutate.rex` — mutation stress around fixture positions: `rexx review/mutate.rex <n> <seed> <fixture file> <case prefixes...>`

Run all from the package root. Both tools pass the estate lint (0 findings).

## F1 suggested patch

`F1-suggested-patch.diff` (against dev4 `src/DiplomacySeason.cls`) orders the
civil-disorder tie by English province name. With it applied, all three season
suites pass (36, 11 and 3 cases) and the estate lint reports 0 findings. It is a
suggestion; ChatGPT owns the code.
