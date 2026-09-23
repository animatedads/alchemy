# Hall-first structural reconstruction

## Why this exists

Body-worn footage is not cooperative photogrammetry.  The camera usually sees floor near the bottom of the frame, while walls, doorways and corners appear and disappear as the wearer walks.  In conventional interiors this low-level geometry is often more reliable and cheaper than generic object recognition.

The dev4 rule is therefore: **follow the support surface before asking for a dense mesh.**

## Structural sequence

1. `VisionSupportFrontierExtractor` finds the bottom-connected support surface using the Vision value model.  It does not assume RGB or a specific carpet colour.
2. `VisionSupportFrontier` records the upper frontier of that support surface.
3. `VisionFloorHomography` registers floor-plane observations between frames or cameras.  The exact four-pair solver is deterministic; robust pair selection remains a provider seam.
4. Gaps / deep penetrations in the frontier can become `VisionStructuralOpeningCandidate` objects.
5. Registered floor-wall boundary segments can be tested by `VisionManhattanCornerDetector`.  Approximately 90-degree structure is a prior, not a fact.
6. `VisionBuildingSkeleton` retains registrations, boundary segments, openings and corners before renderer mesh generation.
7. `Vision3DGeometryRefinementRequest` asks for *geometry evidence* (for example more floor-wall samples or doorway jambs), preferably from another already-recorded camera view, before escalating to source-resolution pixels.

## Evidence authority

- A floor frontier is an observation derived from compact Vision evidence.
- A homography is a floor-plane registration with explicit candidate/inlier evidence.
- An opening is initially `CANDIDATE`.
- A Manhattan corner is initially `CANDIDATE`.
- No candidate is promoted to observed geometry merely because a 90-degree prior makes it plausible.
- Dense Wire3D surfaces remain projections of reconstruction state, not the authority for the building geometry.

## Multi-officer use

Multiple bodycams are independent camera tracks against one possible static-world skeleton.  The first refinement choice for weak geometry should be another source with better aspect, then denser V5V sampling, then high-resolution source material only if still required.
