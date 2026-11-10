# Portfolio-review hardening — ooRexx Maths v0.17

v0.17 is a review/hardening release. It deliberately adds no new mathematical family.
The release applies the estate portfolio rules to the v0.16 source and qualification surface.

## Changes

- adds `compatibility-lock.json` with exact runtime/Foreign Runtime artifact hashes, authority boundaries, provider versions and current qualification state;
- adds machine-readable receipts under `qualification/receipts/` and preserves raw test/static-gate logs under `qualification/logs/`;
- runs the supplied `oorexx_standards_enforcer.py` directly against the release tree/ZIP;
- removes production uses that depended on `&`/`|` as if they short-circuited;
- removes discouraged `result` locals and `+ 0` numeric-coercion idioms identified by the standards tool;
- makes expected-condition tests announce `rc`, `sigl`, condition name and description;
- retains external packages as external authorities rather than copying their source into Maths.

The language-safety rewrite exposed two review-sensitive branches which are now explicit: the ball-accuracy proof starts fail-closed (`DISPROVED`) until its exact/provider evidence satisfies the requested bit count, and discrete-state-space AUTO routing has an explicit outer provider branch rather than relying on ambiguous nested-`else` binding.

## Static standards gate

Tool SHA-256: `978d0eb24cde13e014f2aeb61bccec1e6e6049792031c593e11407af17d545d8`.

Final pre-seal scan of the source tree ZIP:

- default policy: **PASS**, 55 Rexx files scanned, 0 errors, 126 warnings;
- strict audit: **REVIEW REQUIRED**, 0 errors, 126 warnings.

The warnings are 123 `LOOP_INVARIANT` heuristic reports and three `PRIVATE_METHOD` reports. The loop reports include normal recurrence, test and benchmark loops where the flagged value legitimately changes through state or input each iteration. Rewriting those loops only to satisfy a static heuristic would reduce clarity. The three private helpers (`MathRxMathProvider~atan2Native` and two class-local `lowerIndex` methods) are synchronous internal calls; none is a `.Message` activity boundary. If that changes, the visibility contract must be revisited and crossing tests added.

## Qualification policy

No inherited PASS is counted as freshly executed. v0.17 counts only the freshly rerun r13196 and enabled Foreign Runtime provider assertions. FLINT-ARB is a capability SKIP because python-flint is absent. Crypto sealing is `NOT_RUN` in this pass because its exact dependency closure was not present as executable artifacts; historical Crypto evidence remains historical only.
