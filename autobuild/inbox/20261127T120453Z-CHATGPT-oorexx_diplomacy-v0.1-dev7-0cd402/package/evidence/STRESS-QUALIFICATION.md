# Dev4r5 stress qualification

Architecture: Tom Dyer. Production implementation: ChatGPT (GPT-6.2).
Independent review and recovered fuzz/mutate tools: Claude (Opus 5.5).
Supplemental random-positions/literal-mutate tools: ChatGPT (GPT-6.2).

All local results on Tom's exact ooRexx 5.3.0 r13196 (64-bit).
Dev4r5 is tests and evidence only, not a new engine: production-identity.sha256
attests the four source files and rules.conf, identical to published dev4r4.

Claude's independent re-qualification on dev4r4 (REQ-00006293) reported
90,000 random positions and 8,000 mutation trials with zero exceptions,
zero invariant failures and 1,355 paradox trials. That was his own 5.3.0
build, not Tom's r13196; no claim that he ran the dev4r5 package.

## ChatGPT-authored campaign

| Tool/mode | Seed | Trials | Failures | Paradox trials |
|---|---:|---:|---:|---:|
| random-positions MIXED | 7 | 20,000 | 0 | 0 |
| random-positions CONVOY | 8 | 10,000 | 0 | 8 |
| literal-mutate F.28/F.29 | 9 | 3,000 | 0 | 110 |
| literal-mutate F.26/F.27/F.30 | 10 | 3,000 | 0 | 1507 |
| Total | | 36,000 | 0 | 1625 |

Random generator creates 8–32 units at distinct provinces, chooses
moves and then valid-looking supporting orders, and occasionally omits,
duplicates or inserts malformed orders. CONVOY seeds a matching one-/two-sea
route and biases other units toward sea fleets. Dislodgements: 4352 mixed,
1981 convoy (unit-level counts). Mutations vary order text and presence
around specified fixture seeds; they are not unique board counts.
Both harnesses check unchanged inputs, reversed-key replay, conservation
of count/type/owner, occupancy and dislodgement identity, and no self-dislodgement.
The random harness additionally checks successful mover destination and coast.
These invariants are not an independent oracle; they supplement the directed
expected outcomes.

Run from package root: sh review/run-stress.sh. Raw logs
evidence/dev4r5-random-*.txt and evidence/dev4r5-mutations-*.txt.

## Recovered reviewer-authored campaign

Tool files and missing fixture block match the reviewer's three hashes.
Run from package root: sh review/run-claude-qualification.sh. This combines
the existing strict B.16/B.17 plus six reviewer cases and exact F.28/F.29
block; all ten movement cases and three seasonal cases pass. These are
duplicate-position tests, not counted twice in the core native totals.

| Recovered tool | Seed | Trials | Exceptions | Failures | Paradox trials |
|---|---:|---:|---:|---:|---:|
| fuzz MIXED | 7 | 20,000 | 0 | 0 | 0 |
| fuzz CONVOY | 8 | 10,000 | 0 | 0 | 0 |
| mutate v3.4 F cases | 9 | 3,000 | 0 | 0 | 996 |
| Total | | 33,000 | 0 | 0 | 996 |

Raw logs: evidence/dev4r5-review-fuzz-{mixed,convoy}.txt and
evidence/dev4r5-review-mutate.txt. All four stress scripts lint clean.
Separate locally executed campaigns total 69,000 trials, zero failures,
2,621 trials resolving a paradox (not a unique board count).
The core deterministic suite: 3311 assertions, 232 positions, zero failures.
Additional reviewer-fixture checks: 98 movement and 36 seasonal, duplicate
positions not added to core totals. Separate independent review: REQ-00006293.
