# ooRexx Vision v0.1-dev1 architecture

Vision is a machine-processing knowledge representation, not a viewing codec.

## Authority split

- `VisionSurface` is an N-bit spatial field with V declared values (`V <= 2**N`).
- `VisionPackedValues` owns exact packed-bit representation only.
- `VisionValueModel` gives values meaning; `VisionColourModel` is the first concrete model.
- `VisionRegion` is the coordinate/time primitive for area-of-interest refinement.
- `VisionProcessor` is the processing contract. There is deliberately no `VisionNetworkProcessor`.
- Distributed execution is `VisionProcessor` work transported by Queue Fabric. Source/intermediate/result material is held or referenced through Storage Fabric.
- Queue messages carry identity, StorageRefs, coordinates/time ranges, processing parameters, generation/authority and result references; large raster/video payloads do not belong in Queue Fabric messages.

## Hierarchical processing

The low-resolution stream is intended to be continuously processable. It discovers evidence sufficient to request selective source detail. A `VisionRegionRequest` can request a higher spatial density and/or a larger N/V budget for one region and time interval. `VisionRegionMaterial` retains its relationship to the low-resolution knowledge surface and the authoritative source rather than replacing either.

## Processing layers

1. spatial/value encoding (`VisionSurface`)
2. lossless temporal coding/keyframes
3. line continuity / contour graph
4. movement and persistent-region evidence
5. classification/ML interpretation
6. selective high-resolution AOI materialization

Measurement remains deterministic where possible. ML interprets measured evidence; it does not redefine basic geometry, pixel/value identity, time or source authority.

## Maths and Foreign Runtime

Geometry, vectors, transforms and projection should use ooRexx Maths rather than private Vision mathematics. Foreign Runtime is the acceleration seam for hot loops (resampling, palette search, distance matrices, packing/unpacking, deltas and line extraction) while the public semantics remain ooRexx-owned.

## KL10 borrowing

The supplied KL10 `BinarySheet.cls` was inspected. Its packed-field implementation already establishes useful rules: arbitrary positive bit widths, explicit MSB/LSB bit order, bit-position parsing, precision sized from bit width, and no byte-endian suffix on non-byte-aligned packed fields. Vision dev1 borrows those semantics but does not depend on the KL10 package. `VisionPackedValues` is neutral and writable, which the Vision surface needs.


## dev2 palette and temporal layer

`VisionCurveLibrary` reconstructs any curve ID 0..254 deterministically. The wire
representation therefore needs only library identity plus three curve selectors.
`VisionPaletteSelector` reconstructs the exact 26-colour model and
`VisionPaletteDistanceMatrix` precomputes within-frame value distances.

`VisionSurfaceDelta` is deliberately lossless and simple. It carries a one-bit
changed-cell mask and only the N-bit values of changed cells. It does not decide
compression, keyframe cadence, motion compensation, or network transport.

`VisionKeyFrame` binds a normal parent surface to an optional refined surface.
The current experiment uses 2x2 subcells (four refined samples per parent), but
the object does not hard-code that ratio.

AOI/source detail remains a Storage Fabric concern. Queue Fabric transports the
small processing request/status/result references; raster/video material does
not become queue payload merely because processing is remote.

## dev3 coherent change and AOI
Temporal deltas can be converted to 4/8-connected components with explicit minimum cell count. Each records bounds, changed-cell count and occupancy density. `VisionAreaOfInterestDetector` promotes qualifying components while preserving evidence; `VisionAreaOfInterest~request` creates the existing StorageRef-backed selective-fidelity request. `VisionRefinedRegion` maps stable parent coordinates exactly onto optional refined keyframe subcells.

## dev4 compatibility break — sampling geometry

The dev3 aligned-refinement model is deleted. Stable Vision/world coordinates
are authoritative; changing lattice phase never changes the meaning of (x,y).

Coverage optimisation is defined as minimising the maximum uncovered radius of
the union of accumulated samples and the candidate refined lattice. The
deterministic pure-ooRexx probe implementation is the semantic reference.

Successive 32-mesh keyframes optimise against the already accumulated 8-mesh
and earlier 32-mesh phases. This provides temporal supersampling for static
geometry. Moving entities cannot be accumulated as if simultaneous: Movement
must transform observations into track/entity coordinates, retaining timestamp,
age and confidence.

## dev5 Movement seam
WORLD-to-TRACK compensation is explicit. The reference transform is translation;
Maths/Movement may provide richer transforms later without changing evidence
semantics. Track accumulation retains timestamp, age and confidence and never
asserts simultaneity. Persistent regions remain unclassified temporal evidence.

## dev6 Line Continuity
Boundary evidence is reproducible from the encoded Vision surface and its
value model. Raw RGB is not an input requirement. Geometry is projected through
the frame's actual sampling lattice into stable coordinates. Movement may then
compensate paths into TRACK coordinates for temporal accumulation. Strength,
continuity, stability and length remain distinct evidence dimensions.

## dev7 vector/topology vocabulary
Continuity geometry now has an initial compact 8-direction run representation.
Topology analysis promotes shared endpoints of degree >=3 to junctions and
endpoint closure to explicit contours. These are geometric facts, not object
classifications. The vocabulary is intentionally independent of Movement:
Movement may transform/associate geometry in TRACK space without redefining
line topology.

## dev8 measurable evidence and ROI escalation
Geometry preservation is now an explicit measurement product rather than an
impression from preview images. Measurements retain phase/time and separate
boundary, path, length, junction, contour, strength and continuity dimensions.
WORLD and TRACK series remain distinct.

ROI escalation consumes these measurements. It requests higher-resolution
source material only when declared evidence requirements are not met. This
closes the initial loop: cheap Vision evidence -> geometry/Movement reasoning ->
measured insufficiency -> targeted authoritative-source refinement.

## dev9 first live bench
Termux camera acquisition is a source adapter only. Camera JPEG/video remains
authoritative source material. The same decode/reduction boundary used for
recorded material produces VisionSurface evidence. Three-target recognition is
then performed from Line Continuity and closed-contour geometry; it must not
consult raw RGB to decide which regions are targets.

## dev10 real-camera qualification
The correctly-oriented Termux capture establishes the first positive fixture.
Reduction precedes recognition. Absolute brightness is insufficient because the
projection surface itself may dominate; local contrast and continuity are
therefore evidence dimensions on the reduced Vision surface. Empirically tuned
thresholds belong to bench diagnostics, not the format or semantic contract.
