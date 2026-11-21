# Moonsault — Sydney 10 Nov 2026 native video/star evidence

**Provenance:** Two original user-provided MP4 files and an annotated PNG. This release excludes all video/image bytes and contains only code, per-frame numerical measurements, and verification evidence.

## Native media access

- `WebcamSydney 1 Live Stream of Harbour 247 4K(1).mp4`: real ISO BMFF/MP4, H.264 `avc1`, 1920×1080, 30 fps, 70 s, 2100 video samples, 14 sync points, track time scale 90,000 ticks/s.
- `WebcamSydney 1 Live Stream of Harbour 247 4K(2).mp4`: real ISO BMFF/MP4, H.264 `avc1`, 1920×1080, 30 fps, 65 s, 1950 video samples, 13 sync points, time scale 90,000 ticks/s.
- ooRexx 5.3.0 r13196 parsed movie/track atoms, sample sizes, stsc/chunk offsets, stts and optional ctts, keyframe indexes and avcC SPS/PPS; emitted Annex-B compressed NAL units to the existing in-process codec-only `moa_h264`. No shell FFmpeg, Python, OpenCV or libavformat media demux was used. `magick` was used ONLY to prepare the private six-frame viewing contact sheet, never to perform detection, decode, registration or measurement.
- Decoded requested frames at 5, 30 and 60 seconds of each clip with exact requested 90 kHz video PTS: 6/6 PASS. Per-frame indexed source reads ranged from 515,013 to 523,338 compressed bytes. Large `mdat` skipped on initial metadata scan. Full per-sample indexes still built locally; production persistent index reuse is a separate qualification gate.
- Interim `media/tests/support/MediaMp4AvcAccess.cls` performed real source qualification for these two files. `MediaMp4H264Frames.cls` is the intended production-facing codec adapter to existing `MediaMp4Track~mapSamples`; it passed ooRexx source translation but **was not run against the connected dev2 full MP4 sample-map classes** in this runtime. This keeps the existing production sample-table logic authoritative and avoids a second permanent production parser.

## Webcam time vs container time

| Clip | Frame PTS in MP4 | Observed webcam overlay (Sydney AEDT, UTC+11) |
|---|---:|---|
| 1 | 5 s | 2026-11-10 21:04:30 |
| 1 | 30 s | 2026-11-10 21:04:55 |
| 1 | 60 s | 2026-11-10 21:05:25 |
| 2 | 5 s | 2026-11-10 21:09:05 |
| 2 | 30 s | 2026-11-10 21:09:30 |
| 2 | 60 s | 2026-11-10 21:10:00 |

The separately uploaded marked screenshot reads 21:10:16 Sydney time. The camera does not appear to move between these clips: the existing skyline registration returned 0,0 whole-pixel shift for all six sampled frames. Source times are independently observed from the webcam clock, not inferred from MP4 file creation time.

## Nine all-six-frame point-source tracks

Screen coordinates at native 1920×1080, (0,0) top-left. Time baseline between the first and last sampled exposure: **330 s**. Positions and velocities from native ooRexx regressions; 'RMS' measures image tracking residual, not astronomical pointing accuracy.

| 21:04:30 position | 21:10:00 position | Δx | Δy | Track RMS (px) |
|---|---|---:|---:|---:|
| (745,33) | (736,42) | −9 | +9 | 0.753 |
| (909,45) | (900,59) | −9 | +14 | 0.656 |
| (1502,108) | (1487,134) | −15 | +26 | 0.658 |
| (1604,170) | (1587,198) | −17 | +28 | 0.702 |
| (415,206) | (401,209) | −14 | +3 | 0.752 |
| (1696,224) | (1677,253) | −19 | +29 | 0.610 |
| (809,257) | (796,267) | −13 | +10 | 0.422 |
| (77,325) | (57,321) | −20 | −4 | 0.651 |
| (427,368) | (410,370) | −17 | +2 | 0.395 |

The **four independent held-out frames** at +15 and +45 seconds in each clip were decoded separately, without participating in fit. Of 36 possible star point detections, 33 matched the positions predicted by the original nine-track model within 3.5px, **0.742px RMS across 33 matched predictions**. The three absences were only at clip1 +15s, consistent with threshold/sensitivity losses, and are not treated as failed geometric matches.

## User's blue arrows as proposals

The annotated PNG is 1317×737 and contains 16 rough arrow tips. Blue annotation edges can themselves generate local maxima, so the marked PNG was **not** used for point evidence. Geometry-only arrow ROI centers were mapped to source 1920×1080 coordinates. Of the 16 arrow positions, nine associated with an independently measured full six-frame track, three more contained a compact point in the last sampled source frame but did not pass six-frame persistence, and four did not contain such a last-frame match. These are **not** 16 confirmed astronomical stars.

Coordinates with full-six-frame confirmation: arrows C, E, F, G, I, K, N, O and P. Last-frame-only: B, D and M. No last-frame point within the 28-pixel ROI: A, H, J, L. Some latter points appeared in other frames, so 'no last-frame point' is not a negative proof that a star was absent.

## Limits and next acceptance gate

This establishes **moving point-source evidence strongly consistent with stellar rotation** relative to a landmark-registered camera. It does not identify Yale catalogue star names, nor qualify a celestial heading. Accurate camera bearing/focal length/radial distortion, J2000-to-date reduction and a full competing-hypothesis/independent-heldout catalogue match are still necessary. A 0.74px track residual cannot be substituted for plate-solve residual. The screenshot at +16s is annotation-contaminated, so unmarked MP4 measurements must remain source authority.

The earlier southwest catalogue assumption was too narrow for this south-facing WebcamSydney view. Source-level time/geometry evidence should be the constraint, not a preferred constellation.

## Reproduction

Use the provided ooRexx r13196 Linux interpreter, preinstalled shared Media Object Access classes, `libmoa_h264.so` and separate PNG/raster providers. `media/tests/test_two_sydney_mp4.rex` exercises six native video seeks. `moonsault/tests/test_new_sydney_star_pixels.rex` generates the measured source candidate TSV. `test_new_sydney_six_tracks.rex`, `test_new_sydney_holdout.rex` and `test_arrow_roi_crosscheck.rex` verify the 9-point tracks and independent timestamped held-outs. Input file paths are referenced rather than bundled.