# dev13 Android renderer correction

The first real Android/Chrome rendering probe proved that HTML, ES module loading,
scene.json retrieval, WebGL context creation and scene decoding all worked, but no
scene geometry appeared.

The fault was Wire3DRenderer._mul(): it multiplied matrices using row-major indexing
and then supplied the result directly to WebGL, which consumes column-major matrices
with transpose=false. Geometry was therefore transformed outside the intended clip
space.

dev13 changes _mul() to column-major `out = a * b`. No semantic scene or authority
contract changes are involved. This is a renderer-only correction.

Acceptance evidence to obtain on Android:
- header reports scene title/revision/object count;
- three objects are visible;
- drag rotates and tap selects;
- scene.json remains authoritative input.
