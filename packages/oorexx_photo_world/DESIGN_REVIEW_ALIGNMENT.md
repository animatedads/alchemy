# Portfolio code-review alignment — dev17

This increment applies the relevant findings from the ooRexx / Alchemy portfolio fixes and design review without treating its 18 September package inventory as current version authority.

- **Compatibility / acceptance drift:** `compatibility-lock.json` records semantic API, exact dependency versions and hashes, runtime build/target, authority and qualification state.
- **Dependency authority:** bundled archives are sealed-delivery snapshots, not development authority. Silent ambient path-order selection is explicitly disallowed.
- **Foreign lifecycle:** Photo World does not implement a second Python lifetime model. Macrospace / Alchemy Foreign Object remain responsible for foreign identity, dispatch and lifecycle.
- **Evidence is not authority:** immediate provider output is raw derived evidence. `SurveyEvidencePromotion` records a deliberate, lineage-preserving Maths-backed promotion without mutating `SurveyWorld`.
- **Maths authority:** reusable higher mathematics and numerical objects remain in ooRexx Maths rather than Photo World or provider-local convenience code.
- **Qualification receipts:** machine-readable receipts distinguish executed tests from `NOT_RUN` and bind executed results to the exact ooRexx runtime package hash used by this build environment.

The portfolio review's sparse-argument concern remains a bridge/foundation qualification item. Macrospace v0.31.6 qualifies arbitrary-arity framed calls and live Rexx-object arguments here, but Photo World still does not treat that as proof of every omitted-position/sparse-array case unless Macrospace supplies the dedicated omission regression.

## dev17 foreign-runtime closure

The previously NOT_RUN Python provider lane is now executed with the exact v0.31.6 bytes. Qualification proves the Photo World provider crossing plus live retained Maths-object operation. This closes the local missing-bytes gap without changing the portfolio-review rule that each exact foreign-runtime version needs its own receipt.
