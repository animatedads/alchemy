# Qualification record — ooRexx Maths v0.17

## Fresh v0.17 result

v0.17 was freshly run on the exact user-supplied ooRexx **5.3.0 r13196 Internal Test Version**. PURE/reference plus distribution-RxMath lanes contribute **422 PASS assertions**. Foreign Runtime v0.22.6 with NumPy/SciPy/SymPy/mpmath contributes **177 PASS assertions**. Total freshly executed enabled assertions: **599 PASS**.

No historical PASS is counted in that number.

| Lane | Assertions | Status |
|---|---:|---|
| core | 18 | PASS |
| claims | 10 | PASS |
| rational scalar | 15 | PASS |
| exact numbers | 24 | PASS |
| decimal expansion | 25 | PASS |
| rational round-trip | 50 | PASS |
| quantization | 31 | PASS |
| mixed precision | 9 | PASS |
| Math3D | 74 | PASS |
| Physics-derived numerical foundations | 51 | PASS |
| named constants | 4 | PASS |
| constant registry | 18 | PASS |
| rational matrix/vector | 15 | PASS |
| proof planner | 18 | PASS |
| causal continuation PURE | 16 | PASS |
| second-order input/output PURE | 6 | PASS |
| discrete state-space PURE | 19 | PASS |
| native RxMath scalar | 19 | PASS |
| NumPy | 14 | PASS |
| proof planner / NumPy | 8 | PASS |
| extended NumPy native | 21 | PASS |
| native signal/modal acceleration | 49 | PASS |
| second-order coupled dynamics | 31 | PASS |
| causal continuation native | 10 | PASS |
| second-order input/output native | 6 | PASS |
| discrete state-space native | 12 | PASS |
| SymPy/mpmath proof providers | 17 | PASS |
| proof planner / providers | 9 | PASS |
| **Fresh enabled total** | **599** | **PASS** |

FLINT-ARB is `SKIP`: `python-flint >= 0.9.0` is not available. Crypto sealing is `NOT_RUN`: the exact Crypto v0.8.3 + Runtime Reference v0.4 executable closure was not available in this current input set. Neither is counted as PASS.

## Exact qualification inputs

- ooRexx debug DEB SHA-256: `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`;
- Foreign Runtime v0.22.6 ZIP SHA-256: `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`;
- Python 3.13.5, NumPy 2.3.5, SciPy 1.17.0, SymPy 1.14.0, mpmath 1.3.0.

## Portfolio/static gate

The supplied `oorexx_standards_enforcer.py` SHA-256 is `978d0eb24cde13e014f2aeb61bccec1e6e6049792031c593e11407af17d545d8`.

Pre-seal release-tree scan:

- default policy: **PASS** — 55 files, 0 errors, 126 warnings;
- strict audit: **REVIEW REQUIRED** — 0 errors, 126 warnings.

The 126 warnings are reviewed in `PORTFOLIO_REVIEW_HARDENING.md`: 123 loop-invariant heuristic warnings plus three synchronous private-helper visibility warnings. They are not suppressed by weakening encapsulation or obscuring legitimate recurrences.

Machine-readable evidence is under `qualification/receipts/`; raw execution/static-gate logs are under `qualification/logs/`.
