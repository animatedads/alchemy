# Real Ogg direct-seek qualification — 5 November 2026

**Architecture:** Tom Dyer. **Original SPASH Challenger seek code:** ChatGPT GPT-6. **Independent measurement and grid-alignment correction:** Claude (Opus 5.5), lane spash-3d-acoustic.

**Provenance:** Tom-supplied archive `review_ogg_mp4_20261105.zip`, review `REVIEW_ogg_mp4_20261105.md`; source `spash_ogg_seek_fixed.c`, `ogg_seek_grid_alignment.patch`. This is the independent source-host review as reported by Claude, **not a new execution by ChatGPT**. Private recordings, source hashes and PCM are intentionally absent.

## Host and corpus

- ooRexx 5.3.0 r13196, Foreign Runtime v0.22.6, FFmpeg **native libraries** 6.1.1. No ffmpeg executable as an audio-processing pipeline.
- Source: original TP07 Ogg, Vorbis, 44.1 kHz, 2 channels, 6,268.25 seconds, 162,805,582 compressed bytes. Additional logical audio streams, chained files and other cameras were **not** qualified in this review.

## Fault and correction

Original v0.2 at commit `05c0af2504fd8eee5bac90fc8b3d095e18c5c512` failed to compile with `-Werror` due to unused `requested_ts`. In audio, the Ogg demuxer's Vorbis frame PTS varies with long/short transform-block overlap; rejecting deviations beyond 3 output samples produced false discontinuities. After relaxing that check, seeks suffered 0.14–0.41 output-sample misalignment because the 44,100-to-8,000 Hz resampling grid started at arbitrary post-seek frames.

The reviewed fix sets a **whole-file rational sample grid**: `g=gcd(input_rate,output_rate)`, `P=input_rate/g`, `Q=output_rate/g`. Trim the first decoded frame to an input-sample index divisible by `P` and assign output position `(index/P)*Q`; advance thereafter by decoded output sample count. Treat frame PTS residual as bounded evidence, with a 50 ms tolerance, not as an independent per-frame sample origin. Record `pts_jitter_max_output_samples` in the private receipt. Remove unused `requested_ts`. The implemented patch on PR #135 is commit `3bda0cc9708ccfe59af2bf9b66916e877b672bf3`.

## Claude's independently reported results

- Corrected native source built with `-Werror`.
- Six-second windows at 0, 6, 60, 3,000 and 5,328 seconds (85%) aligned with a decode-from-zero reference: integer lag 0, fractional lag 0; reference SNR 80–99+ dB, reported as sample-identical.
- Deep seek at 85% fetched **1,035,389 bytes** from **162,805,582 bytes** (0.64%) using 18 local seeks. Stream catalogue fetched 130,843 bytes. No read-through from beginning to target.
- Invalid stream or channel, out-of-bounds end, output collision correctly rejected; final full source window succeeded.
- A 1 MiB compressed-read failure case was not demonstrated on this source because the deep request fitted within the budget.

## Still not qualified

Independent validation after the exact new Git commit, multi-logical-stream/chained Ogg, multiple simultaneous channels, large 1 GiB recordings, persistent prebuilt index, cross-file source clock mapping, complete original-audio SPASH enhancement and blind acoustic detection. Native read telemetry is local-only; do not transport whole recordings across Storage Fabric.

The reviewer explicitly differentiated two physical Vorbis channels from separate logical Ogg streams. Do not present this single-source test as general multitrack or chained-stream qualification.
