# Dual-camera native 5-bit motion trace — dev9 qualification

Inputs supplied in the active reconstruction session:

- camera A: `1000060609.mp4`, 1080x1920, ~29.9729 fps, 1641 source frames;
- camera B: `VID_20260923_050113.mp4`, 1080x1920, ~30.0390 fps, 1615 source frames.

The cameras were held simultaneously, one in each hand and approximately level.
They are therefore correlated sources but **not** a rigid calibrated stereo pair.

For qualification only, every source frame was decoded with frame passthrough,
reduced to a 55x98 luminance surface, quantized to 5 bits, and compared to the
immediately preceding source frame.  Dense flow was summarized by a local affine
field to retain common drift, apparent expansion, small in-plane rotation and
residual/parallax spread.

This Python/OpenCV probe is not a runtime dependency and does not replace the
Vision V5V value model.  Production dev9 consumes `VisionSurface` plus
`LineAssessment` at native timestamps.

Observed fuzzy cross-source alignment from this deliberately tiny 5-bit probe:

- dx: correlation ~0.946, best lag 21 frames;
- dy: correlation ~0.798, best lag 20 frames;
- apparent scale: correlation ~0.703, best lag 20 frames;
- flow magnitude: correlation ~0.938, best lag 21 frames;
- small in-plane rotation: correlation ~0.529, best lag 20 frames.

The lag cluster is therefore around 20–21 source frames for this extraction.
An earlier feature-based probe gave a nearby ~22-frame alignment.  Dev9 treats
synchronization as fuzzy evidence rather than encoding a single magical frame
offset.

Full native-frame qualification evidence is retained in
`DUAL_CAMERA_NATIVE_5BIT_TRACE.json`.
