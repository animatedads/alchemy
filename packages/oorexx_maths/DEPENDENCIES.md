# Dependencies — ooRexx Maths v0.17

## Required runtime

The mathematical reference/exact implementation requires ooRexx. This release was freshly qualified against the user-supplied **ooRexx 5.3.0 r13196 Internal Test Version** package:

- artifact: `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(20260925-083247).deb`
- SHA-256: `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

PURE/REFERENCE DECIMAL and RATIONAL lanes need no Python runtime.

## Optional resident/native providers

Fresh v0.17 qualification used:

- ooRexx Foreign Runtime v0.22.6, artifact `oorexx_foreign_runtime_v0.22.6(8).zip`, SHA-256 `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`;
- Python 3.13.5;
- NumPy 2.3.5;
- SciPy 1.17.0;
- SymPy 1.14.0;
- mpmath 1.3.0;
- distribution RxMath for compatible native scalar operations.

These are implementation providers, not mathematical authorities. BINARY64 narrowing remains explicit. Foreign Runtime owns bridge/object-lifetime semantics; Maths owns mathematical domain, precision, proof and provider-selection policy.

`python-flint` is not installed in this qualification environment. FLINT-ARB therefore remains an explicit capability SKIP, not a PASS.

## Optional Crypto sealing

Maths supports ooRexx Crypto evidence/proof sealing. **Crypto is NOT_RUN for the v0.17 fresh qualification** because exact Crypto v0.8.3 and Runtime Reference v0.4 executable artifacts were not available in the current input set. Older Crypto qualification records remain historical evidence and are not counted in the v0.17 assertion total.

## Dependency authority

Maths does not vendor Foreign Runtime, Crypto, Runtime Reference, Physics World or Rexx-tronics as development source authority. Consumer packages may motivate reusable mathematical kernels, but their physical/electrical semantics remain outside Maths.

The machine-readable lock is `compatibility-lock.json`.
