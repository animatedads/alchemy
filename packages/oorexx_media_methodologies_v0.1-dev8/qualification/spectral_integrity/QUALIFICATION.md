# Spectral Integrity dev8 qualification

This qualification exercises the five Audio Spectral Integrity v0.2 methodologies added by Media Methodologies dev8.  It does **not** infer words, speakers, source count, emitters, intention or a historical multiplexing process.

## Runtime and upstream

- ooRexx: 5.3.0 r13196, Internal Test Version, build 2026-08-03.
- upstream provider: Audio Spectral Integrity v0.2.
- Python backend: NumPy + SoundFile, dynamically imported from the explicit upstream root.

## Real TP00001 source interval

The already retained `qualification/audio_v9_real/source_listening.wav` is used only as field material for transform qualification.

- Complementary 100 Hz bucket views at 0 Hz offset: `MEASUREMENT`; passband recombination maximum absolute residual `1.3877787807814457e-17`.
- Phase sweep at offsets 0/25/50/75 Hz: odd-band power fraction changes from `0.300019` to `0.577104`; range `0.277085`.  The passband recombination residual remains `1.3877787807814457e-17` at every offset.  This demonstrates substantial boundary sensitivity and is a reason **not** to select one persuasive bucket origin after listening.
- 24 dB odd-preference view: `CANDIDATE`; peak-safe scale `1.0`; `observation_promotion=false`; the output is a listening transform, not recovered source truth.
- Harmonic observation without external f0: `NOT_APPLICABLE / EXTERNAL_F0_REQUIRED`.

## Controlled known-truth fixtures

A deterministic 16 kHz stereo fixture supplies a declared 200 Hz f0 with known harmonics.  The externally seeded harmonic method emits 1,940 local expected-harmonic observations.  This proves the measurement path, not speaker identity.

A separate known two-input control assigns A to even 100 Hz slots and B to odd slots.  Recovery errors are approximately `2.50e-16` (even/A) and `2.22e-16` (odd/B).  Only this controlled construction has known per-bucket source ownership; field material does not.

## Authority boundary

All outputs are derived.  Complementary views and phase/harmonic tables are measurements of declared transforms.  Preference audio remains a reconstruction/listening candidate.  No result can become a captured observation, and no field bucket is labelled as an independent source.
