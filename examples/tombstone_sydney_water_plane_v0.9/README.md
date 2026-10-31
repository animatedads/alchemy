# Tombstone Sydney water-plane calibration v0.9

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 31 October 2026. Native ooRexx 5.3.0 r13196. Additive component; no SLAM-core changes.

## Source

- qualify_water_plane.rex: four image/world water-plane correspondences, at least three independent withheld points, metre CRS, source metadata, uncertainty, coverage and singularity checks. Rejects inadequate geometry before generating an output.
- water_pixel_metric.rex: converts a qualified 3×3 homography to world coordinates and a local 2×2 directional Jacobian at water-contact pixels. Its area-derived geometric mean metres/pixel is not a 3D-vessel resize.
- Four synthetic PSV fixtures: metadata, controls, heldouts, sample pixels. The synthetic data is not a Sydney survey.

Run with ooRexx in this directory:

    rexx qualify_water_plane.rex metadata_synthetic.psv controls_synthetic.psv holdouts_synthetic.psv output_synthetic.psv
    rexx water_pixel_metric.rex output_synthetic.psv points_synthetic.psv metrics_synthetic.psv
    python qualification_v09.py

The native arithmetic returned max held-out residual approximately 1.52e-13 in synthetic metres; four directional derivatives were verified against independent finite differences. Local qualification: 21/21 checks PASS (two expected successful calculations, nineteen deliberate bad-input rejections). See qualification_v09.json and full local ZIP for the test suite.

Status is SYNTHETIC_MATH_ONLY. An externally sourced control set can at most yield SURVEYED_CANDIDATE_REQUIRES_INDEPENDENT_AUDIT. This program cannot independently establish the source authenticity of alleged survey coordinates.

## Limits

Camera coordinates found on third-party webcam directories are approximate, not usable surveyed points. No verified four water-plane ground controls, geographic warp, vessel metre distances or real-world speed exist yet. Use independently auditable projected-MGA coordinates and image pixel tie-points; do not treat building roofs or bridge truss points as lying on the water surface.

The earlier ferry scoring baseline (TP15/FN1/FP0/TN14, one negative abstention, 17 review) remains unchanged. No visual scores have been promoted to SLAM TESTED. Autobuilder and production services were not touched.
