# Camera-path solver

The first reconstruction problem is camera motion against a mostly static world.
The solver runs at native source cadence (about 30 fps for current bodycam
material) and compares frame N to frame N+1.

Per frame:
1. Vision / Line Assessment supplies stable item and line identities.
2. `VisionFrameGeometryComparator` computes item displacement and line midpoint,
   angle, and length changes from the previous frame.
3. Motion evidence proposes camera motion / pose candidates.
4. `VisionCameraPathFeasibility` rejects candidates that violate physical
   translation, angular-rate, accessible-floor, or wall-crossing constraints.
5. Surviving possible locations are carried into the next frame.

After each source video has a feasible path family,
`VisionMotionSynchronizer` and later world-geometry registration compare fuzzy
motion/location hypotheses across independent cameras.  A common floor plan is
acceptable only if each source admits a continuous accessible camera path
through that same static layout.

Temporary stationary objects may contribute short-baseline parallax evidence,
but are not permanent architectural landmarks.  Static walls, floor boundaries,
door jambs, sockets, switches and radiators are stronger world anchors.

`Vision3DMotionGraphProjection.cls` provides an optional ooRexx ML Graph dev6
projection for displaying frame-local motion evidence without altering it.
