# Wire3D dev23 — visible projector tracking field

Repairs dev22 packaging/runtime integration: the generated tracking-field descriptor existed in the Rexx scene generator but was absent from the shipped `web/scene.json`, so the browser correctly rendered no field.

The shipped scene now contains the `wire3d-tracking/1` descriptor. The renderer reconstructs a deterministic multi-scale field from version + seed:

- seeded spatially unique star constellations,
- sparse registration stars around the projector frame,
- six long asymmetric wavy registration lines,
- three asymmetric crosshair anchors.

The field is renderer/sensing infrastructure (`applicationState=false`). It is rendered before Wire3D objects and does not participate in semantic application state or authority.

`?diag=1` now reports the tracking descriptor, seed, star count, wave count, and anchor count. The ordinary Wire3D model/view path is unchanged.
