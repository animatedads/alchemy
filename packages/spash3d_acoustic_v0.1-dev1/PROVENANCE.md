# Provenance — SPASH 3D Acoustic v0.1-dev1

Architecture: Tom Dyer. Coding: Claude (Opus 5.5), 31 Oct to 7 Nov 2026, lane spash-3d-acoustic.

- Native provider base: `packages/audio_v9_voice_recovery_v0.1-dev16/native/av9_spatial_provider.c` (10 functions).
  This package adds 19 functions (listed in README.md); none of the base functions is changed in behaviour.
- `src/AudioV9SpatialNativeProvider.cls`: the dev16 class plus methods for the added functions. The other Audio V9
  classes are used unchanged from dev16 (`tools/rx.sh` puts dev16 `src` on the path).
- `spash3d/F11SceneV04.cls`: the F11 scene as built by Physics World's `tests/f11_vehicle_experiment.rex`.
- Data inputs (not included): the FD and FC camera originals of 9–10 Oct 2023, TP1–TP9 FD and TP28–TP34 FC, decoded to
  8 kHz mono float32. Their identity is their SHA-256 in the campaign manifest of the audio_v9_voice_recovery line.
- Voice profiles: statistics from sample voices supplied by Tom with neutral labels; samples and their labels are
  not kept (Tom, 5 Nov 2026).
- Verified on 6–7 Nov 2026: `moment_render.rex` reproduced the earlier FD renders byte for byte; native build passes
  with -Wall -Wextra -Werror.
