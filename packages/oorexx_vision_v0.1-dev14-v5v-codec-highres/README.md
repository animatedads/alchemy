# ooRexx Vision v0.1-dev10 — real Termux three-target bench

dev10 grounds the first live bench in the supplied correctly-oriented Termux
camera capture.

The authoritative camera image is reduced first to the normal ~4K Vision
evidence scale. Target discovery then uses local contrast, Line Continuity and
compact closed-region geometry; raw-resolution RGB is not a recognition input.

Adds `VisionLocalContrast` and `VisionProjectedTargetPolicy`, plus a derived
55x73 positive fixture. The fixture demonstrates the intended processing
boundary without redistributing the full camera source.

The target is deliberately "three compact projected regions", not "three
mathematical squares": perspective and clipped/sloping corners are legitimate.

No hand recognition, gestures or 3D callbacks are in this qualification.


## dev14 — V5V codec + selective high-resolution request

This package adds the current V5V temporal codec contract and the explicit
high-resolution evidence request module.

`V5VTemporalCodec` treats the encoded VisionSurface as the observation to
preserve.  Exact keyframes and exact `VisionSurfaceDelta` records are the
baseline.  Camera Behaviour and Line Assessment may later supply advisory
evidence maps for smarter packing, but neither becomes part of the codec and
EXACT_SURFACE policy may not silently discard observations.

`VisionHighResolutionRequest` wraps the existing `VisionRegionRequest` contract.
It identifies the authoritative source, stable region, time interval, requested
source resolution and purpose.  Fulfilment is represented by
`VisionRegionMaterial`; large media bytes remain behind the material/source
reference rather than being embedded in the request object.

The current phone/live FFmpeg source from dev13 remains included.
