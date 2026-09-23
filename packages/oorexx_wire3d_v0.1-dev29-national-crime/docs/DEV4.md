# Wire3D v0.1-dev4 — frontier, raster and evidence semantics

Dev4 makes raster/coverage terrain a first-class projection without making Wire3D a GIS engine.

## Core rule

**Resolution is not certainty.** A dataset may provide one sample per metre while large parts of the represented world remain inferred, reconstructed, disputed, stale, or unknown.

`Wire3DGeoSurfaceProjection` represents one authoritative raster/coverage/DEM dataset. It preserves the source dataset reference, SRID, extent, sample resolution and evidence state. Renderer-created cells, triangles, normals and LOD meshes remain presentation artifacts and never become authoritative spatial objects.

`Wire3DEvidenceState` provides a deliberately small epistemic vocabulary: `SURVEYED`, `OBSERVED`, `RECONSTRUCTED`, `INFERRED`, `UNKNOWN`. It can carry confidence, source reference, observation time and method. It does not attempt to replace provenance, Observation or Journal PointedState; those remain authoritative sources and can be referenced by `sourceRef`.

The same geographic place may therefore have several simultaneous surface projections backed by different evidence/provenance. Wire3D does not choose a winner. A viewer can compare them or move a temporal/evidence cursor later.

## Renderer contract

LOD is renderer-owned. A phone may display a coarse mesh while an auditorium renderer displays a denser one; both are projections of the same semantic surface. Sampling density, display density and confidence are separate quantities.
