# Integration boundary

## FC

- 32x18 FC evidence maps naturally to a `VisionSamplingLattice("RECT",1,0,0,1)`.
- Camera authority/reacquisition stays in FC Vehicle Motion.
- Only admitted, authoritative FC episode samples are projected.
- Per-sample centroids are transformed WORLD -> TRACK before accumulation.
- `CAR_MOTION` remains an FC observational label, not a Vision classification.

## FD next

FD should use the same pattern downstream: stable F11 geometry and coherent
probe measurements can be represented as Vision regions/observations after the
sealed FD detector decides geometry authority. Vision must not replace FD's
night locator, exclusion/reacquisition rules, or mechanical-event gate.

## AOI

Vision's AOI request object is a good future seam for asking Storage Fabric for
source-resolution material around a detected region/time interval without
placing raster/video payloads into Queue Fabric messages.
