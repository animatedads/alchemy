# Sydney Harbour six-screenshot temporal mask evidence

Native ooRexx 5.3.0 r13196, executed 9 November 2026.

## Sources

Five screenshots taken 9 November 2026 at 20:17:25, 20:24:30, 20:32:05, 20:32:17, and 20:37:11 Sydney time (1920 x 1080); one further screenshot at 22:08:42 Sydney time (1316 x 742). These are independent webcam wall-clock observations, **not** a continuous video timeline.

## Method

1. Decode PNG under the shared ooRexx `MediaPngFile` using native in-process PNG provider.
2. Resize the previous five screenshots to 1316 x 742 using shared AREA resampler; use 20:37:11 as a stable landmark reference.
3. Find integer translation from landmark facades (ROI x=320 y=315 w=320 h=95) within +/-6 pixels. Shift image by registered offset; preserve validity mask.
4. Reduce to 329 x 185 pixel processing plane, add all six observations to `MediaTemporalDifferenceMask` using independently supplied Sydney UTC+11 webcam timestamps.
5. Rebuild temporal reference model with 50% local intensity threshold, score every frame retrospectively. Count positive mask pixels in the restricted sky region x=31..319, y=10..66, and facade ROI x=80..249, y=82..114.

## Native results

| Time Sydney | Registered dx,dy | Landmark score PPM | Sky-positive processing pixels | Facade-positive processing pixels |
|---|---|---:|---:|---:|
| 20:17:25 | (0,0) | 79,527 | 1,222 | 1 |
| 20:24:30 | (0,0) | 55,669 | 0 | 4 |
| 20:32:05 | (0,0) | 32,151 | 0 | 0 |
| 20:32:17 | (0,0) | 31,721 | 1 | 0 |
| 20:37:11 | (0,0) | 0 | 6 | 0 |
| 22:08:42 | (-3,-3) | **152,842** | **97** | **8** |

The new screenshot exceeds the test's provisional **100,000 PPM landmark-residual gate**, so this is a *broad scene-difference comparison*, not a qualified pixel-accurate sky registration. Atmospheric transparency, moving clouds, screenshot scaling, and specks over the bridge can contribute to bright differences. **None of the 97 changed processing pixels is claimed as a confirmed star**; a star detector must revisit original-resolution pixels, evaluate point spread and persistence, and validate the Yale catalogue fit after geometric calibration.

## Evidence and constraints

`test_sydney_six_png_temporal.rex` uses only ooRexx classes and existing in-process media providers. It does not use Python, libavformat, a FFmpeg executable, or an external image-analysis program. The generated PGM masks and TSV metrics are from this run. Pixel images and their masks remain outside the public Git repository; only source and textual test evidence are committed.

This test does not independently validate a full-scale affine/homography warp, focal length, lens distortion, insects vs stars, or a real astrometric fix.