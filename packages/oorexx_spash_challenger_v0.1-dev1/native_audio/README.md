# SPASH Challenger native bounded Ogg input — dev1

## Update: v0.2 resident multistream direct seek (5 November 2026)

The former v0.1 `SpashNativeOggDecoder` decodes from the beginning and is **NOT** suitable for deep repeated reads of 1 GiB originals. Use the additive `seek/SpashNativeOggSeek.cls` and `seek/spash_ogg_seek.c` for new random-access qualification. It enumerates logical streams, selects individual channels, calls libavformat native time-based byte seeking against a resident original, and enforces a 64 MiB default compressed-byte budget. The source Ogg, working PCM and derived buffers remain on the resident MU; only immutable refs and compact metadata cross Storage Fabric. A genuinely validated 1 GiB deep seek and multistream source timing still require original-host tests. See `seek/README.md` and `seek/tests/run_contract_tests.sh` (tests use a stub and do not qualify actual decoding). Never deploy the test stub as a Foreign Runtime provider.


Architecture: Tom Dyer. Implementation: ChatGPT GPT-6. This is an additive SPASH Challenger Foreign Runtime provider; it does not change Audio V9/Claude modules or production services.

## Purpose

Remove the exact missing input blocker observed in CODEX-PC's authenticated REQ-00003105: original Ogg/Vorbis must be decoded from the user-authorised local original files **inside an ooRexx-controlled pipeline**, not by launching the ffmpeg executable or invoking Python. The provider is C/libavformat+libavcodec+libswresample reached exclusively through `.foreign~load()` from ooRexx. C implements bounded source decoding and physically selected channel extraction only. ooRexx retains all application orchestration, evidence labelling, window admission, enhancement, processing and audit authority. No ASR, speaker attribution or cloud APIs.

## Contract

- Input: existing original Ogg (read only), physical channel index zero-based; source-start offset in **milliseconds of decoded audio output sample ordinal**, not filename/wall clock; duration 1..120000 ms; 8/16/48 kHz output rate.
- Exact sample count: `duration_ms * output_rate / 1000`, output float32 mono only, exclusive-create mode 0600. For 6s@8kHz: exactly 48,000 samples / 192,000 bytes. Output may be directly passed to the existing `AudioV9SpatialNativeProvider~renderMask` after source-specific mask geometry has independently been qualified.
- Report: separate private TSV recording source sample rate, selected channel, output sample count, peak, and explicit `DECODED_AUDIO_SAMPLE_ORDINAL_ONLY` clock authority. Never project to FD/FC chain time without an observed source origin map.
- Every failure (unsupported layout, missing decoder, source truncation, corrupt packet, existing target, fractional/infinite data) fails closed and removes partially created outputs. No source modifications.
- There is **no** wave/PCM upload, Git attachment of input, metadata from a specific source, generic speech identification, timeline alignment or enhancement effectiveness result here.

## Host qualification

1. Build host-local: `sh build_linux.sh` with libav development packages already installed. This builds the provider only; it never processes media.
2. Place the bridge JSON beside `libspash_ogg_decode.so` in a private host test directory; ensure the existing foreign.cls/Foreign Runtime path is on `REXX_PATH`.
3. Run via ooRexx only, on a private copy of the bridge and source original in place: `REXX_PATH=<src:foreign_path> rexx qualify_decode.rex <private_bridge_path> <original_tp_ogg> <new_private_f32> <new_private_report_tsv> 0 0`.
4. Verify private output byte count for 6s at 8kHz, compare channel-specific short-window PCM with an independently trusted decoder in a controlled *test-only* process as permitted, and validate actual source channel count/sample rate. Only after signal integrity passes feed f32 into qualified Audio V9 native analysis and A/B mask rendering.
5. Verify a nonzero original offset, the final-media edge, missing channel and preexisting destination fail closed; run direct source integrity check before and after. Validate sample origin against Ogg granule/MP4 clocks separately; this implementation **does not** resolve cross-media or video offset.

## Limits/status

`CODE_PENDING_HOST_BUILD_AND_TEST`: code and build recipe are supplied, but there is no local libav development toolchain or local source recordings in this development container, so native execution, Ogg Vorbis sample accuracy, exact Foreign Runtime ABI and enhancement A/B remain unqualified. Do not advertise a successful audio run until CODEX-PC's source-host receipt confirms it.