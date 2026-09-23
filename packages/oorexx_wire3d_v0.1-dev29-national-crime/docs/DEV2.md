# Wire3D v0.1-dev2

## Live semantic projection boundary

`Wire3DComponentProjection` is the first passive live-object adapter. It accepts an existing object and refreshes only when that object explicitly publishes `asDirectory`. It uses `hasMethod()` first and never probes through `UNKNOWN`. The returned Directory is retained as projection evidence/metadata; Wire3D does not acquire authority over the source.

`Wire3DInteractionSession` is the renderer-neutral semantic interaction object. Desktop click and mobile tap are renderer gestures; both resolve to the same `select(spatialId)` operation. `enter()` is meaningful only for spatial containers. This keeps interaction OO and prevents browser event vocabulary from leaking into the authoritative model.

The browser renderer now performs semantic picking and emits `wire3d-select` with the selected spatial id and semantic reference. The mobile detail card displays the selected object's semantic identity and metadata. It still performs no source mutation.

## Invariants retained

* Visual state is projection, never authority.
* Component projection is passive and side-effect free by contract.
* AI projections remain institutional actors (`NO_MASCOT`).
* Touch and desktop are peers over one interaction model.
* No renderer-specific state is required by source components.
