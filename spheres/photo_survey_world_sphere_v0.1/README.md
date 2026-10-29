# Photo Survey World sphere v0.1

Authoritative project-continuity sphere for ooRexx Photo Survey World.

## Authority and scope

Photo Survey World owns survey-world semantics: photographs as observations of one world, camera/rig observations, explicit survey constraints, image-to-world correspondence, room/street/area topology, derived-evidence promotion, and reconstruction state. It does not own reusable mathematics, physical simulation, Python runtime semantics, or third-party model truth.

The authority split is deliberate:

- **Maths** owns vectors, matrices, transforms, rays/planes, numerical solvers, precision/provider semantics and higher mathematics.
- **Physics World** owns physical-world semantics consumed by later coupled survey constraints. Photo World depends on Physics; Physics must not import Photo World.
- **Upstream ooRexxPython + the Alchemy adapter** own the supported Python bridge direction for new work. Macrospace v0.31.x remains historical qualification evidence for dev21, not an active competing native implementation.
- **Python providers** such as Depth Anything V2, GeoCLIP, PyMeshLab and the current OpenCV LSD structure probe may contribute derived evidence; they do not mutate `SurveyWorld` or decide geometry.
- **Photo Survey World** decides whether observations and derived evidence coexist in a plausible survey world.

## Current accepted implementation evidence

The current Library head is `oorexx_photo_world_v0.1-dev21.zip`, SHA-256 `ab63a8fcd453623cc371ccfda71f60588256260251d6f71deb338a6e85b97707`.

Dev21 adds Rexx-owned multi-view image geometry over its then-qualified Macrospace-delivered primitive segments. OpenCV/Python performs only LSD line detection. Accepted segments cross as live ooRexx objects; Photo World + Maths own vanishing-point consensus, weighted refinement, Manhattan/lens checks and all survey semantics.

The six indoor views produced 27 / 40 / 20 / 26 / 33 / 9 accepted segments and 3 / 3 / 2 / 2 / 3 / 1 vanishing families. The nominal XCover Pro main-lens prior is supported only where the orthogonality-quality gate is met; unresolved views remain unresolved instead of selecting a least-bad lens.

## Indoor-room authority correction

The room wall carrying the projector screen is an old chimney breast. The screen is mounted on the projecting breast face, with a recessed alcove on **both** sides. The authoritative wall topology is:

`LEFT_ALCOVE_REAR -> LEFT_RETURN -> CHIMNEY_BREAST_FACE -> RIGHT_RETURN -> RIGHT_ALCOVE_REAR`

Supplied metric observations remain in their original roles:

- left wall to doorway: 2.750 m, measured;
- opposite wall: 3.750 m, measured;
- long wall: approximately 5.000 m, estimated prior.

These measurements are not rectangle axes. The package must not invent chimney-breast width, projection depth, alcove widths, room area, or doorway/jamb binding until solved or measured.

## Current dependency note

Dev21 remains exactly qualified against its sealed snapshots: Maths v0.14, Physics World dev46 and Python Macrospace v0.31.6. That historical lock is not rewritten after the fact.

Current canonical GitHub candidates have moved:
- **Maths v0.19**, baseline archive SHA-256 `cf92eac71498450fb688569328833b33b122942de89450a4022d9d824c778f40`, freshly qualified under ooRexx r13196.
- **Physics World v0.1-dev50.2**. The dev50.2 journal-preflight source and deterministic regression fixture are committed, but its own validation record says the r13196 execution and package-wide standards/test pass are still NOT RUN.
- **Alchemy upstream ooRexxPython adapter v0.2**. The old Macrospace native development line is retired. The adapter delegates native bridge authority to `JosepMariaBlasco/oorexxpython`; upstream thread qualification requires ooRexx 5.3.0 r13265+.

Therefore the next Photo World Python-provider release must migrate to the upstream adapter and be qualified on a suitable runtime; the existing r13196 Macrospace PASS is historical evidence, not proof of the replacement bridge.

## Near-term work

1. Establish persistent wall-corner correspondences across the six indoor views.
2. Solve camera translations/stations against the measured room constraints; do not infer them by eye.
3. Solve the two alcove breakpoints and chimney projection depth against the authoritative topology.
4. Rebase the numerical layer onto Maths v0.19 and rerun Photo World regressions before changing the dependency lock.
5. Reconcile Photo World/Physics interfaces against Physics World dev50.2; do not inherit its unexecuted dev50.2 qualification as a PASS.
6. Move Python-provider crossings to the Alchemy upstream ooRexxPython adapter. Depth Anything V2 remains soft depth evidence; GeoCLIP geographic candidates and PyMeshLab candidate mesh processing remain non-authoritative.
7. Qualify the replacement Python bridge on the upstream-required ooRexx runtime before retiring the dev21 historical Macrospace receipt.
8. Continue running the ooRexx standards enforcer directly against final release ZIPs.

This sphere is documentation/project-continuity authority only. It grants no authority to alter measurements, promote model output into surveyed truth, or mutate external package authority.
