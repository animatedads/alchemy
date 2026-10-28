# Audio Spectral Integrity Lab v0.2

Reproducible, provider-neutral *research method* for band-limited listening views, alternating 100 Hz odd/even spectral buckets, and testable voiced-harmonic hypotheses. Intended to complement Layered Audio and Audio V9; **not a replacement for their evidence or reconstruction APIs**.

This is a standalone Python reference backend that requires NumPy and SoundFile for FLAC I/O. `spectral_integrity.py` does not change originals. It retains stereo for processing and writes peak-limited 24-bit FLAC previews. Audio, privacy-sensitive media, and maps are **not** bundled or uploaded to GitHub.

## Basic usage

```sh
python3 src/spectral_integrity.py /local/private/original.wav /local/private/output --tail-s 20 --slot-hz 100 --ceiling-hz 8000
./run_tests.sh
```

Even bins: 0..100, 200..300, ... Hz. Odd bins: 100..200, 300..400, ... Hz. Relative preference is achieved by *attenuating non-preferred bins* 12 dB or 24 dB, then a shared peak-safe scale. Do not interpret the nominal +24 dB preference as +24 dB of added acoustic information. Integer slot boundaries are half-open intervals; the high-ceiling is excluded.

This reference implementation uses rectangular full-clip FFT masks (with consequent ringing); it does **not** assert the original recording was assembled in this way. Unlike a multichannel source separator, odd/even filters split **one** captured waveform. Each view may change intelligibility without uncovering a new source.

## v0.2 bounded research increment

- `rfft_views(..., offset_hz)` shifts the alternating slot boundaries without altering
  source samples. Frequencies below the first offset form an even partial slot.
- `bucket_phase_sweep()` measures complementary odd/even energy fractions and exact
  passband-reconstruction error at configured origins (0, 25, 50, 75 Hz by default).
  These fractions **cannot** classify speech or prove two sources.
- `synthesize_interleaved(A, B, ...)` supplies a mathematically known, two-input
  positive control; the unknown field recording is never used as the positive truth.
- The command line exports shifted odd- and even-preferred 24 dB listening views
  and `phase_sensitivity.csv` beside earlier reference views. No adaptive gain in
  these comparisons; each preview is peak-safe.
- New test fixtures verify stereo preservation, recombination, positive control
  source assignment, phase-dependent energy redistribution and invalid offsets.

Example on private material:

```sh
python3 src/spectral_integrity.py /local/original.wav /local/views \
  --tail-s 20 --slot-hz 100 --ceiling-hz 8000 \
  --offsets-hz 0,25,50,75
```

## Method and limitations

`rfft_views()` preserves sample count, stereo differences, channel phase and exact unweighted reconstruction inside the selected 0..ceiling region. `preference()` uses fixed relative attenuation; `bounded_quiet_gain()` is a distinct, explicitly nonlinear exploratory listening transform and must never be conflated with the linear source-preserving test. `sweep_bands()` enumerates 200 Hz envelope candidates, not calibrated speech probabilities. `harmonic_observations()` accepts an externally proposed voiced f0, reports peak/floor evidence, and does not estimate independent pitch from each narrow band.

A missing expected harmonic does not prove digital multiplexing: formants, voiced/unvoiced phonemes, glottal source differences, recording response, codec, noise, phase cancellation or band masks can create gaps. Multiple audible messages or listener agreement similarly do not prove a particular physical playback emitter, intentional staging, operator, or crime.

For an investigation, separately retain: immutable source hashes; transformation parameters; listening notes recorded blind to candidate text; original plus derived streams; independent provenance of media; and an independently testable alternative-source/null model. Do not publish or infer named persons/locations from processed snippets.

## Project boundaries

- Layered Audio: provider-neutral semantic processing, provenance, parallel views.
- Audio V9: acoustics, source tracks, FC/FD reconstruction, ML and independent corroboration.
- Video/Pose: separately timestamped contact events are calibration observations, never clock authority by themselves.
- Storage Fabric: immutable source and derived object material.
- Compute/Job-to-Node: optional placement with no machine-local path encoded in job definitions.

See `docs/METHOD.md`, `docs/EXPERIMENT_LEDGER.md` and `sphere/`.

## v0.3 — falsification and blinded evaluation increment

`windowed_bucket_views()` adds time-local, sqrt-Hann windowed-overlap-add (WOLA) odd/even views to compare against full-clip circular-FFT ringing. At Nyquist only, the windowed method includes the terminal bin for exact full-band reconstruction. No source inference is made.

`oracle_template_projection()` fits real coefficients from exact, known reference inputs A and B, separately by odd/even spectral buckets. On the deliberately woven positive control the fitted odd/even coefficients identify the synthetically assigned sources, while on the ordinary A+B control both are present. **This oracle requires the original A/B references and cannot be used to identify sources in an unknown recording.**

`control_examples()` and `src/blind_trial.py` supply four anonymous test conditions: original A, filtered/notched A, ordinary simultaneous A+B and deliberate A_even+B_odd. The blind-trial response template contains no expected words; a private mapping is chmod 0600 and must stay off public GitHub. RMS matching is coarse and not psychophysical loudness calibration. See `docs/CONTROL_PROTOCOL.md`.

Local test: `sh run_tests.sh`. Private trial command: `python3 src/blind_trial.py A.flac B.flac /private/trial --ceiling-hz 8000`. The bundle ships no recordings or personally identifying location/site details.
