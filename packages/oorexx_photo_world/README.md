# ooRexx Photo Survey World v0.1-dev18

Geometry-first multi-photo world reconstruction. Photographs are independent calibrated observations of one world; they are never pixel-stitched into a panorama.

## dev4
- Adds `SurveyBundle.cls`: persistent world features, per-photo 2-D observations, XCover camera projection and reprojection residuals.
- Adds a local street coordinate frame: +X along street, +Y across street, +Z up.
- Adds `SurveySvg.cls` for dependency-free engineering top-down output.
- Adds `examples/paisley_bundle.rex`, a deliberately provisional world hypothesis for the supplied pedestrian-street photo set, with nine distinct 1.60 m camera stations.
- Adds a projection regression test.

The provisional building widths, depths, camera stations and attitudes are hypotheses, not claims of surveyed dimensions. Refinement is driven by multi-photo reprojection agreement. No Python, OpenCV, image-generation model or panorama warp is part of this package.

## dev5: measured XCover Pro dual-camera rig

The supplied same-station pair `1000061224.jpg` / `1000061225.jpg` is represented as a rigid rear-camera rig rather than two independent survey stations. The user measured the rear camera optical centres as 10 mm apart vertically. `SurveyCameraRig` stores camera-module offsets in metres and `SurveyRigStation` places both cameras from one handset station. The wider image is assigned to the XCover Pro ultra-wide lens and the narrower image to the main lens. The physical upper/lower module identity is deliberately not claimed yet; reversing the vertical sign is a calibration convention change, not a world-geometry change.

## v0.1-dev6 — inverse rays and explicit constraints

Dev6 adds the next geometric half of the survey model: `SurveyCameraGeometry~pixelRay()` is the algebraic inverse of the existing world-to-pixel projection, and horizontal-plane intersection is available for explicit measured/annotated image points. It does **not** discover image features or infer correspondences.

`SurveyConstraints.cls` makes physical evidence first-class. The first locked constraint is the supplied XCover Pro dual-camera observation: both photographs share one handset station and their rear camera centres are separated by 0.010 m vertically. The sign/order of that vertical offset remains a calibration hypothesis until independently established.

This establishes the intended solve loop: world point -> camera projection -> pixel residual, and annotated pixel -> camera ray -> world constraint. Geometry, observations, rig authority, and residuals remain ooRexx-owned.

## v0.1-dev10 — stitched survey-area engineering map

Adds `SurveyAreaMap.cls` and `examples/paisley_area_map.rex`.  This is a deterministic ooRexx engineering map assembled from the supplied overlapping aerial screenshots as named/topological constraints. It is deliberately not a synthetic satellite image and does not pixel-warp Google imagery. Every map primitive carries an evidence state (`OBSERVED`, `CARTOGRAPHIC`, or `DERIVED`) and optional uncertainty in metres. The renderer exposes those distinctions in the SVG and prints the uncertainty legend.

The initial Paisley area map connects the photographed town-centre survey to the south/east aerial sequence through Paisley Arts Centre, New Street, Witherspoon Street, Causeyside Street, Paisley Canal, Neilston Road, Falside Road, Braids Road and Park Road. Coordinates are a local engineering frame and remain provisional until solved from measured correspondences.


## dev8 area-map extension

Three additional supplied aerial screenshots extend the evidence map south and south-west from the previous Park Road boundary. New provisional anchors include Saucehill Park, Charleston, Brodie Park, Royal Alexandra Hospital, Lochfield Road, Stanley Road, Gallow Green Road and Canal Street. These remain evidence/topology anchors with explicit uncertainty; they are not claimed as surveyed coordinates.


## dev9 evidence correction
Corrected the Neilston Road retail topology from supplied aerial evidence: ALDI is north of Neilston Road; Morrisons is south of Neilston Road; Morrisons Petrol Station is west/north-west of the main Morrisons store. Absolute coordinates remain provisional until image registration solves them.

## dev10 registration boundary
`rexx/SurveyRegistration.cls` adds explicit evidence-frame control points and a weighted 2-D similarity solver. It performs no feature discovery and reads no pixels. Correspondences must be supplied explicitly; solved transforms report RMS residual and preserve source/uncertainty metadata. This is the first step from hand-positioned topology toward evidence-derived area coordinates.


## dev11 Maths authority integration
Photo Survey World now pins ooRexx Maths v0.14. `SurveyRegistration2D` no longer owns a private square-root implementation: registration magnitude, point residuals and RMS residuals use `.Maths~sqrt()` under the Maths context. Existing camera/world geometry continues to use Maths angles, trigonometry and Vector3 objects. Photo Survey World owns survey semantics and constraints; reusable numerical mathematics belongs to Maths.

## dev12 foreign provider boundary
Adds `SurveyForeignProviders.cls`. Depth, geolocation and mesh processors are
explicit evidence providers, not SurveyWorld authorities. The Python-facing
adapters accept an already-projected Alchemy Python object; Python class loading,
object identity, dispatch and lifetime remain the responsibility of Python
Macrospace / Alchemy Foreign Object. Returned products are wrapped as
`SurveyDerivedEvidence` with kind, provider/version, source digest and coordinate
convention. No provider receives authority to mutate `SurveyWorld`.

Intended first consumers are Depth Anything V2 (soft depth evidence), GeoCLIP
(candidate geographic hypotheses) and PyMeshLab (candidate mesh processing).
This release does not vendor those Python projects and does not perform image
recognition itself.

## dev13 Macrospace resident-provider qualification
Adds a small stateful Python provider plus an ooRexx regression which loads it via
`.AlchemyPythonClass~loadCls`, constructs one resident Python instance, wraps it
in `SurveyPythonDepthProvider`, and invokes it twice. The second result must retain
Python-side state from the first call. This proves the Photo World seam uses a
resident foreign object, not process-per-call glue. The probe does not inspect an
image; dev13 originally left dense depth arrays outside the v0.31 scalar marshalling contract; dev14 resolves that architectural question by assigning numerical arrays/matrices to Maths rather than Macrospace.


## dev14 Maths-owned foreign numerical payloads

Photo Survey World now makes the numerical-authority boundary executable. `SurveyDepthField` requires a Maths `MathMatrix`; `SurveyMeshCandidate` requires Maths matrices for vertices and faces (and optional normals); `SurveyMathPayload` accepts only `MathValue` instances. Immediate Python adapter results are marked `DEPTH_RAW`, `GEO_CANDIDATES_RAW` and `MESH_CANDIDATE_RAW` so foreign output cannot silently masquerade as accepted survey geometry. Promotion to `SurveyDepthEvidence` or `SurveyMeshEvidence` requires Maths-owned numerical material.

The optional Python class/object dependency is advanced to Macrospace v0.31.2 (SHA-256 `f7c999c66e3b631a099821da804ae111fa02586ba1550864171151f86a585baf`). Its arbitrary-arity `@ARGS:` crossing is represented by a five-argument constructor, instance-method and classmethod regression. The v0.31.2 archive itself is not bundled because the current ChatGPT attachment channel did not expose it; the stale v0.31.0 archive has been removed.

See `NUMERICAL_AUTHORITY.md`.

### dev14 test-harness repair
The older tests that placed `::requires` before later executable statements have been normalised so ooRexx does not enter directive mode before the test body. Translation-time relative paths now resolve from `tests/` consistently, and the previously implicit move/resize dependency is explicit. This is a qualification-harness repair, not a world-model behaviour change.

### dev14 rigid-rig runtime repair
Real ooRexx qualification exposed a latent `SurveyRigStation~cameraPosition` scope bug: `_x`, `_y` and `_z` were not exposed in the method, so the interpreter treated their names as nonnumeric literals. dev14 explicitly exposes the station coordinates before applying the camera-module offset. This repairs the existing 10 mm rigid-pair path and constraint test; it does not change the handset-coordinate convention.

### dev14 qualification status
Real ooRexx 5.3.0 r13196 qualification now passes all 11 currently executable non-Macrospace regressions, including the new Maths-owned payload test and the repaired 10 mm camera-rig/constraint path. The Macrospace v0.31.2 crossing regression is packaged but not claimed as executed because that archive was unavailable in this sandbox. See `QUALIFICATION_DEV14.md`.

## dev15 — portfolio-review hardening and explicit promotion lineage

Dev15 applies the relevant portfolio code-review rules without importing its stale version inventory. `compatibility-lock.json` now locks the Photo World semantic API, ooRexx r13196 qualification target, exact dependency hashes, authority boundaries, bundled-vs-external status and qualification state. Bundled dependency ZIPs are explicitly sealed-delivery snapshots rather than development source authority.

Machine-readable receipts under `qualification/` distinguish `PASS` from `NOT_RUN`. The optional Macrospace v0.31.2 crossing remains `NOT_RUN` in this environment; its expected hash is locked rather than silently falling back to an older bridge.

`SurveyEvidencePromotion` makes the model-output boundary executable. Supported `DEPTH_RAW` and `MESH_CANDIDATE_RAW` evidence can be promoted only to the corresponding Maths-backed survey evidence while preserving source digest, provider and provider-version lineage and supplying an explicit basis. The promotion record has no SurveyWorld mutation authority.

See `AUTHORITY_AND_DELIVERY.md`, `DESIGN_REVIEW_ALIGNMENT.md`, and `compatibility-lock.json`.


## dev16 — standards-enforcer repair

Dev16 adds the Claude-supplied `oorexx_standards_enforcer.py` as an explicit static release gate and repairs every fatal finding it reported against dev15. `SurveyImageProcessing` no longer relies on `&` as a short-circuit operator; the depth-kind/metric-unit checks in `SurveyDepthField` are explicitly branched; and the three foreign-provider adapters no longer use the reserved/discouraged local name `result`.

The affected runtime regressions were strengthened so uncropped images carrying crop metadata still retain stored dimensions, real cropped dimensions are honoured, unsupported depth kinds fail closed, and metric depth without units fails closed. All 12 executable Photo World regressions plus the exact Maths v0.14 Math3D suite were rerun under the user-supplied ooRexx 5.3.0 r13196 runtime.

The standards enforcer now returns `VERDICT: PASS` with zero errors. Six `PRIVATE_METHOD` warnings remain intentionally reviewed: the methods are synchronous class-internal renderer/catalogue helpers and are not sent across a Message activity boundary. Their source comments now state that restriction explicitly; widening their visibility merely to silence a contextual warning would unnecessarily enlarge the callable surface. See `STANDARDS_ENFORCER_REVIEW.md` and `QUALIFICATION_DEV16.md`.

## dev17 — Macrospace v0.31.6 live Maths-object crossing

The exact supplied `oorexx_python_macrospace_poc_v0.31.6.zip` is now pinned as a sealed-delivery snapshot (SHA-256 `38175f11db8e7e7de28a37e4012c92a94109b4fbcfec7fb96ee166b4d4644c6b`) and has been built against the same ooRexx 5.3.0 r13196 qualification runtime used by Photo World. Its focused virtual-class regression family is rerun in this environment.

The Photo World crossing test is no longer merely an arbitrary-arity scalar probe. A real Maths v0.14 `MathMatrix` is passed from ooRexx into the resident Python provider as a retained Rexx object. Python operates that live Maths object naturally: `rows()`, `cols()`, positional `at(1,2)`, and the chained non-string return `context().provider()`. No Python tensor/array authority or serialization copy is introduced. Maths remains the numerical authority; Macrospace owns only live cross-runtime object projection and invocation.

The stateful depth-provider probe still proves resident Python identity across repeated inference calls, and foreign output remains `DEPTH_RAW` derived evidence with no direct `SurveyWorld` mutation authority. See `MACROSPACE_INTEGRATION.md` and `QUALIFICATION_DEV17.md`.

## dev18 — indoor measured-room survey, through Photo World code

dev18 adds the first indoor-room evidence slice.  It does not hand-wave a room
shape from photographs.  The current metric anchors are represented explicitly:

- opposite-wall span: **3.750 m**, measured;
- long-wall span: **5.000 m**, approximate user prior;
- left-reference to doorway/opening anchor: **2.750 m**, measured, with jamb /
  opening-width semantics intentionally not invented.

`SurveyIndoorRoomSolver` solves the first two-parameter Manhattan envelope
through the ooRexx Maths matrix solver.  The resulting rectangle is therefore a
**hypothesis**, not a promotion of image appearance into world truth.  For the
current evidence it is 3.75 m x 5.00 m (18.75 m2).  The opening anchor lies 2.75 m
along the 3.75 m reference wall, leaving a 1.00 m reference span to the opposite
corner under this hypothesis.  Door width remains unknown.

The six supplied room photographs are also exercised by a real Macrospace
provider (`PhotoWorldStructureProvider`).  Python/OpenCV LSD extracts only raw
2-D straight-segment evidence; it does not solve or mutate `SurveyWorld`.
Photo World wraps that output as `STRUCTURE_RAW`.  Geometry remains owned by
Photo World and reusable numerical solving by Maths.

`output/indoor_room_plan.svg` is generated by ooRexx code from the measured
constraints and hypothesis.  It is a diagnostic projection, not evidence.
