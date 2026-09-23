# Wire3D dev15 — Maths v0.8 renderer boundary

This cut removes the dev13/dev15 browser-owned model/view matrix stack.

* Wire3D semantic transforms remain Wire3D objects.
* ooRexx Maths v0.8 produces every node model matrix and the camera view matrix.
* Matrices cross the wire as explicit column-major arrays under the OpenGL/column-vector convention.
* The static browser smoke route owns only the viewport-dependent perspective adapter (aspect ratio is a browser fact).
* The shader consumes `projection * view * model * point` directly; JavaScript no longer composes a hidden `_model()` matrix.
* Picking projects `[0,0,0,1]` explicitly through the same model/view/projection data used by drawing.
* The demo generator now writes the file actually fetched by the browser: `web/scene.json`. Earlier cuts could regenerate a root-level `scene.json` while the smoke server continued serving a stale `web/scene.json`.
* Drag/pinch camera mutation is intentionally disabled in this qualification cut. A semantic camera interaction contract will be added only after static projection is proved on-device.
