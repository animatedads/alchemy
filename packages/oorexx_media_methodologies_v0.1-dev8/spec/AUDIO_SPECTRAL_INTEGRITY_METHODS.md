# Audio Spectral Integrity methods

Media Methodologies dev8 consumes **Audio Spectral Integrity v0.2** as a provider-neutral experimental backend.  The provider remains the owner of the transforms; this package owns only methodology registration, applicability, execution profiles, experiment lineage and provenance glue.

The methods are intentionally plural and bounded:

- `AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS` creates complementary odd/even alternating spectral views from **one** captured waveform.  Their exact recombination inside the selected passband is a transform identity, not evidence that the recording contained two physical sources.
- `AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP` repeats the partition at predeclared bucket origins and measures how strongly conclusions depend on arbitrary mask boundaries.
- `AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW` attenuates the non-preferred bucket set and peak-scales the result.  It is a derived listening candidate and adds no information.
- `AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION` measures expected-harmonic support only when an independent `f0` hypothesis is supplied.  It does not infer speaker identity or a second source.
- `QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL` constructs a mathematically known two-input spectral weave.  Only this controlled fixture has known per-bucket source ownership.

## Scientific boundary

Field results may support statements about the declared transform, bucket energy, phase sensitivity, recombination error or externally seeded harmonic support.  They do not by themselves establish words, speakers, source count, emitters, intent, a historical multiplexing process, or criminal conduct.

All transformed streams remain derived material.  Originals and immutable source references must be retained separately.  Blind listening notes are observations about listeners, not an automatic semantic label on the source waveform.
