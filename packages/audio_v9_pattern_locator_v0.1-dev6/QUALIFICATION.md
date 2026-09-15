# Qualification — Audio V9 Pattern Locator v0.1-dev5

## Runtime

Open Object Rexx 5.3.0 r13196 Internal Test Version, 64-bit.

Supplied runtime package SHA-256 used by the qualification environment:

`8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`

## Pinned runtime dependencies

- ooRexx ML v0.1-dev10 ZIP:
  `8f7f104599e17035314645e300fceb9124735d779fc14c46d6c60ea9b44d6b89`
- ooRexx Foreign Runtime v0.22.6 ZIP:
  `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`

Documentation/reference-only input:

- ooRexx ML Gopher sphere v0.1-dev10 ZIP:
  `6878ed9a621543cb0be3fa857880ee386e77d0742edb173f33d916bc03cbd493`


## Dev5 Spectral Pattern Field / STOP-bucket qualification

Current locator suite under the pinned r13196 runtime:

```
PASS ALL Audio V9 Pattern Locator v0.1-dev5 TESTS (32 files)
```

Captured as two complete deterministic halves in `qualification/ITERATION5_DISTRIBUTED_TESTS_A.txt` and `qualification/ITERATION5_DISTRIBUTED_TESTS_B.txt` (16 + 16). New coverage includes:

- strict legacy CSR lookup still fails on an over-budget exact bucket;
- selective production lookup returns explicit `STOP` rather than truncating;
- STOP-fraction policy fails closed;
- child stdin cannot corrupt the pilot event stream;
- package-wide `NUMERIC INHERIT` with 30-digit executable roots;
- direct uniform-time frame bounds and cached cross-band common q50;
- moving spectral box lattice;
- affine-gain invariance of spectral-box `MLPatternHash`.

Synthetic spectral evidence:

```
stationary residual motion ≈ 0.346481 dB
stationary turn            ≈ 0.487519 dB
structured speech motion   ≈ 1.014970 dB
structured speech turn     ≈ 0.733980 dB
affine-gain box difference dominant=0 total=0
```

Real-fixture evidence is recorded in `qualification/SPECTRAL_PATTERN_FIELD_REAL_DEV5.txt`. In the supplied raw campaign 0..15 s versus supplied processed rank-01 0..15 s, 812 corresponding moving boxes give:

```
residual movement correlation = 0.9898689573233826
turn-geometry correlation     = 0.9871238635303846
mean abs residual-motion delta = 0.008507 dB
mean abs turn delta            = 0.013902 dB
```

These are structural evidence values, not probabilities or speaker-identity claims. Human time annotations were applied only after blind field extraction.


Distributed Spectral Pattern Field qualification:

```
10 s fixture, one node:     18 segments / 522 boxes
4 x 2.5 s work units:       18 segments / 522 boxes
worker completion order:    3, 1, 4, 2
merged segments:            byte-identical
merged boxes:               byte-identical
wrong master SHA-256:       FAIL CLOSED
missing unit result:        FAIL CLOSED
```

The work manifest pins the canonical float32 master SHA-256 and exact sample ranges. Work starts preserve the global 256-sample/32 ms FFT phase.

## Dependency qualification

Complete supplied ooRexx ML dev10 suite under r13196:

```
PASS ALL ooRexx ML v0.1-dev10 TESTS (57 files)
TOTAL_ELAPSED=9.75
```

Captured in `qualification/OOREXX_ML_DEV10_FINAL_TESTS.txt`.

Foreign Runtime base native boundary:

```
PASS 128 assertions
```

Captured in `qualification/FOREIGN_RUNTIME_NATIVE_TEST_FINAL.txt`.

## Locator qualification

Current dev5 locator surface:

```
PASS PART A 16
PASS PART B 16
PASS TOTAL 32/32
```

The split is a qualification-harness execution detail only; the package `run_tests.sh` still enumerates the complete suite. The two captured halves cover every `tests/test_*.rex` file exactly once.

Coverage includes all prior semantic/distributed/source-binding regressions plus STOP buckets, numeric inheritance, moving Spectral Pattern Fields, real-field scaling repairs, and exact one-node/distributed field equivalence.

## Performance regression and repair

During combined qualification, `test_native_worker_end_to_end` timed out at 120 s
inside repeated generic dev10 close-neighbour enumeration.  This was recorded as
F024 rather than hidden by increasing the timeout.

Repair R024 precomputes a 27-cell radius-1 relative stencil once, with every
`MLCloseHashDifference` produced by authoritative dev10
`MLCloseHashSchema~difference`.  Per-landmark work then applies the relative
coordinates and uses the retained ML difference object.  Dev10
`MLProbeKeyComparator` restores the public difference-score/key ordering.

`test_probe_stencil_equivalence.rex` proves exact bucket/difference equivalence at
interior and boundary coordinates.  The formerly timing-out end-to-end worker
completed in 1.66 s before ordering restoration and 3.20 s after restoring the
public ML ordering contract.

## Compile/native surface

Strict native rebuild:

```
cc -std=c11 -O3 -fPIC -Wall -Wextra -Werror -shared ...
```

PASS; captured in `qualification/NATIVE_BUILD_DISTRIBUTED_DEV5.txt`.

Rebuilt provider SHA-256:

`fcd44f1db808a9d163c778020de6044abcea61a6916c925bfb3505aa08d99284`

Exact r13196 `rexxc` PASS for all 18 delivered source/tool Rexx files: six `src/*.cls` and twelve `tools/*.rex`. Captured in `qualification/REXXC_DISTRIBUTED_DEV5.txt`.

## Clean-byte seal requirement

The final package is not accepted until a clean extraction of the final ZIP:

1. verifies every `MANIFEST.sha256` entry;
2. reruns all 32 locator tests;
3. recompiles all 18 delivered class/tool Rexx files;
4. strictly rebuilds the native provider.

That evidence is appended to `PROGRESS.md` and recorded here before the final
release hash is reported.

## Deliberate non-claims

- No live ED209 pilot execution is claimed by this local qualification.
- No 671-event final trajectory has yet been produced by this ooRexx line.
- Structural difference values are deterministic evidence, not confidence
  percentages.


## Dev5 clean-candidate evidence

Candidate ZIP SHA-256:

`e1285280149628db15581eb261ac5b139cc40d583ffb54dff17d4634b3e210d2`

A new extraction verified 133/133 manifest entries and then passed:

- locator 32/32 (16 + 16 complete halves);
- ooRexx ML dev10 57/57;
- Foreign Runtime base native boundary 128 assertions;
- strict native provider rebuild with SHA-256 `fcd44f1db808a9d163c778020de6044abcea61a6916c925bfb3505aa08d99284`;
- r13196 `rexxc` 18/18 delivered class/tool files.

The corresponding transcripts are bundled as `qualification/CLEAN_CANDIDATE_*_DEV5.txt`.
