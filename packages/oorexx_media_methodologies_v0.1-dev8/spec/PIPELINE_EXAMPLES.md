# Plural-method Pipeline Examples

## 1. Blurred person entering a shot

Goal: recover as much supported appearance/motion structure as possible when every frame is blurred.

Do not choose a single enhancer. A candidate plan is:

1. `VIDEO.DECODE.PRESERVE_PTS`
2. `VIDEO.CAMERA_STATE.GATE`
3. one or more motion estimates: `VIDEO.MOTION.DENSE_FLOW`, `VIDEO.MOTION.PHASE_CORRELATION`, `VIDEO.TRACK.TRAJECTORY`
4. parallel reconstruction branches:
   - `VIDEO.RECON.LEADING_EDGE_BACKPROJECTION`
   - `VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL`
   - `VIDEO.RECON.LATENT_MULTI_FRAME`
   - `VIDEO.RECON.FLOW_WARP_ACCUMULATE`
   - `VIDEO.RECON.MOVING_STRIP_MOSAIC`
   - `VIDEO.SUPERRES.MULTIFRAME`
5. `QUAL.FORWARD_MODEL.REPROJECTION`
6. `QUAL.PARAMETER.SENSITIVITY`
7. `QUAL.TIME_REVERSE`
8. `QUAL.CROSS_METHOD.DISAGREEMENT`

The output is a family of candidates and support maps. A learned inpainting/SR branch can be added for visualization, but its synthetic pixels stay separately marked.

## 2. Tiny physical movement in a fixed scene

Goal: determine whether a door/wall/object exhibits coherent subpixel movement.

Possible branches:

- `VIDEO.MOTION.PHASE_SUBPIXEL`
- sparse probe tracking;
- dense flow on the ROI;
- structure/control-region tracking;
- `VIDEO.MOTION.EULERIAN_MAGNIFY` for visualization only.

Camera-state gating and stable control regions are mandatory. Audio correlation is downstream and cannot tune the sealed visual detector.

## 3. Poor speech recording

Goal: understand what is measurable and possibly produce a clearer listening copy.

Parallel/ordered possibilities:

- decode/sample-timeline audit;
- clipping and noise-floor measurement;
- band-pass/notch;
- Wiener/MMSE/spectral subtraction;
- WPE dereverberation;
- multichannel beamforming if geometry exists;
- classical/learned source separation if needed;
- ASR only as a transcript hypothesis;
- forced alignment against candidate text;
- compare transcript against the original waveform, not only the enhanced output.

## 4. Audio event plus visible mechanical response

Goal: test physical coupling rather than simply notice coincidence.

1. seal independent audio and visual measurements;
2. align clocks with `AV.SYNC.CLOCK`;
3. compute event/motion lag using `AV.SYNC.TRANSIENT_MOTION`;
4. estimate coupling with `AV.COUPLING.ACOUSTIC_MECHANICAL`;
5. run `QUAL.TIME_SHUFFLE`, matched controls and clock perturbation;
6. preserve alternative shared-cause hypotheses.

## 5. Reconstruct a room/world from video/stills

Possible branches:

- Vision boundary/line continuity;
- `VIDEO.GEOM.VANISHING_POINTS`;
- feature matching/homography;
- structure from motion;
- pose estimation and bundle adjustment;
- plane fitting;
- temporal registration;
- camera-path/view feasibility;
- Photo World calibrated hypotheses;
- multi-view texture fusion;
- Wire3D presentation.

Each layer retains its own authority; rendering does not become measurement.
