# Vision 3D -> Wire3D integration (dev2)

`Vision3DWireProjection` is a projection adapter, not a second reconstruction model.

* Vision 3D owns occupancy/evidence state, confidence, support-only geometry and enhancement decisions.
* Wire3D receives renderer-neutral spatial nodes and revision-fenced scene deltas.
* Maths v0.8 remains the numerical authority for model/view transforms.
* `UNSEEN` and `OCCLUDED_UNKNOWN` are not manufactured as solid scene objects.
* `OBSERVED_FREE`/`INFERRED_FREE` are hidden by default; they remain reconstruction evidence rather than visible solids.
* `SUPPORT_ONLY` can be rendered during reconstruction diagnostics or suppressed for the requested object-only view.
* A cell moving from inferred to observed evidence keeps the same Wire3D spatial id and is published as `UPDATE_NODE`.

The real qualification fixture `project_bodycam_pair_wire3d.rex` reconstructs the accepted 9s->10s bodycam pair and writes a current `WIRE-3D/0.1` scene containing the sparse cells plus the two camera positions and their trajectory edge.
