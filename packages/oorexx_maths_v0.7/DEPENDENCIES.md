# Dependencies — ooRexx Maths v0.7

## Required

Qualified against the user-supplied ooRexx 5.3.0 r13196 Internal Test Version. PURE/REFERENCE decimal and exact-number lanes require no Python runtime.

## Optional Foreign Runtime providers

Baseline: ooRexx Foreign Runtime v0.22.5 from `oorexxapis(20260901-121025).zip`.

Observed qualification-host stack:

- Python 3.13.5
- NumPy 2.3.5
- SymPy 1.14.0
- mpmath 1.3.0
- scipy-openblas configured for NumPy BLAS/LAPACK

Targeted Foreign Runtime v0.22.5 prerequisites also pass: NumPy reverse import 3/3, NumPy zero-copy 4/4, and Python DLPack tensor 15/15.

python-flint is absent on the assistant qualification host. The FLINT-ARB adapter remains capability-gated at python-flint >= 0.9.0. The user's FLINT-enabled environment qualified the v0.4 FLINT certificate/planner surface 8/8; v0.7 requires its own rerun before claiming the optional FLINT total.

## Optional Crypto

Qualified with ooRexx Crypto v0.8.3 for SHA-256 sealing of canonical `.MathEvidence` and `.MathProof` objects.


## bitsandbytes relationship

bitsandbytes is **not** a required dependency in v0.7. Its public NF4/blockwise/QuantState design is used as prior art for provider-neutral Maths objects. The PURE NF4 reference path embeds the published 16-value NF4 codebook as mathematical constants and performs its own exact-rational reference quantization. A future accelerated bitsandbytes provider must be separately capability/version qualified.
