# Audio quality corpus v2

`AUDIO-QUALITY-TARGETS-V2` replaces the fixed two-reference profile with a manifest-backed corpus. The native scorer reads `QUALITY_CORPUS.tsv`; adding future references no longer requires changing the foreign ABI or the Rexx search entry points.

The corpus currently contains four distinct prepared references. The two historical references remain as contrast, while two sample-exact windows from the user-supplied 2026-09-08 WhatsApp recording add the quiet/high-register coverage that the previous pair lacked:

1. `quality_target_01_whatsapp_16k_mono_pcm16.wav` — historical real-speech contrast.
2. `quality_target_02_upspeak_16k_mono_pcm16.wav` — historical brighter-speech contrast.
3. `quality_target_03_quiet_voice_16k_mono_pcm16.wav` — source 08:09..08:57 (489..537 s), preserving a very quiet speech-bearing regime.
4. `quality_target_04_high_register_16k_mono_pcm16.wav` — source 12:45..13:33 (765..813 s), preserving a brighter/high-register regime.

The two new references are decoded/downmixed/resampled only. There is no gain, denoise, compression, gating, loudness normalization or peak normalization, so the quiet-vs-bright level distinction remains part of the reference evidence.

## Duplicate handling

The separately uploaded `24 August Threats ... 1(2).mp3` has SHA-256 `f59b6f88ac7693655d0a1610e8380442853afcb6a94534d2d28b48a45c17c867`, exactly the same source hash already represented by target 01. It is therefore recorded as duplicate provenance but is not inserted again and cannot silently double-weight that voice.

## Corpus semantics

The native profile is built over every manifest reference (2..32 supported). Global and temporal centers/scales are robust across references, while candidate two-second windows are scored against the nearest reference window across the whole corpus. This gives quiet/high-register speech explicit support without removing the older contrast material.

Scores produced with v2 are not numerically comparable with pre-v2 reference-profile scores.
