# Reference plural audio reconstruction providers

API seam: `media.methodologies.reference-audio-provider/0.1`.

This package intentionally supplies several implementations rather than a preferred enhancer.  Every output is a derived candidate.  Captured audio remains the source authority.

Implemented provider paths:

- `AUDIO.DENOISE.SPECTRAL_SUBTRACTION` — stationary low-energy noise profile plus magnitude subtraction.
- `AUDIO.DENOISE.WIENER` — PSD-derived Wiener gain.
- `AUDIO.DENOISE.NMF` — nonnegative matrix factorisation with an explicit stationary-component suppression heuristic.
- `AUDIO.HARMONIC_PERCUSSIVE` — median-morphology harmonic component; this is partial-component evidence, not a complete recovered utterance.
- `AUDIO.SPECTRAL.REPAIR` — experimental local time-frequency interpolation; requires an explicit damage mask and marks repaired samples as synthetic rather than observed support.

## Independence

Different methodology IDs do not imply independent evidence.  Each result declares `implementation_foundations`.  Spectral subtraction and Wiener filtering intentionally share the STFT and low-energy noise profile and therefore cannot count as fully independent corroboration.  NMF shares the STFT front-end but uses a separate factorisation path.  HPSS uses separate median morphology.  Spectral repair uses local complex-bin interpolation and an explicit damage mask.

## Real evidence

For real audio there is no clean target.  Pairwise waveform correlation is descriptive only and must not be interpreted as accuracy.  No provider elects a winner.

## Known-truth qualification

Synthetic qualification may compare candidates with a known clean signal because the truth was generated before corruption.  Those scores qualify an implementation under the fixture; they do not transfer automatically to a real recording.
