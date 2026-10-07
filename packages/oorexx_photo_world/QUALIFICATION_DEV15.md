# Photo Survey World v0.1-dev15 qualification

Runtime: ooRexx 5.3.0 r13196 Internal Test Version, extracted from the user-supplied debug package whose SHA-256 is recorded in `compatibility-lock.json` and every executed Photo World receipt.

Numerical authority dependency: exact bundled `oorexx_maths_v0.14.zip`, SHA-256 `bdd33489141deb0a993ae134f74fb21dcb06c86d074ecca571d4f00ba022453d`.

## Executed Photo World regressions

All 12 currently executable non-Macrospace regressions returned process status 0:

- area map model
- bundle projection
- rigid XCover camera rig / 10 mm vertical baseline
- XCover camera catalogue
- explicit rigid-station constraint
- explicit raw-to-Maths-backed evidence promotion boundary
- projection/inverse-ray consistency
- Maths-owned provider payloads
- move/resize/camera-height
- photo observation
- explicit-control similarity registration
- Neilston retail topology

The exact Maths v0.14 dependency's own `test_math3d.rex` was also executed under the same ooRexx runtime and ended with `PASS oorexx_maths Math3D 74 assertions`.

## Machine-readable receipts

See `qualification/qualification-index.json` and `qualification/receipts/*.json`. Receipts deliberately qualify named tests against an exact runtime/dependency set rather than making a blanket maturity assertion.

## Not executed

`tests/test_python_provider_macrospace.rex` targets exact Python Macrospace v0.31.2. It remains `NOT_RUN` because the v0.31.2 archive/runtime was not available in this execution environment. Its expected SHA-256 is locked as `f7c999c66e3b631a099821da804ae111fa02586ba1550864171151f86a585baf`; Photo World does not silently substitute v0.31.0.

The v0.31.2 arbitrary-arity `@ARGS:` contract is therefore represented by source and compatibility metadata but is not claimed as executed by this artifact. Sparse omitted-position semantics remain a separate bridge/foundation qualification concern.
