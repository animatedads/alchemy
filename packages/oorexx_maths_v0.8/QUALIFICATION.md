# Qualification record — ooRexx Maths v0.8

## Runtime baseline

- ooRexx 5.3.0 r13196 Internal Test Version from the user-supplied package.
- Foreign Runtime v0.22.5 from `oorexxapis(20260901-121025).zip` for NumPy/Python provider lanes.
- Crypto v0.8.3 plus Runtime Reference v0.4 and the package's Foreign Runtime/OpenSSL provider for the accelerated sealing lane.
- Python on the assistant qualification host: NumPy 2.3.5, SymPy 1.14.0, mpmath 1.3.0.
- python-flint is not installed on this host; the FLINT-ARB lane remains an explicit SKIP here.

## Final executed suite

The final working tree was run through `run_tests.sh` with NumPy, proof providers and accelerated Crypto enabled.

| Lane | Assertions |
|---|---:|
| core | 18 |
| claims | 10 |
| rational scalar | 15 |
| exact numbers | 24 |
| decimal expansion | 25 |
| rational round-trip | 50 |
| quantization | 31 |
| mixed precision | 9 |
| **Math3D v0.8** | **74** |
| rational matrix/vector | 15 |
| proof planner | 18 |
| NumPy | 14 |
| proof planner / NumPy | 8 |
| SymPy/mpmath proof providers | 17 |
| proof planner / providers | 9 |
| Crypto evidence/full-proof sealing | 6 |
| **Executed total** | **343 PASS** |

FLINT-ARB remains an 8-assertion capability lane. The user's FLINT-enabled environment qualified the equivalent v0.7 provider/planner surface previously; v0.8 must be rerun there before claiming the optional **351/351** cross-environment total.

## v0.8 Math3D qualification

`tests/test_math3d.rex` contains 74 assertions covering:

- explicit angle units and degree/radian conversion;
- degree reduction including very large degree inputs;
- magnitude-aware high-precision radian reduction;
- sine/cosine cardinal values;
- caller precision isolation (`NUMERIC DIGITS 9` caller with 50-digit Maths context);
- Vector3 add/dot/cross/norm/normalization/scaling;
- exact 3-4-5 norm in a rational context;
- fail-closed irrational square root and trigonometry under a rational context;
- quaternion axis-angle construction, normalization, conjugate, inverse, multiplication and Vector3 rotation;
- the historical negation/half-angle precision-leak regressions;
- quaternion -> Matrix3 agreement;
- 4x4 translation/rotation/scale composition;
- transform inverse round-trip;
- point versus direction homogeneous semantics;
- right-handed and left-handed `lookAt` construction;
- row/column-major layout export;
- OpenGL, Vulkan and DirectX perspective depth mappings;
- OpenGL orthographic boundary mappings;
- Ray3D and Plane3D geometry;
- `.Maths` 3D factories and evidence paths.

See `VALIDATION_MATH3D.txt` and `ANGLE_REDUCTION.md`.

## Angle-reduction defect closure

The apparent trig defect was traced to arithmetic performed before a method established the intended working precision. The permanent regression deliberately lowers caller precision to 9 digits and verifies that quaternion construction, rotation, inversion and angle halving still obey the 50-digit Maths context.

This is a release gate for future 3D changes: no helper may rely on increasing precision after an argument expression has already been rounded by its caller.

## Foreign Runtime prerequisite rerun

Direct rerun against Foreign Runtime v0.22.5:

- PASS optional NumPy reverse-import 3/3
- PASS optional NumPy zero-copy 4/4
- PASS Python DLPack tensor 15/15

## Crypto lane

The six Maths sealing assertions pass through Crypto v0.8.3 with `.CryptoForeignRuntimeInstaller~install`, using its Runtime Reference / Foreign Runtime / OpenSSL provider. This avoids turning slow portable SHA execution on the debug ooRexx build into an artificial Maths qualification timeout.

The original portable Crypto path is preserved; accelerated qualification does not change Maths proof/evidence semantics.
