# File-object media semantics and 1 GiB remote seek contract

## Boundaries

- **ooRexx `MediaFile` owns** file identity, box/sample metadata, tracks,
  timestamps, sample dependency mapping, cursors, seek planning and evidence.
- **Storage Fabric owns** verified storage identity, replica selection,
  source placement, leases, ranged transfer, privacy and security transport.
  Accept an existing `StorageByteSource` or run a bounded local job at the
  storage node; do not build media-specific remote file-copy protocols.
- **Decoder providers own** compressed-sample decoding only (native FFmpeg
  where useful); no provider owns public media seek semantics.
- **Vision/v5v stays unchanged**, receiving selected frames/PTS from the
  common media provider. FC/FD Camera Behaviour may adopt the same boundary.
- `.cls` is the ooRexx class front end, **not the index file format**.

## Implemented dev2 metadata path (unqualified until native tests run)

The ooRexx `Mp4SampleTable.cls` metadata parser currently supports `stsd`,
`stts`, `ctts` (including signed v1 offsets), `stsc`, `stsz`,
`stco`/`co64`, and `stss` for non-fragmented, no-edit-list files.
`MediaMp4Track~planTime(ticks)` produces a candidate target sample
and preceding sync-sample anchor. It does **not** execute `seekTime`.

`MediaMp4SampleTable~rangesForPlan(plan,budget,maxSamples)` returns
coalesced, bounded byte spans of compressed samples from the nominal
anchor to the target, preserving gaps between tracks. Codec dependency
and decoder priming may require more packets than this initial candidate
window; providers must qualify and request further bounded extents.
No file-to-EOF prefetch is authorized. The `MediaRangeCacheSource` has
a fixed LRU block budget, no read-ahead and explicit source-id fencing.

The reported dev1 native ooRexx result is 32 bytes of **synthetic**
MP4 tail-metadata reads on a logical 1 GiB source, not a physical
Storage Fabric network measurement. The new dev2 fixtures are pending
native ooRexx qualification, with no decoder runtime acceptance yet.

**Operational limitation:** `MediaLazyReadSource` currently inherits
a weak local path-plus-size identity from `LazyReadFile`. A durable
cross-node sample index needs a stronger immutable generation/content
identity from the authoritative Storage Fabric provider. Logical
`readAt` counters alone do not prove physical remote I/O volume if
the underlying provider silently materializes the whole object.
Instrumentation must measure actual source-node read bytes and XTP
bytes, as distinct from logical media-request bytes.

## MP4 table roadmap

* ISO BMFF atom graph, including extended sizes, moov at head/tail,
  fragmented moof/mdat/sidx/tfra, 64-bit offsets and bounded sparse reads.
* Sample table: stsd, stts, ctts (signed version 1), stsc, stsz/stz2,
  stco/co64, stss, sdtp, roll and recovery groups; edit lists (elst).
* Persistent sidecar keyed by immutable Storage Fabric content/version ID,
  size, metadata digest, parser/index schema revision and track inventory.
  Chunk/shard index and persist atomically on resident node; invalidate on
  mutation, mismatch, or newly discovered segment. Do not use device/inode
  as cross-node proof of identity.
* Seek by **track timescale integers**; map requested presentation PTS through
  edit timeline to sample, choose a verified random-access decode point,
  load only the required source extents (plus dependency/preroll), decode and
  discard until requested presentation frame. Keep B-frame PTS distinct from
  DTS and retain 90kHz timestamps accurately; never infer PTS from frame count.
* VBR/VFR: obtain exact sample byte size and media-time duration from tables;
  bitrate and nominal fps must never determine file location.
* Several audio/video/subtitle tracks and multiple sample descriptions; each
  has an independent clock, index and decoder. Synchronize at the media-file
  presentation timeline rather than by assuming frame ordinal equivalence.

## Storage traffic policies

1. Open source via metadata/verified identity, not bytes. `moov` may be at
   the end: use top-level atom sizes to jump past `mdat` without reading it.
2. Scan at source node and publish **compact index**; locate relevant bytes
   by index. Keep only a bounded, reusable cache of keyframe/GOP extents.
3. Prefer compute-near-data. If processing must run elsewhere, request
   authorized byte ranges with budget, coalescing, backpressure and verified
   source identity. No unbounded sequential reads or automatic full remux.
4. For a 1 GiB source, an isolated hot jump must transfer only compact
   metadata and selected GOP (not the full recording); repeat jump to the
   same GOP should be a cache hit. Measure actual bytes, requests and latency.
5. Distinguish `KEYFRAME`, `EXACT` (decode forward after priming) and
   `WINDOW` (bounded interval) seek modes. If exact seek cannot be established,
   return `NOT_INDEXED` / `UNSUPPORTED` rather than misleading time offsets.

## Acceptance matrix

- Flat MP4 with moov-first and moov-last; `mdat` >1 GiB using sparse fixture.
- Faststart, non-faststart, 32/64-bit box/chunk offsets, fMP4 and growing
  camera recordings; corrupt/truncated atom sizes fail closed.
- H.264 and H.265 B-frame reorder; AVC/HEVC keyframe dependencies, open-GOP,
  VBR audio and VFR timestamp irregularity, timescale 90000, negative CTTS,
  edit lists and multiple audio streams.
- Seek to beginning, frame midpoint, timestamp near EOF, unknown timestamp,
  and repeated random hops. No linear `av_read_frame` search from zero.
- Check resident-node identity, source mutation fences, stale index rejection,
  access authorization, failed ranged reads and resumable bounded cache.
- Quantify byte traffic: index pass, first jump, repeated jump, 100 random
  jumps. A 1 GiB file must not be shipped as a prerequisite for inspection.

## Implementation caution

`MediaSeekIndex~atOrBefore` is a binary-search primitive over **already
validated presentation-ordered access points**, not a complete codec seek
algorithm. For open GOP or multi-reference streams, producing and accepting
those points is part of the codec dependency qualification; do not equate
`stss` membership blindly with arbitrary exact decoding eligibility.
