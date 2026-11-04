# Power SLAM PTZ v0.17 — native apparent-zoom and pan-shift measurement

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6. Date: 2026-11-02.
Rasen Falcon lane: `power-slam-harbour`; `tombstone-vision` retains ferry motion evidence.

## Source and provenance

User-provided recording: `WebcamSydney 2 Live Panning View of Harbour 247.mp4`, taken from https://www.youtube.com/watch?v=jshwkG1ZpP8.

- Source MP4 SHA-256: `aa0d87c96d9a35c601632d81fa1592206f9a12bb6c3bd7af78cfe4873158bc45`.
- Source 1920x1080 H.264 30 fps; extraction is FFmpeg decode to 640x360 8-bit grey, 1fps, 240 frames.
- Decoded raw SHA-256: `9eb28e1e86f959068302f6016269919e19d3441af3d70f016c83789500b5d77d`, size 55,296,000 bytes.
- The source video, all decoded frame bytes and stills are deliberately **excluded from Git**. Redistribution rights were not established.

## Method

`SlamHarbourPtzScale.cls` uses native ooRexx to calculate a column-wise horizontal grayscale gradient, averaged over image rows 35..254, and smoothed at five- and 61-column widths to remove broad illumination structure. It estimates a **1D skyline profile transformation**:

`target_column = scale * source_column + translation_px`

The fitter samples 105 columns in the reference frame and searches bounded scale and horizontal translation by normalized cross-correlation. Panning shifts image columns; a zoom changes the distance between stationary high-contrast structures. The algorithm is not a 2D camera solution; it is a coarse apparent-scale estimate and could still suffer from different scene depths, moving objects, auto-framing, focal distortion, or skyline mismatch. The band can include water and transient moving vessels; it is **not** a perfect stationary-object segmentation.

There is no OpenCV detector and no external classification code. FFmpeg only decodes and scales pixel data. Do not confuse **relative apparent magnification** with proof of optical zoom or a calibrated focal length.

## Measurements from real recording

| Comparison, seconds | Apparent scale | Horizontal shift at 640px width | Normalized correlation |
|---|---:|---:|---:|
| 45 -> 55 | 1.925 | -92 px | 0.643838732 |
| 217 -> 227 | 1.925 | -92 px | 0.645782570 |
| 45 -> 217 (repeat phase) | 1.000 | 0 px | 0.994676973 |
| 55 -> 227 (repeat phase) | 1.000 | 0 px | 0.995676721 |

The 45 -> 55 and 217 -> 227 results are distinct measurements 172s apart. Both phase-aligned images have a scale of 1.0 and near-identical profiles. This supports the **candidate** 172s programmed cycle from v0.16. No second full 172s cycle is visible, so the long-term schedule remains unqualified.

Exploratory native zoom ramp relative to 45s (bounded search; note temporary frame-to-frame translation):

| t(s) | Scale | Translation (px) | Correlation |
|---:|---:|---:|---:|
| 48 | 1.000 | 0 | 0.99835 |
| 49 | 1.000 | 0 | 0.99835 |
| 50 | 1.200 | -32 | 0.89117 |
| 51 | 2.000 | -192 | 0.62853 |
| 52 | 1.950 | -116 | 0.63410 |
| 55 | 1.925 | -92 | 0.64384 |

These are not motor-angle or focal-length measurements; shift may include simultaneous pan/auto-centring. The ramp covers only selected times, not a complete 1fps PTZ pose trajectory.

## Qualification

- `test_ptz_zoom.rex`: 13/13 checks PASS on native ooRexx 5.3.0 r13196. This includes exact synthetic zoom+pan recovery, **pure pan must recover 1x**, malformed feature rejection and repeated-phase mismatch rejection.
- v0.16 regression: 9/9 cycle tests and 12/12 geographic-anchor tests PASS. **Combined 34/34 tests PASS.**
- The v0.17 source raw video was re-decoded with an identical SHA-256 and all main measurements rerun successfully using native ooRexx.
- Admission: `REPEATED_APPARENT_ZOOM_CANDIDATE_NOT_LENS_CALIBRATED`. No surveyed camera centre, per-frame pan/tilt, physical focal length, optical-vs-digital zoom decision, reliable ferry world positions, or automatic target tracking qualified.

## Reproduction from repo

With ooRexx and FFmpeg installed:

```sh
sh packages/oorexx_slam_v0.1/bin/run_ptz_zoom.sh '/path/WebcamSydney 2 Live Panning View of Harbour 247.mp4' /tmp/powerslam-ptz
```

The runner decodes the video only as a source adapter, runs native tests, and measures the two zoom events and two identical-phase controls. The `ptz_640x360_1fps.gray` output is local evidence, not part of the public package. Actual source SHA should match the recorded hash above for exact reproduction.

## Next

Track individual pylon, Opera House and Mosman structures across full pan/tilt/zoom phases with native feature correspondence; solve per-frame intrinsic and extrinsic changes against independently georegistered 3D landmark points. Disentangle optical zoom from digital crop and estimate the stationary mounting point. Do not admit real ferry geolocation until the camera model passes independent holdouts.