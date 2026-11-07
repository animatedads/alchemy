# SPASH 3D Acoustic v0.1-dev1 — audio processing code

Architecture: Tom Dyer. Coding: Claude (Opus 5.5). Written by: Claude (Opus 5.5). Lane: spash-3d-acoustic.

The audio processing code behind the Cyprus FD/FC work, 31 Oct to 7 Nov 2026: the Audio V9 native provider with 19
added functions, the ooRexx tools that run it, and the voice-profile data models. Code and statistics only:
**no audio, no transcriptions, no sample recordings** are in this package, by rule.

## What it does

| Area | Tools | What they make |
| --- | --- | --- |
| Clean (amp, filter, amp) | `spash3d/full_union.rex`, `finish_union.rex`, `moment_render.rex`, `v7_cleaned.rex` | Speech AGC, bird-screech (tonal burst) and cat-call removal, MMSE enhancer 90–3600 Hz, speech tilt, voice masks, speech AGC; removal log of every cut |
| Multi-pitch | native `multi_f0_f32`, `src` method `multiF0` | Up to 4 simultaneous pitches per 10 ms frame by iterative harmonic cancellation |
| Spectral brackets | `spash3d/multitrack.rex` | One Ogg with a track per pitch bracket (default 0–150, 151–190, 190–240, 240–302, 302–381, 381–480 Hz) plus a reference |
| Voice lines and split | `patterns/mlines.rex`, `patterns/split.rex`, `blocks.rex`, `contours.rex`, `roll.rex`, `peek.rex` | Continuous pitch lines, level-by-level collections, one file per group |
| Voice profiles and SLAM decision | `VoiceProfile.cls`, `voice_set_build.rex`, `profile_matrix.rex`, `night_slam.rex`, `night_render.rex`, `fd_scan.rex`, `fd_pick.rex` | Profiles, overlap matrix, per-run decisions (one profile or a union), candidate scans |
| Clocks | `FeedChain.cls`, `FdChain.cls`, `fd_place.rex`, `fc_place.rex`, `clock_*.rex` | FD chain TP1–TP9 (TP7 anchored at 11:14:49); FC − FD = 0.9065 + 0.1331 h |
| Comprehension aid (not evidence) | native `spectral_smooth_f32`, `comprehension/smooth_test.rex` | Smoothed and bandwidth-rebuilt copies; must stay apart from evidence renders |

## Native additions (to the dev16 provider's 10 functions)

`band_blocks_tsv, compare_tsv, enhance_f32, envelope_f32, gccphat_tsv, harmonic_f0, multi_f0_f32, pitch_f32, rake_f32,
spectral_smooth_f32, speech_agc_f32, stationary_suppress_f32, template_scan_tsv, tonal_burst_suppress_f32,
voice_features, voice_mask_f32, voice_mask_union_f32, xcorr_tsv, yin_f0` — all in `native/av9_spatial_provider.c`,
registered in `native/av9_spatial.bridge.json`, wrapped in `src/AudioV9SpatialNativeProvider.cls`.

## Build and run

```
sh native/build_native.sh
export ALCHEMY=/path/to/alchemy FR_ROOT=/path/to/foreign_runtime_v0.22.6
sh tools/rx.sh spash3d/multitrack.rex tp01 /path/to/pcm /path/to/work out.ogg -20 12k voice_0-150Hz:60-150,voice_151-190Hz:151-190,voice_190-240Hz:190-240,voice_240-302Hz:240-302,voice_302-381Hz:302-381,voice_381-480Hz:381-480
```

Inputs are 8 kHz mono float32 decodes of the camera originals (`pcm/tpNN.f32`); ffmpeg is used for container decode
and encode only.

## Test

```
sh tests/make_synthetic_mix.sh mix.f32
sh tools/rx.sh tests/test_mf0.rex mix.f32 mix.mf0.tsv
```

Expected on 6 Nov 2026: all 755 expected voice-frames of the three synthetic voices found (130, 210, 285 Hz,
overlapping), median pitch error 0.8 %, about 2 % stray picks at voice edges.

## Voice profiles

`profiles/` holds the profile data model only (format `VOICE_PROFILE/2`: pitch buckets at 1/24 octave, 32-band
shape mean and sd, p5–p95 pitch window, strict threshold), with neutral labels, plus the 6 Nov overlap matrix.
No audio and no sample files; profiles are statistics only (Tom, 7 Nov 2026).

## Rules carried by this package

- Police matter: times and acoustic labels only in shared artifacts; never wording.
- Private audio never goes into git.
- Evidence and comprehension-only outputs stay apart.
- Every update states architecture (Tom Dyer), coding, and who wrote it.
