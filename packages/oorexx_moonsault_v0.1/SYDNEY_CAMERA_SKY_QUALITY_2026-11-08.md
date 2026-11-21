# Moonsault — camera-dependent sky evidence (8 November 2026)

The three Sydney webcam captures, although named .mkv, are MPEG-TS/H.264 and decode through Media Object Access dev4 under native ooRexx 5.3.0 r13196. All three are 30 fps, ~60 seconds. Native RGB24 frame access qualified at 5s, 30s and 55s on each input.

## Astronomical sampling policy

- Stream 1: 1280x720, STAR_CANDIDATE_AND_CLOUDS.
- Stream 2: 1280x720, STAR_CANDIDATE_AND_CLOUDS.
- Stream 3: 640x360, SCENE_AND_CLOUDS for these three Sydney files; native sky sample is too coarse for credible faint-star work, but cloud and landmarks are useful.
- Default conservative camera sampling threshold is 960x540, configurable through `assessFrame(frame, cameraId, minimumWidth, minimumHeight)`. This is not a universal physical law: optical quality, compression, focus, noise, exposure, field-of-view, skyglow, sampling and measured point-spread functions ultimately determine star resolution.
- An eligible frame does NOT prove any stars. The class records zero actual detections/matches and forbids celestial correction until a separate measured and independently validated pipeline provides at least three persistent tracks, three catalogue matches, RMS <= 1.5px, verified time and camera calibration.
- No resampling or sharpening can manufacture star evidence lost by native image sampling; different camera views are not assumed to share stars or local cloud occlusion.
- The third camera may support cloud motion/landmarks/scene registration, not heading from stars in these captures.

## Native executed tests (r13196)

`rexx tests/test_sydney_camera_roles.rex` — PASS, 21 synthetic role and evidential authorization assertions.

`rexx tests/test_camera_roles_on_video.rex stream1.mkv stream2.mkv stream3.mkv OUTPUT_DIR` — PASS on the three actual uploaded recordings, nine native H.264 RGB24 timestamped frame requests, 12 IDR anchors per camera, 1 MiB maximum compressed read budget. Per frame verified expected role and rejected any unsupported celestial heading assertion. Raw output image is a direct ooRexx PPM rendering, no Python pipeline.

Native decoding does NOT yet amount to a performed Moonsault star detection, catalogue identification or astrometric fit. This change prevents using a low-sampling camera as a source of false celestial heading while preserving the two 720p streams for a later real detection pipeline.

The executable H.264 provider remains in the Media Object Access branch (draft PR #138) and is a development dependency. The Moonsault camera policy lives in the Moonsault branch, rather than altering the SLAM450 component.