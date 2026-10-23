# Audio Spectral Integrity Lab v0.1

Reproducible, provider-neutral *research method* for band-limited listening views, alternating 100 Hz odd/even spectral buckets, and testable voiced-harmonic hypotheses. Intended to complement Layered Audio and Audio V9; **not a replacement for their evidence or reconstruction APIs**.

This is a standalone Python reference backend that requires NumPy and SoundFile for FLAC I/O. `spectral_integrity.py` does not change originals. It retains stereo for processing and writes peak-limited 24-bit FLAC previews. Audio, privacy-sensitive media, and maps are **not** bundled or uploaded to GitHub.

## Basic usage

```sh
python3 src/spectral_integrity.py /local/private/original.wav /local/private/output --tail-s 20 --slot-hz 100 --ceiling-hz 8000
./run_tests.sh
```

Even bins: 0..100, 200..300, ... Hz. Odd bins: 100..200, 300..400, ... Hz. Relative preference is achieved by *attenuating non-preferred bins* 12 dB or 24 dB, then a shared peak-safe scale. Do not interpret the nominal +24 dB preference as +24 dB of added acoustic information. Integer slot boundaries are half-open intervals; the high-ceiling is excluded.

This reference implementation uses rectangular full-clip FFT masks (with consequent ringing); it does **not** assert the original recording was assembled in this way. Unlike a multichannel source separator, odd/even filters split **one** captured waveform. Each view may change intelligibility without uncovering a new source.

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
