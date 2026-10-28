# Experimental Reconstruction Research Backlog

This file deliberately records methods that deserve implementation/qualification rather than deleting them because they are incomplete.

## Motion-blur reconstruction family

1. **Leading-edge backprojection** — initial specification present.
2. **Bidirectional blur envelope** — use both leading/trailing support constraints.
3. **Non-rigid edge backprojection** — piecewise trajectory for limbs/clothing.
4. **Rolling-shutter-aware edge reconstruction** — edge support indexed by row exposure time.
5. **Joint blur/trajectory solve** — alternate between latent object and per-frame blur kernel.
6. **Blur tomography** — exploit changing blur direction/length across frames.
7. **Edge-derived super-resolution** — subpixel edge crossings constrain higher-resolution shape before texture.

## Occlusion reconstruction family

- temporal reveal mosaics with explicit visibility ordering;
- moving-object strip mosaics;
- multi-view surface-texture fusion;
- uncertainty-aware hole retention rather than automatic inpainting.

## Micro-motion / audio family

- visual microphone reconstruction from suitable surfaces;
- rolling-shutter vibration recovery above nominal frame rate;
- audio-to-visual transfer-function estimation;
- state-dependent door/window/structure acoustic response models.

## Model-assisted family

Learned restoration is allowed but should be evaluated against classical methods and synthetic ground truth. Priority experiments include identifying when models preserve *measured* boundaries/timing while hallucinating texture or phonetic detail.
