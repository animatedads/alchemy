# Spectral-Interleaving Method and Falsification

## Controlled synthesis

Let recorded or generated utterances A(t), B(t) have FFTs A(f), B(f). With complementary masks M_even(f) and M_odd(f), the controlled example is:

```
Y(f) = M_even(f) A(f) + M_odd(f) B(f)
```

The demonstration may recover different words from `M_even Y` and `M_odd Y`. This shows technical *possibility* only. Existing recordings can be used; TTS is not necessary. An ordinary sum `A+B` is a control. Use balanced spectral power, synchronized utterances and controlled playback levels; log voices, phonemes, codec and rendering setup.

## Field-recording diagnostic

For one unknown capture X(f), `M_even X` and `M_odd X` are merely complementary listening transforms. The identity `M_even X + M_odd X = M_passband X` is a mathematical identity and **not evidence** of multiple pre-mixed sources. Fixed preference mixes attenuate alternative bins to protect from clipping; never amplify noise and then claim new acoustic content. Introduce TTS weaving only as a *positive reference*, alongside unmodified single-speaker, two-speaker natural overlap, media playback and traffic/noise negatives. Preserve L/R independently.

Compare control samples of known close speech and distant speech; estimate f0 from sufficiently broadband voiced frames, predict harmonics with uncertainty intervals, and test energy near them against local spectrum. Missing lines alone are non-diagnostic. If a second source is proposed, require time-continuous phonetic/harmonic coherence, independent channel/spatial evidence, and null-model rejection before describing it as a source track. No phrase should be marked confirmed solely because repeated listeners agree on filtered versions.

## Reporting hierarchy

1. Observed: recording duration, PCM sample counts, original checksum, band transform parameters.
2. Measured: band energies, envelope variance, spectral peaks, artifacts and channel differences.
3. Candidate: human hearing/automated ASR hypotheses with blind test logs, alternatives and confidence limits.
4. Attribution: requires independent provenance, not the spectral view alone.

Raw recordings of private conversations and minors do not belong in public source control. Source text in this repository is intentionally free of field-specific allegations or precise locations.
