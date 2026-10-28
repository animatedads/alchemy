# Audio Processing Methodologies

The baseline catalogue contains **66 audio methodologies** spanning acquisition, calibration, restoration, reconstruction, analysis, source separation, spatial acoustics and forensic checks.

## Acquisition and calibration

The first priority is timing and channel integrity: decode with sample-time preservation, declared resampling, inter-channel alignment, clock-drift estimation, DC handling, level measurement, clipping detection, polarity/coherence checks and calibration response measurement.

An amplified listening copy is allowed, but it is not substituted for the source waveform in quantitative analysis.

## Restoration

Classical filtering, spectral subtraction, Wiener/MMSE filtering, wavelet methods, NMF, learned denoising, WPE dereverberation, echo cancellation and hum removal are represented separately because they have different assumptions and artefacts.

A restored listening copy remains derived material.

## Reconstruction

Audio reconstruction includes room-response deconvolution, declipping, dropout concealment, click repair, wow/flutter correction, spectral repair, bandwidth extension, audio super-resolution and blind acoustic deconvolution.

Model-assisted methods must not be allowed to invent evidential speech content. If a model produces a clearer-sounding syllable that was not reliably present in the source, that syllable remains a model candidate.

## Measurement and semantic layers

Voice activity, transient detection, spectral flux, pitch, formants, periodicity and spectral/cepstral features are measurements.

Diarization, ASR and acoustic-event classification are later hypotheses. Anonymous diarization clusters are not named identities. ASR output is a transcript hypothesis with confidence and timing, not a replacement for the waveform.

## Separation

Harmonic/percussive methods, ICA, NMF and learned source separation all remain available. Separation leakage and suppression are first-class failure modes, so a separated stem cannot be assumed to contain “everything speaker A said.”

## Spatial methods

GCC-PHAT, SRP-PHAT, delay-and-sum, MVDR, GEV, MUSIC, room-response estimation, fused localization and acoustic imaging are specified independently.

Spatial methods require explicit array geometry and channel timing. Without those, lack of a localized source is not negative evidence that no source existed.

## Forensic methods

The catalogue includes ENF analysis, codec artefacts, splice/discontinuity analysis, double-encoding indicators, reverberation consistency, noise-floor continuity, channel coherence and packet/sample timeline audit.

These produce cautious hypotheses and continuity evidence, not automatic conclusions about editing intent or provenance.


## Multipath reconstruction and path evidence

Dev5 adds a distinct five-method multipath family covering sparse coherent-path estimation, spectral trajectory tracking, motion-induced coherence, bounded physics compatibility and trajectory-conditioned virtual-microphone reconstruction. These methods are intentionally not collapsed into generic echo cancellation or beamforming. Delay remains excess-path timing, path-rate remains excess-path-rate, and a reconstructed waveform remains derived candidate material. See `AUDIO_MULTIPATH_METHODS.md`.
