# Apron SLAM – transient vehicle image motion v0.1-dev2

Source-only integration surface for read-once moving-vehicle proof of concept. **No recording, plate region, plate glyph, OCR result, frame or identifying content is included.** The class consumes anonymous camera/track centroid observations at integer source PTS (microseconds); the caller must supply these from the existing Vision/Motion/Media Object Access providers. It does not open media files and has no disk or network I/O.

`ApronTransientTrack` validates monotonic PTS, one track/source, fixed geometry, bounded observation count and maximum timestamp gap; it computes robust median pairwise image-centroid velocity, then `ApronImageMotion~displacement(exposureUs)` returns shutter-time image displacement. The resulting vector is **not** the plate's exact projected motion and must not be converted to km/h without camera geometry and a 3D pose. Unknown shutter time is not inferred from FPS. `~close` drops the in-memory track samples.

Real glyph motion requires plate-plane projection in existing `ApronGeometry.cls` and the canonical Maths provider. This increment is synthetic-contract qualified only; it does not claim plate localisation, OCR, native MP4 H.264 decoded-frame seeking, lens calibration or source-measured shutter exposure.

Tests use synthetic data only. Execute with `LD_LIBRARY_PATH` appropriately set for ooRexx 5.3 and run `rexx tests/test_transient_motion.rex` and `rexx tests/test_motion_rejections.rex` from this package root. No footage or glyph/font asset is packaged.