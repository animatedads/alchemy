# Media Object Access dev3 — MPEG-TS and MP4 seek-index extension

Architecture: user. Implementation: ChatGPT GPT-6. Native ooRexx classes, no Python, no FFmpeg subprocess. Status: SOURCE CANDIDATE; no ooRexx 5.3 interpreter in current container.

## Correct content types of Sydney samples

The 3 supplied files named `stream{1,2,3}_20261107T134037Z.mkv` begin with MPEG-TS sync bytes (0x47) at offsets 0, 188 and 376, are exact multiples of 188 bytes, and `ffprobe` independently reports `mpegts` with H.264 video and AAC audio (90000 Hz). Name extension is wrong; `MediaFileProbe` ignores it. In `MediaFileProbe~detect`, ftyp/styp/moov is MP4, 188-byte TS packet sync is MPEG-TS, EBML/Matroska signature is explicitly unsupported until a native reader exists.

## ooRexx-only container indexing

* `MediaTsWire` interprets MPEG-TS 188-byte packet headers, PAT/PMT PSI with CRC-32/MPEG-2, PES PTS/DTS, video PID and Annex B H.264 IDR NALs.
* `MediaTsFile` does a bounded PSI probe on open. It **never scans the whole source implicitly**; `buildIndexLocal(.true,maxBytes)` is an explicit resident-node-only pass with a declared byte budget. IDs from a complete pass are `IDR_CANDIDATES_ONLY`, *not proven decoder random-access points*.
* `exportIndexText` / `loadIndexText` serialize and restore 90 kHz integer PTS/DTS, PES byte offsets, PID and source identity/size. The Storage Fabric owner must persist the sidecar atomically on a data-resident MU and bind it to a verified immutable version identity. Do not use local path/size as proof of identity. On mismatches the load fails closed.
* `planTime` performs binary search in preindexed candidates. `planBoundedRange` caps a source fetch (default 2 MiB, maximum 16 MiB) at the stored PES boundary. `seekTime` refuses decoded-frame exactness until the H.264 Foreign Runtime provider verifies SPS/PPS, IDR, reference dependency, B frames and requested presentation time.
* No real H.264 frames are decoded by this increment. No star/heading claims can be made from unqualified container seeks.

## MP4 must retain stronger features from draft PR #138

The working baseline is branch `feature/media-object-access-dev1` with flat MP4 `stsz/stsc/stts/ctts/stco/co64/stss`, signed edit-list corrections and bounded source-range caching. Existing MP4 `MediaMp4Track~seekTime` must remain a fail-closed codec gate. This dev3 adds `MediaMp4IndexSnapshot`: a compact per-sample source-bound sidecar, including offsets, sizes, media DTS/PTS, edited movie PTS, presentation sorting, and sync candidates. Unlike rebuilding `stsz/stco` on every hot request, a restoring consumer can binary-search presentation ticks and return bounded compressed sample ranges without re-reading the track metadata. The persisted sample map is never equivalent to qualified decoded-frame seeking.

## Remote 1 GiB contract

1. Open with byte-source identity and a few hundred bytes, determine container by signature (not extension).
2. Reuse verified index if available. On a cache miss, create the index **locally at the storage node**, not through a 1 GiB remote scan; publish metadata only.
3. Use integer PTS/DTS, not frame number or nominal frame rate. For MP4, honor `ctts` and `elst`; for MPEG-TS, keep 90 kHz source timestamps and explicit wrap/discontinuity fencing.
4. Jump to nearest admissible decoder anchor and request only a bounded GOP/dependency region. Cache under immutable source identity. Never silently re-download a whole file or replay from zero.
5. Require separate codec-provider approval for `EXACT` frame output, frame reordering, multi-track sync, and decoded frame provenance. If unsupported, error rather than approximate.
6. Verify bytes read, requests, cache reuse and integer-seek correctness at beginning/middle/near EOF on synthetic 1 GiB and real MKV-named TS / MP4 sources.

## Testing status

The new TS index/sidecar test is `tests/test_ts_contract.rex <resident-path>`. It uses a local CHARIN byte source to exercise actual user-supplied MPEG-TS. The MP4 sidecar requires a regression using the source-derived `MediaMp4SampleTable~exportIndexText` and `MediaMp4Track~installIndexText` method. Tests are not PASS until actually run with ooRexx 5.3 (r13196).