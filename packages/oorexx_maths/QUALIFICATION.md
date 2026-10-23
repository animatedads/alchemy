# Qualification — ooRexx Maths v0.19

v0.19 adds exact algebra over Q while retaining the v0.18 finite-theory, theorem/proof, numerical, exact and provider surfaces.

## Required runtime lane

Exact runtime: ooRexx 5.3.0 r13196 Internal Test Version, user-supplied debug DEB SHA-256 \`8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae\`.

Fresh final-source non-Foreign run: **489 assertions PASS**. The new \`test_algebra_foundations.rex\` contributes **44 assertions PASS** covering rational-field semantics, Q[x] construction/arithmetic/evaluation/derivative, exact Euclidean division/divisibility/gcd, Q^n basis/addition/scaling, and exact linear-map application/composition/linearity.

Transcript: \`qualification/logs/v019-core.log\`.

## Foreign Runtime/provider lane

Foreign Runtime v0.22.6 exact archive SHA-256 \`25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465\`.

Fresh enabled provider total: **177 assertions PASS** across NumPy, SciPy, SymPy/mpmath and provider proof-planning lanes. The first final-source invocation completed five lanes (123 assertions) before the environment execution window interrupted the next lane during startup. A second invocation reran that lane and all remaining lanes cleanly (54 assertions). Interrupted work is not counted.

Transcripts: \`qualification/logs/v019-foreign-part1.log\` and \`qualification/logs/v019-foreign-part2.log\`.

## Enabled total

**666 freshly executed assertions PASS** = 489 required/core + 177 Foreign Runtime/provider.

## Capability-gated lanes

- FLINT-ARB: **SKIP**, because \`python-flint >= 0.9.0\` is not installed.
- Crypto sealing: **NOT_RUN** because the exact Crypto v0.8.3 + Runtime Reference v0.4 executable dependency closure is not present. Historical Crypto evidence is not counted as fresh v0.19 evidence.

## Standards gate

Direct scan with the Library-supplied \`oorexx_standards_enforcer.py\` (SHA-256 \`978d0eb24cde13e014f2aeb61bccec1e6e6049792031c593e11407af17d545d8\`) reports **0 errors**, 134 warnings and default \`VERDICT: PASS\` across 58 ooRexx files.

Strict mode reports the warnings for review: 131 \`LOOP_INVARIANT\` heuristic warnings and 3 synchronous \`PRIVATE_METHOD\` warnings. The v0.18 baseline had 126 reviewed warnings; the eight new v0.19 warnings are loop-heuristic false positives in polynomial/vector algebra routines. No private method is sent across a \`.Message\` activity boundary.

See \`STANDARDS_ENFORCER_REVIEW.md\` and the machine-readable receipts under \`qualification/receipts/\`.

## Evidence discipline

The algebra layer reuses \`MathRational\`, \`MathVector\` and \`MathMatrix\`; it does not create a second numeric authority. Polynomial equality and algorithms are exact over retained rational values. No external research theorem is imported as truth merely because it appears in a paper or formalization catalogue.
