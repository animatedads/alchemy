# Tombstone Sydney: unseeded ferry track v0.11

Architecture: user. Coding: ChatGPT GPT-6. Native state fusion: ooRexx 5.3.0 r13196. OpenCV only extracts pixel evidence from user-provided video.

## Reproduced results — real 31.2 s recording 1000066232.mp4

Original mobile 2340x1080, fixed 1920x1080 webcam crop; source SHA256 `2ee6fa992d302824bcd126bfc4617e1a2126b6ce6fd24e219513fc76c71bf192`.

1. Without any manually supplied object coordinates, select largest moving yellow connected component on the first sample. Use velocity/position gating over subsequent samples. Of **158 video samples, 158 candidate detections** successfully follow the original Manly ferry.
2. Comparison with **prior manually seeded** v0.6 visual track (used ONLY as evaluation): median 6.11 native pixels, 95th percentile 12.54, maximum 13.99, **158/158 within 20 px**. The prior hand-seeded track isn't independent proof of vessel identity. The first unseeded largest-component-only method made 23 errors >40 px; continuity gating fixes these **on this same observed clip**, not yet unseen video.
3. Actual automatic candidate crops passed to unchanged v0.8 native ooRexx colour scorer: **80 direct `ferry`, 51 `abstain`, 27 `not_ferry`**. The existing scorer prints `VIDEO_MANUALLY_SEEDED_POSITIVE_CROPS` (legacy label) but these are NOT manually seeded crops.
4. New native `temporal_fusion.rex` checks per-frame chronology, expected morphology geometry, physical image bounds, prediction linkage, support, position steps and duplicate rows, then retains a distinct `CONTINUITY_SUPPORTED` track state through 146 frames after an initial 12/12 ferry-positive acquisition. It **never changes** direct visual negatives/abstentions to fresh positives. Neither continuation nor colour-support is a SLAM graph-tested score, statistical probability or verified vessel identity.
5. Native qualification **12/12 PASS**: valid plus idempotent repeat, 11 corrupt/forged cases rejected (duplicate/missing rows, impossible jump, out-of-bounds, wrong fold, forged support, etc.). The 16-file complete ZIP is in this conversation; the uploaded raw MP4 is excluded from Git.

## Files and reproduction

`detect_blind.py`: OpenCV video foreground/colour connected components, no manual vessel seed.
`score_blind.py`: crop pixels and encode evidence features only.
`temporal_fusion.rex`: native track-state continuity, no source truth labels.
`compare_blind.py`: post-hoc independent coordinate comparison against the earlier seed track.

Use `python detect_blind.py --mp4 /mnt/data/1000066232.mp4 --output /mnt/data/tombstone_v011`, then `python score_blind.py` in that workspace (adjust fixed `P`/video path when not running there). Run the v0.8 `score_vision.rex` with `features.psv` and the new `blind_video_features.psv`; copy its `predictions_v08.psv` to `blind_predictions.psv`. Run `rexx temporal_fusion.rex unseeded_candidates.psv blind_predictions.psv temporal_evidence.psv`. See complete package for fixture files, digest, reproduction commands and native QA report.

**Open gates:** full geographic homography (200 m baseline alone insufficient); multi-object tracking; unseen video and alternate lighting; red/white fast ferry; direct SlamStore/graph evidence-contract review. No geographical speed or raw-vs-warped classification claim.
