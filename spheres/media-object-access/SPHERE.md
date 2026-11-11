# Media Object Access — source-controlled Gopher sphere

Sphere ID: `oorexx.media.object.access/0.1`  
Rasen Falcon component: `media-object-access`  
Active component owner: CHATGPT (verified 2026-11-11)  
Status: implementation + qualification sphere; **not registered/confirmed in Rasen Falcon Gopher sphere catalogue**  
Updated: 2026-11-11

## Object architecture

```text
ooRexx MediaFile / MediaMp4File / MediaTsFile / MediaPngFile / MediaJpegFile
    |           provenance / SourceIdentity / clock / track / edits
    +-- metadata indexes, sparse reads, persisted sidecar, seek planning
    |           |
    |           +-- Storage Fabric resident ByteSource and byte-range cache
    |           |       no implicit full-object transfer or silent source mutation
    |           +-- per-format compressed access units with exact PTS / DTS
    +-- native codec-only Foreign Runtime providers (H264, PNG, JPEG)
                    decoder bytes -> typed RGB/RGBA samples
    +-- ooRexx raster, alignment, temporal evidence and SLAM consumers
```

Application intent and media ownership remain in ooRexx. Container inspection,
source-identity validation, track selection, edit lists, random-access windows,
caching and timestamp correctness must not move into a CLI or a libavformat
wrapper. Native providers may decompress compressed access units and convert
pixel formats only. Vision v5/v5c is a distinct codec and is not replaced.

## Source and qualification

Canonical working source: `packages/oorexx_media_object_access_v0.1-dev1/`.
Draft GitHub PR: #138, branch `feature/media-object-access-dev1`;
the development directory name retains dev1 although dev4–dev8 additions exist.

Native ooRexx 5.3.0 r13196 evidence recorded in GitHub
`docs/NATIVE_QUALIFICATION_2026-11-08.md` and later dev4–dev8 notes:

- Synthetic 1 GiB MP4 top-level tail `moov`: 32 metadata bytes read;
  ordinary 32/64-bit flat sample offsets and a bounded LRU cache.
- Three real Sydney `*.mkv`-named uploads were **188-byte MPEG-TS**, not
  Matroska. MPEG-TS source identity + persisted seek sidecar tested;
  9 reverse H264 hot seeks returned RGB24 pixels at exact 90 kHz requested
  timestamps, within a 1 MiB compressed-byte cap per request.
- Two actual 1080p H264/avc1 MP4 clips, six decoded seeks (5/30/60 seconds
  each) passed through a dedicated independent AVC access mapper; about
  515–523 KiB compressed bytes per seek.
- RGBA PNG, pixel-channel split, adaptive temporal masking, and
  similarity/heldout landmark registration were separately qualified on
  the supplied images within stated gates. No star identity, position
  solution or universal camera calibration is promoted from those tests.

**As of 2026-11-11, the production route**
`MediaFile~openMp4 -> MediaMp4Track~mapSamples ->
MediaMp4H264Frames~frameAt -> MediaH264Decoder`
**is not yet independently native-qualified against these two MP4 files.**

## Current implementation increment and gates

Source closure was repaired: `Mp4BoxReader.cls` now supplies one neutral bounded
box reader directly imported by `Mp4EditList.cls` and `Mp4SampleTable.cls`;
`Mp4File.cls` directly imports the canonical sample table. This breaks
the prior mutual visibility/require problem found by CODEX-PC
(REQ-00003341, REQ-00003343; 5 PASS / 2 FAIL at a historical commit).

`MediaMp4AvcConfig.cls` parses structured `avc1` sample entries and bounded
`avcC` metadata instead of string-scanning arbitrary `stsd` bytes.
`MediaMp4H264Frames.cls` now checks source identity/size across bounded
reads, rejects changed sample descriptions, hidden edit-preroll and
nonexact 90 kHz PTS conversion, and fails explicitly on bounded seek
exhaustion. No blanket MP4/HEVC/open-GOP equivalence is implied.

Tests: `run_tests.sh` includes `test_mp4_avcc_config.rex` in the base set.
Optional `MEDIA_MP4_REAL_1` / `MEDIA_MP4_REAL_2` enables
`test_mp4_production_h264.rex`, which compares frame PTS, dimensions
and complete RGB24 bytes against the independently tested direct AVC
mapper on the *same resident original*; output is only local numeric
qualification evidence. **These new tests remain pending native
execution.**

## Storage, privacy and source-of-truth requirements

1. Original media stays resident on the authorized Storage Fabric MU.
2. Every remotely reused index is bound to an authoritative immutable
   content/generation identity, size, track and index schema; local
   path-plus-size is not a cross-node version guarantee.
3. Source/metadata reads and physical transport bytes must be measured
   separately; a logical read count alone does not prove remote transfer.
4. Decoder preroll and B-frame frame selection must be checked against
   actual returned presentation PTS and pixels; sync flags alone are
   candidate anchors, not proof of an exact decoded frame.
5. No private original recordings, RGB pixel bodies, PCM, sample hashes
   or personally identifying media details go to public GitHub.
6. This sphere is versioned documentation, **not evidence of remote
   Rasen Falcon sphere registration**. The 2026-11-11 resolver returned
   UNKNOWN_SPHERE both for media-object-access and for known existing
   GitHub sphere names. Registry reconciliation is a separate service gate.

## Adjacent responsibility boundaries

- `spash-challenger` owns Ogg direct-seek native provider and audio
  integrity; media-object-access owns common media-file semantics.
- `storage_fabric` owns physical placement, XTP/transport, leases and
  immutable source versions.
- Moonsault/SLAM may consume timestamped image evidence, but may not
  promote cloud/image-change masks to star identities or geodetic locks
  without held-out calibrated evidence.
- Changes remain isolated to draft PR #138 until native, end-to-end
  production tests pass; do not merge or deploy by implication.
