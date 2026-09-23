# dev16 desktop qualification

Qualified with the user-supplied ooRexx 5.3.0 r13196 Internal Test Version.

Repairs found by the real runtime gate:

1. Rexx directives in `test_maths3d_integration.rex` are after executable code.
2. `Wire3DMathsAdapter.cls` directly requires `MathsBootstrap.cls` and
   `Wire3DCore.cls`; ooRexx package visibility is not inherited from a sibling
   package through `Wire3DAll.cls`.
3. Maths PURE/REFERENCE providers are bootstrapped before matrix composition.
4. `projectionFor` establishes Maths working precision before evaluating the
   viewport aspect ratio, preventing the same caller-boundary precision leak
   fixed by Maths v0.8.
5. The portrait-phone qualification showed x=+/-3 just outside the horizontal
   clip volume at eye z=10. The deterministic demo camera is moved to z=12;
   automatic scene framing remains the intended general solution.
6. The demo output path is supplied explicitly by the launcher so scene
   generation updates the exact `web/scene.json` Chrome serves.

Desktop gate: `test_core`, `test_maths3d_integration`, renderer maths and JS
syntax pass. The demo scene is generated and parsed from the exact web path.
