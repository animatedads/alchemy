# Three-officer hall structural probe

Sources supplied by the Architect:

- `1000060474.mp4` — 1920x1080 encoded, portrait display rotation, 30 fps, 42.0534 s, 1259 frames.
- `1000060565.mp4` — 1920x1080 encoded, portrait display rotation, 30 fps, 50.1842 s, 1506 frames.
- `1000060567.mp4` — 1920x1080 encoded, portrait display rotation, 30 fps, 31.5234 s, 946 frames.

## Result

The hall supports a much cheaper structural route than generic dense point-cloud reconstruction.
The recurring evidence is:

1. a bottom-connected dark support surface (carpet / floor),
2. long floor/wall contact edges,
3. repeated door-jamb verticals,
4. support-surface continuation through open doorways,
5. direction changes at floor level which become structural-corner candidates when registered across camera motion.

The supplied `three_officer_C_support_frontier.jpg` is a diagnostic extraction across officer C around the hall / kitchen threshold.  Yellow is the detected support frontier and green is the bottom-connected support region.  The important signal is not floor colour itself but the frontier opening and closing as the camera approaches/passes an opening.

The supplied `officer_B_C_floor_registration.jpg` registers officer C 0.5 s onto officer B 0.0 s using only candidate features inside the detected floor/support region.  In this exploratory design probe, 59 of 73 tentative floor-only correspondences survived the planar homography RANSAC gate (80.8%).  The warped floor boundaries visibly coincide over most of the hall.  This is strong evidence that the floor plane can act as the common registration spine between independent bodycam traversals.

Additional exploratory floor-only correspondence checks (not production algorithms):

| Relation | tentative | planar inliers | note |
|---|---:|---:|---|
| officer A 0.00 -> 0.25 s | 129 | 83 | same-camera floor motion |
| officer B 0.00 -> 0.25 s | 187 | 170 | very strong same-camera floor motion |
| officer C 0.50 -> 0.75 s | 59 | 49 | strong same-camera floor motion |
| officer B 0.00 -> officer C 0.50 s | 73 | 59 | strong cross-officer floor registration |
| officer A 1.50 -> officer B 4.00 s | 22 | 12 | weaker overlap / changed view |
| officer A 4.00 -> officer C 1.00 s | 17 | 9 | weaker overlap / changed view |

Those numbers were obtained with a temporary desktop feature probe against source frames solely to test the hypothesis.  They are **not** a new runtime dependency and they do not define Vision semantics.  Dev4 implements the structural contracts in ooRexx over compact `VisionSurface` evidence and Maths v0.8.

## Architectural consequence

The preferred indoor-building first pass is now:

```
V5V compact frame
   -> bottom-connected support surface
   -> support frontier
   -> floor-plane registration across movement / cameras
   -> floor-wall boundary segments
   -> support continuation gaps => opening candidates
   -> approximately orthogonal registered segments => corner candidates
   -> sparse building skeleton
   -> geometry-evidence refinement requests
   -> only then dense surface / object refinement
```

This is deliberately not a claim that every building is orthogonal.  The Manhattan-world constraint is an explicit prior with a tolerance; evidence outside it remains available to non-orthogonal models.

## What can already be calculated safely

Without a trusted metric scale, the footage supports projective / relative structural calculations rather than centimetres:

- independent camera traversals can be registered on the floor plane;
- floor/wall boundary segments can be accumulated in a common floor coordinate system;
- gaps where the support surface continues can be represented as opening candidates;
- wall-direction changes can be tested over movement rather than classified from one frame;
- repeated approximately-orthogonal segments can be promoted to structural-corner candidates;
- the hall can become the registration spine to which adjoining rooms are attached.

Absolute lengths remain scale-free until camera calibration or one trusted physical dimension is supplied.
