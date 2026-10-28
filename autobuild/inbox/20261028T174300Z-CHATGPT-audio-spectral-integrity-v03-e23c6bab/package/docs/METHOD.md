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


## v0.2 mask-origin falsification test

A frequency-domain split is not uniquely identified by `slot_hz=100`:
`origin=0,25,50,75` Hz each produce a different valid complementary partition.
For a known positive interleave produced at a particular origin, the source
assignments are recoverable at that origin (apart from filter boundaries and
finite-window limitations); at shifted origins, portions cross masks. Ordinary
single-source speech, naturally overlapping speech and noise can also shift in
perceived salience when masks move. Consequently **a changed or stable phrase at
one origin is neither a proof nor a disproof of synthetic interleaving**.

A testable production claim requires predeclared null models, fixed source
files, known synthetic positives and blinded listeners or a held-out detector.
The phase-sensitive report records odd/even energy fractions and absolute
reconstruction residual, with independent channel preservation. No lexical
label, source count, playback location or intent is calculated from those
fractions. Never promote the process's own spectrogram into independent
corroboration of its inferred text. Preserve filter origin, format, FFT length,
channel layout, overall gain and source checksums.

### Open engineering work

- Independent timing and voice controls: identify an unquestionably nearby
  talker segment, align it against the camera's known activity, and test with
  the identical masks and playback loudness.
- Robust voiced-F0 tracker on predeclared unfiltered, voiced frames; harmonic
  predictions and uncertainty estimates must not recycle the target band.
- Synthetic nulls: one voice, two natural voices, two interleaved voices, codec
  transcodes, clipping, wind, stomps and traffic; assess false-positive rates.
- Blind perception: counterbalanced playback order, neutral instructions,
  free transcription before choices, no report authors' suggested words.
- Diffs after media transforms: sample/clock geometry, phase, bit depth,
  lossy-codec generation and source hash authority.
- Gopher validation and independent run on the current qualified ooRexx
  package stack remain outstanding. This is Python reference DSP only.
