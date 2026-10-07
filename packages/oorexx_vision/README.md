# ooRexx Vision v0.1-dev10 — real Termux three-target bench

dev10 grounds the first live bench in the supplied correctly-oriented Termux
camera capture.

The authoritative camera image is reduced first to the normal ~4K Vision
evidence scale. Target discovery then uses local contrast, Line Continuity and
compact closed-region geometry; raw-resolution RGB is not a recognition input.

Adds `VisionLocalContrast` and `VisionProjectedTargetPolicy`, plus a derived
55x73 positive fixture. The fixture demonstrates the intended processing
boundary without redistributing the full camera source.

The target is deliberately "three compact projected regions", not "three
mathematical squares": perspective and clipped/sloping corners are legitimate.

No hand recognition, gestures or 3D callbacks are in this qualification.


## dev14 — V5V codec + selective high-resolution request

This package adds the current V5V temporal codec contract and the explicit
high-resolution evidence request module.

`V5VTemporalCodec` treats the encoded VisionSurface as the observation to
preserve.  Exact keyframes and exact `VisionSurfaceDelta` records are the
baseline.  Camera Behaviour and Line Assessment may later supply advisory
evidence maps for smarter packing, but neither becomes part of the codec and
EXACT_SURFACE policy may not silently discard observations.

`VisionHighResolutionRequest` wraps the existing `VisionRegionRequest` contract.
It identifies the authoritative source, stable region, time interval, requested
source resolution and purpose.  Fulfilment is represented by
`VisionRegionMaterial`; large media bytes remain behind the material/source
reference rather than being embedded in the request object.

The current phone/live FFmpeg source from dev13 remains included.


## dev15 repair/qualification increment

* Repairs dev14 `VisionSurfaceDelta~between(...)`: the authoritative class uses
  `VisionSurfaceDelta~new(previous,current)`.
* Adds exact V5V encode/decode round-trip coverage.
* Keeps `EXACT_SURFACE` as the admitted baseline; lossy evidence suppression is
  not silently enabled.
* Adds explicit REQUESTED -> FULFILLED lifecycle to selective high-resolution
  requests while retaining `VisionRegionMaterial` as the returned evidence
  reference.


## dev16 — 27 Sep portfolio synchronization

dev16 rebases this working line on the portfolio-review candidate
`dev15-repaired1`, retaining its ooRexx 5.3 runtime repairs.  It also imports
the independent `LineAssessment` compatibility seam as an adjunct source and
test so line evidence has one reusable implementation rather than being
reimplemented by each Vision consumer.

Camera Behaviour is deliberately not folded into Vision: its current v0.57
candidate remains a specialist consumer and is still manual-review pending in
the portfolio checkpoint.  See `PORTFOLIO_SYNC_2026-09-27.md`.

## dev17 — standards repair

Reviewed against `oorexx_standards_enforcer.py` after the 27 Sep portfolio sync.
Hard findings were repaired using native ooRexx control flow rather than comments
or suppressions.  In particular, boolean `&` expressions were replaced with
short-circuit-safe nested decisions or equivalent failure-disjunctions.  The
phase expression now spells `.5` so the checker does not misread `+0.5` as the
forbidden `+ 0` coercion idiom.  Compact one-line test loops were expanded so
internal routine labels are no longer misclassified as labels inside loops.

The enforcer's loop-invariant and private-method diagnostics remain review
signals rather than automatic rewrite instructions: loop-mutated state and
receiver-local private helpers are retained where their semantics are correct.
`family.rex` was used as a positive ooRexx example for inherited accessor and
message-dispatch semantics; checker appeasement does not override the language
object model.

## dev18 — runtime-qualified standards repair

The 7 Oct Library supplied ooRexx 5.3.0 r13196, allowing this branch to be
executed rather than source-reviewed only.  That qualification exposed two
predicate inversions introduced during the dev17 standards cleanup.  Both are
repaired and all 11 package tests now pass under the real interpreter.  See
`QUALIFICATION_2026-10-07.txt`.

## dev19 — lattice topology + non-face human behaviour evidence

Merged the earlier lattice-topology work forward onto the runtime-qualified dev18
baseline. `VisionSamplingLattice` now owns RECT/HEX logical neighbour contracts,
and boundary extraction consumes those contracts; HEX samples no longer silently
fall back to rectangular right/down adjacency.

Adds a deliberately non-recognition semantic seam for bodycam/CCTV discovery:
`VisionHumanBehaviourVector`, `VisionEntityEvidence`, `VisionEntityEvidenceSet`,
`VisionEntityClassifier` and `VisionEntityHypothesis`.  The human behaviour vector
contains persistence, coherent motion, articulated motion, periodicity, body
scale, continuity and scene context.  It has no face or landmark field.  ML may
classify this evidence later without becoming authority for geometry, tracking,
time or source identity.  High-resolution face/body inspection remains a later
selective AOI operation when justified.
