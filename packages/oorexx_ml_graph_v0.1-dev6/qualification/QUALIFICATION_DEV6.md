# ooRexx ML Graph v0.1-dev6 qualification

## Runtime and baselines

- ooRexx 5.3.0 r13196, Internal Test Version, 64-bit.
- Exact ooRexx ML v0.1-dev11 semantic authority.
- Exact ooRexx Vision v0.1-dev14-v5v-codec-highres for decoded `VisionSurface` integration.
- Pillow 12.3.0 is present in the Python environment; the optional Foreign Runtime/Pillow provider is shipped and syntax-qualified, but the exact Foreign Runtime v0.22.6 archive was not available in this qualification workspace, so no dev6 Pillow runtime PASS is claimed.

## Image/raster primitive contract

The new image object model is a sibling of graph axes/series, not a misuse of them. `MLImageScene` owns an immutable source reference plus ordered semantic overlay layers.

Primitive family:

- line
- polyline
- polygon
- rectangle / rounded rectangle
- ellipse
- circle
- marker (circle, square, cross)
- text

Styles independently control stroke/fill RGBA, stroke width, overall style opacity, line cap/join, dash declaration, and fill rule. Layers have independent opacity and visibility. Coordinates may be source pixels or normalized image coordinates.

Rendering scale is presentation-only. It does not change source dimensions, primitive coordinates, or retained evidence.

## Vision/V5V authority checks

The integration boundary is the decoded `VisionSurface`, which is what V5V produces/consumes at the Vision semantic layer. Graph does not parse V5V wire records and does not modify Vision surfaces.

The qualification fixture uses an actual dev14 `VisionSurface` with deliberately arbitrary odd dimensions 37x23, a `VisionColourModel`, source reference, timestamp, and generation. It verifies:

- width/height are taken from the source rather than assumed from historic 47x84 / 55x73 experiments;
- palette-index values are reconstructed through the source colour model;
- line and polygon transparency are emitted independently;
- normalized coordinates map against the actual source extent;
- source reference and generation remain unchanged after rendering;
- the overlay remains explanatory material, not a replacement Vision observation.

## Executed dev6 regression

Pure ooRexx/reference-renderer run with ML dev11 and Vision dev14: 15 test programs / 138 assertions PASS.

New dev6 image assertions:

- image semantic model: 10
- deterministic SVG compositor: 6
- actual VisionSurface/V5V-bound overlay: 8

Existing graph, projection, temporal, difference, and wobble regression remains green in the same run.

Exact upstream ooRexx ML v0.1-dev11 suite: 63/63 test files PASS.

The supplied Vision dev14 package has unrelated pre-existing failures in some broader geometry/AOI tests under this ooRexx runtime; dev6 does not claim a green full Vision suite. The VisionSurface overlay integration test and relevant high-resolution request path are independently exercised.

## Rendering providers

### SVG reference renderer

Fully executed. It reconstructs the source raster, clips overlays to image bounds by default, preserves source coordinate authority, supports arbitrary render scale, and emits independent stroke/fill alpha multiplied by style and layer opacity.

### Foreign Runtime / Pillow renderer

Shipped as `MLGraphPillow.cls`. It follows the existing ForeignPython provider pattern and stores no Python handle in semantic state. It supports the same base primitive family. Dashed image strokes deliberately fail rather than being silently approximated by Pillow. The source and test compile, but runtime qualification is deferred until the exact Foreign Runtime v0.22.6 artifact is available.

## Visual qualification

`examples/v5v_image_overlay.rex` creates a synthetic 160x90 indexed VisionSurface and overlays a translucent polygon, polyline/lines, normalized rectangle, ellipse/circle, cross marker, and text. The SVG was parsed/rendered successfully for visual inspection; the blocky Vision raster remains visible beneath semi-transparent diagnostic geometry.
