# Qualification — ooRexx Maths v0.20 candidate

Status: **CANDIDATE; native r13196 rerun pending.**

The source increment adds `MathFiniteChain` and `tests/test_ordered_structures.rex` (21 assertions). Candidate archive `oorexx_maths_v0.20-candidate1.zip` has SHA-256 `152faeb8ba2562087957fe0e9d7e1561237ef4508faa4a8ee2150bc6287abcac` and passes the portfolio standards gate with 0 errors / 135 reviewed warnings. The preparation host does not expose the qualified ooRexx r13196 interpreter, so v0.19's 666 PASS assertions are retained only as historical baseline evidence and are **not** relabelled as v0.20 PASS.

Promotion requires the new ordered-structures test, the existing non-foreign suite, enabled Foreign Runtime provider lanes, and resealed manifest/receipts on the exact candidate bytes.

The Reasoned Thought cross-pillar is a consumer/design input only; its semantic suite is separate and must not be counted as Maths assertions.

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


## v0.20 candidate2 SLAM-derived statistics

Candidate2 adds `MathStatistics` and `tests/test_statistics.rex` (29 assertions) after inspection of Library `oorexx_slam_v0.1-1.zip`. This host still does not expose the exact ooRexx r13196 runtime, so the new assertions are PENDING native qualification; no v0.19 PASS is inherited. The candidate archive `oorexx_maths_v0.20-candidate2.zip` has SHA-256 `db4be88afc25ecb694a2909fa48153141e69f0752a2c20bacde50b821e8527e4` and passes the portfolio standards gate with 0 errors / 136 reviewed warnings.


## v0.20 candidate3 paired statistics

Candidate3 adds `MathPairedStatistics` and `tests/test_paired_statistics.rex` (12 assertions). Native ooRexx r13196 execution remains PENDING on this preparation host. The new test covers exact rational population/sample covariance, exact perfect positive/negative correlations, defensive state, length rejection and zero-variance rejection.

Candidate archive: `oorexx_maths_v0.20-candidate3.zip`, SHA-256 `3d687b4ac51f43058a41560d0d8f168cb36f4a285299784bb1164cf75560c457`. ZIP integrity PASS; internal manifest has 131 entries; portfolio standards gate: 61 files, 0 errors, 136 reviewed warnings, default PASS. These are static/archive gates only, not a substitute for r13196 execution.
