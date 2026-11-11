# SPASH Ogg native seek + multitrack v0.2 (TP07 native qualification; full multistream pending)

Architecture: Tom Dyer. Implementation increment: ChatGPT GPT-6. Additive to PR #135 and the SPASH Challenger lane. All source selection, processing, scoring, and execution authority stays with ooRexx. Native C/libav is exclusively a Foreign Runtime codec/IO implementation provider.

## Why this exists

A 1 GiB original Ogg file must stay on its resident machine. Storage Fabric transports the immutable content reference, placement, a small track catalogue/clock/seek receipt and derived feature refs, **never the original payload on each query**. The owning MU executes the job against its local original; private f32 excerpts and enhancement derivatives stay resident. No Python, ffmpeg command line, remote protocol, cloud ASR or transfer is used by this provider.

## Contract

- `catalogue(localOriginal, privateManifest, maxReadMb=64)` opens a **local regular seekable Ogg file**, identifies every FFmpeg-demuxer-visible logical audio stream separately, and records track index, codec, physical channel count, rate, stream PTS origin, timebase, duration and declared bit rate. Native formats can be variable bitrate. This is a compact descriptive catalogue, **not** an established persistent Ogg granule index.
- `decode(localOriginal, privateF32, privateReceipt, streamIndex, channelIndex, startMs, durationMs, targetRate=8000, maxReadMb=64)` chooses a logical stream plus a zero-based physical channel; performs an `av_seek_frame(... AVSEEK_FLAG_BACKWARD)` at `startMs - 5s`, decodes local preroll, and outputs the exact selected interval by stream presentation timestamp. The requested time is relative to that audio stream's PTS origin, **not** an FD/FC wall-clock or video time. The output remains a private mono f32 float buffer for Audio V9 native methods.
- Custom AVIO uses `pread` and local seek callbacks, with a maximum **64 MiB compressed-data budget by default**, irrespective of source length. It records actual compressed bytes read, local seeks, compressed source size, selected packet/frame counts, output sample count and clock authority. Overshoot, non-monotone/chained PTS, corruption, missing timestamps, nonseekable files, unsupported formats, and incomplete requested output fail closed without publishing partial files.
- Qualified deep seek must use *far fewer bytes than source size*, not simply report a successful timestamp. For a 1 GiB test, target at least 80% of media duration and measure `compressed_bytes_fetched / compressed_file_size_bytes`; in addition check output sample equality and waveform alignment against a trusted reference. A sparse persistent seek index and session cache are not claimed by this increment.
- Multiple logical streams can be individually selected; multiple physical channels within each can be independently selected. **Simultaneous synchronized multi-stream PCM rendering, chained Ogg serial transitions, Ogg muxing/VBR encoding, true sample-exact cross-track synchronisation and reuse of a persistent decoder handle are not qualified**; require explicit separate gates.

## Native host test

`sh build_seek_linux.sh`

Place `spash_ogg_seek.bridge.json` beside `libspash_ogg_seek.so`, set `REXX_PATH` to this package + actual `foreign.cls`, and execute:

`rexx qualify_seek.rex /private/bridge.json /home/hc3/blinkdl/testaudio/fcpaphos/<approved original> /private/report 0 0 <seek_ms_in_last_20_percent>`

Test multiple logical streams and every physical channel, reference expected 6 s x 8 kHz = 48,000 float32 samples = 192,000 bytes, compare independent root/late excerpts and VBR/seek-to-boundary. Force a 1 MiB read budget to test fail-closed; test 1 GiB source and confirm deep seeks read far less than 1 GiB. Pre-existing targets must remain untouched. Include last partial-window failure, deliberate malformed/Ogg chain, channel missing, unknown timebase, and source-digest before/after; any negative must reject.

## Storage Fabric placement

Deploy source once through existing permitted resident-MU placement. The durable identity is the source StorageRef/digest and location/replica set; a working local path is resolved **on that MU only** through the existing storage/residency subsystem. A job message carries `{source_ref, stream_index, channel_index, start_ms, duration_ms, target_rate, method_id}`, not raw Ogg or PCM. Validate the replica digest and authorization at the MU; send only bounded candidate metadata and source/derivative references to the control plane. This package does **not** implement or impersonate Storage Fabric placement, hash verification, cache eviction or a live 10-MU scheduler.

## Qualification status

CODEX-PC qualified the **pre-source-fence** PR135 native decoder on 7 November 2026 (REQ-00003345): ooRexx 5.3.0 r13196, Foreign Runtime v0.22.6 and libav 7.1.5 built with -Werror; real TP07 162,805,582-byte Ogg, one logical stream, two physical channels. The 85%-deep six-second seek read 1,035,389 compressed bytes (0.636%) with 18 local seeks. Six- and 60-second excerpts were byte-identical against longer start-origin native output. Independent deep-seek reference equality, chained logical streams, genuine 1 GiB source and source-audio enhancement remain **unqualified**. No private recording or derived PCM is in Git.

On 11 November, a native **local source-mutation fence** was added to catalogue and decode acceptance. It records local file-descriptor device/inode/size/mode/mtime/ctime, rejects changed originals and deletes partial outputs. The standalone synthetic C test passed locally and through an **Autobuilder PASS receipt** for immutable package `packages/oorexx_ogg_source_fence_v0.1`, submission `20261111T175659Z-CHATGPT-oorexx-ogg-source-fence-v0.1-25942a`. That receipt does **not** qualify the integrated libav seek provider after the fence modification. It is not a replacement for Storage Fabric source SHA/durable lease.

A reusable Gopher sphere has also been **Autobuilder accepted and confirmed readable through Rasen Falcon**: `spash-ogg-seek`, articles `ogg.seek.start` and `ogg.seek.storage`, submission `20261111T180117Z-CHATGPT-spash-ogg-seek-sphere-v0.1-9197ed`. Consult it before modifying hot seeking or Storage Fabric traffic. This draft PR135 remains unmerged; require a new source-host compile + negative concurrent-mutation test before marking the integrated provider qualified.