# Cross-modal Audio / Video Methodologies

Cross-modal analysis begins only after each modality has its own timing, source identity and authority state.

## Clock alignment

`AV.SYNC.CLOCK` explicitly maps audio sample time, video PTS and optional wall-clock anchors. Multiple mappings may coexist until an anchor resolves them. Clock residuals and discontinuities are preserved.

## Event lag and coupling

`AV.SYNC.TRANSIENT_MOTION` measures lag between audio events and visual/mechanical motion. `AV.COUPLING.ACOUSTIC_MECHANICAL` goes further and tests a physical-coupling hypothesis using matched controls, lagged response profiles and visual camera-motion authority.

Temporal correlation alone is not causation. A shared third cause can drive both modalities.

## Visual microphone

`AV.VISUAL_MICROPHONE` is intentionally experimental. Surface vibration seen in video can sometimes recover an audio-band candidate. The result is a reconstructed signal whose bandwidth and fidelity are limited by frame rate/readout, texture, compression and the surface's mechanical transfer function. It is not a direct microphone recording.

## Speech/lip synchrony

This method compares anonymous mouth-region motion with speech timing. It is a synchrony hypothesis and does not identify a person.

## Fusion and contradictions

Audio localization can be intersected with visual geometry. Event streams can be compared for co-occurrence. But disagreement is preserved through `AV.CONTRADICTION.ANALYSIS`; the framework does not distort one modality until it agrees with another.

`AV.RECON.CONSENSUS` compares reconstruction candidates while retaining common-method lineage, support and disagreement maps.
