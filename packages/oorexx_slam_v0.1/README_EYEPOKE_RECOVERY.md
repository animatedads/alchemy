# EyePoke / Low Blow SLAM: cross-module recovery admission (dev1)

Architecture: Tom Dyer. Code: ChatGPT GPT-6, 2026-11-04.

This integration adds **source admission and strategy scoring** around existing
Alchemy components. It does **not** implement another reconstruction engine.

## Module contracts

- **Vision** `src/VisionRecoveryPrivacy.cls`: source-scoped protected
  `VisionRegion` zones in authoritative source coordinates. Individual points
  or whole requests intersecting protection cannot be admitted. Existing
  `VisionTrackTransform`, `VisionTrackObservation`, V5V exact-surface codec,
  and `VisionRegionMaterial` retain motion/evidence authority.
- **Camera Behaviour** `CameraRecoveryWindow.cls`: admits only a native-PTS,
  same-source, same-generation, same-track sequence of already-admitted
  observations. A source barrier, temporal gap, duplicate or reversed PTS
  rejects the window. It does not decode, track, or identify.
- **Media Methodologies** `src/MediaVideoRecoveryEvidence.cls`: existing
  `MediaExperimentCandidate` must be `DERIVED_RECONSTRUCTION`, keep an
  original source reference, support and uncertainty maps, and valid held-out
  consistency metrics. It retains the five existing `VIDEO.RECON.*` IDs and
  never elects a reconstruction as an original observation.
- **SLAM** `src/SlamRecoveryStrategy.cls`: selects eligible registered methods
  using measured motion, blur, texture and occlusion conditions. The bounded
  0–100 score represents comparative consistency **only**, not true detail
  recovered, identity, or forensic certainty. No score may be marked
  `TESTED` without independently published checker evidence.

## Five method identities (already present in Media Methodologies)

1. `VIDEO.RECON.LEADING_EDGE_BACKPROJECTION`
2. `VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL`
3. `VIDEO.RECON.FLOW_WARP_ACCUMULATE`
4. `VIDEO.RECON.MOVING_STRIP_MOSAIC`
5. `VIDEO.RECON.LATENT_MULTI_FRAME`

The Python/OpenCV reference provider is `EXPERIMENTAL_REFERENCE`, not a new
production ooRexx integration. Reuse ooRexx, the existing Foreign Runtime and
the existing Maths library for numerical kernels.

The initial regression tests are wholly synthetic; a local ooRexx r13196 run
with minimal dependency stubs passes 29 checks. **Full-module integration and
an independent reconstruction-quality run are not yet qualified.**

## Hard private-media gate

No original surveillance video, frames, stills, crops, private region coordinates,
video-derived images, masks, maps, metadata, measurements, source hashes, or any
other video-derived result may be committed to GitHub, including documentation,
test fixtures and issue attachments. Only generic source, specifications, and
wholly synthetic tests may be published.

Every real-media task must explicitly define source authority, time range,
privacy-protected areas, protected-support mask, track coordinates, provenance,
candidate/support/uncertainty outputs, and independent held-out verification.
Unavailable detail remains UNKNOWN; no generative fill may establish factual
visual detail. Occupant reconstruction and identity inference are outside the
initial vehicle-exterior trial.

## Provider execution correction

The initial Media Methodologies reference-video runner has been migrated from
`ADDRESS SYSTEM python3 ...` to the existing **Foreign Runtime** resident
Python bridge. The SLAM stage must not execute Python or call shell commands;
it selects five published methodology IDs and scores verified Media candidates.
Media Methodologies owns the Foreign execution adapter and result authority;
Vision and Camera Behaviour own their underlying observation contracts.

The approved alternative for a future provider is the existing ooRexx Python
Macrospace boundary (including its replacement backend), but this increment
implements the already-qualified Foreign Runtime API rather than inventing a
new integration mechanism.

**Private media remain outside GitHub, including negative-result artifacts.**
A native vs reference-method comparison is not scored as TESTED solely because
its provider completed; an independent checker and substantive forward-model
qualification are still required.
