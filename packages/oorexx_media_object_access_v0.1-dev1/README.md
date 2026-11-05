# ooRexx Media Object Access — v0.1-dev2 edit-list qualification candidate

The source remains in the `oorexx_media_object_access_v0.1-dev1` package
directory while PR #138 is in qualification. This is a structured ooRexx media
file interface, **not an FFmpeg wrapper**. Codec providers remain replaceable.

## Current implementation

- `MediaFile`, `MediaMp4File`, `Mp4Atom`, `MediaMp4Track`: bounded box
  inspection and track metadata. Seek past a 1 GiB `mdat` to find a tail `moov`
  without decoding or reading compressed payload.
- `MediaByteSource`, `MediaLazyReadSource`, `MediaStorageRangeSource`:
  zero-based, bounded absolute reads adapting existing LazyReadFile and
  Storage Fabric streaming APIs.
- `MediaMp4SampleTable`: metadata-only `stsd`, `stts`, signed/unsigned
  `ctts`, `stsc`, `stsz`, `stco`/`co64`, `stss`; sample byte offsets,
  sizes, DTS, PTS and durations in integer track ticks. Presentation lookup
  is stable-sorted independently of decode order.
- `MediaMp4Track~mapSamples` returns an in-memory map and
  `MediaMp4Track~planTime(ticks)` returns an **unverified decoder seek
  candidate**. `rangesForPlan` creates a bounded, coalesced list of
  physical sample byte spans rather than expanding across interleaved audio
  or unrelated media.
- `MediaRangeCacheSource`: optional fixed-budget read-through LRU over
  any MediaByteSource, with source identity and size fencing. No automatic
  sequential prefetch; repeated in-cache hot jumps do not re-fetch bytes.
- `MediaSeekIndex`: separate integer-tick binary-search primitive for
  prevalidated random access points.

## Deliberately NOT qualified

There is **no claim of exact frame seeking**. `MediaMp4Track~seekTime`
still rejects execution. An MP4 `stss` sync marker is a **candidate**:
codec reference chains (H.264/H.265 open GOP, B-frame dependencies), decoder
priming, and presentation frame delivery need codec-provider qualification.

Current limitations also include: complex movie edit-list `elst` timeline
transforms (fail closed), fragmented MP4 `moof`/`trun` and growing
recordings (fail closed), `stz2`, dependency/roll groups, CENC, external
references, persisted sidecar index loading, source generation recovery and
audio/video multi-track timeline synchronization. `stsz` sample count is
bounded at 2 million for the in-memory working index; no arbitrary stream
size is silently accepted.

`MediaStorageRangeSource` inherits the transport and source-identity
strength of its Storage Fabric provider. The existing `LazyReadFile`
identity is **path and size**, which is not strong enough alone to qualify
a persistent cross-node media index. Storage Fabric authoritative immutable
versions/content identities must be used for distributed evidence.

## Tests

Run from the package `tests/` directory under ooRexx 5.3:

```sh
rexx test_sparse_mp4.rex
rexx test_seek_index.rex
rexx test_mp4_sample_table.rex
rexx test_mp4_co64.rex
rexx test_mp4_elst.rex
rexx test_mp4_track_elst.rex
rexx test_media_cache_1gb.rex
```

The first two dev1 tests were reported **PASS on a local ooRexx 5.3
runtime** after fixing trailing `::requires` directives; that correction
is now committed. The dev2 tests and revised edit-list code require **fresh native qualification**
in the author's environment, which has no `rexx` executable. Rasen Falcon
test request REQ-00003273 asks CODEX-PC for read-only native qualification.

The synthetic 1 GiB fixtures model enormous source sizes with virtual
byte sources, not 1 GiB of allocated memory. They test metadata byte
traffic and bounds, not actual compressed decoding or remote link latency.

See `docs/DESIGN.md` for boundaries and full acceptance matrix.

## 5 November real-recording review and new edit support

Claude (Opus 5.5) independently reported that 4/5 native ooRexx dev2 tests
passed on ooRexx 5.3.0 r13196; the cache test failed on an omitted
superclass `::requires`. That dependency has now been fixed and Claude
reports the retest PASS (16,384 bytes from a synthetic 1 GiB source).

On real camera TP08, the reviewer compared 63,524 A-law packets against
FFprobe and found exact `byteOffset`/`sizeBytes` correspondence; the
constant 8,010 ticks at 90 kHz difference came from `elst`. This dev2
increment now handles `elst` v0/v1, a leading empty segment, and one or
more nonoverlapping unity-rate media segments with integer-expressible
track timestamps. It modifies movie presentation PTS, not media DTS or
sample byte address. Repeated/overlapping edits, nonunity playback speed,
and fractional track-tick boundaries remain explicitly unsupported.

`tests/test_mp4_elst.rex` covers +89 ms, trimmed media start and signed64
empty edit on a synthetic logical 1 GiB MP4. The new implementation has
**not yet been qualified against the resident TP08**; the review predates
these changes. Run the seven-test runner and then verify on the actual file.

A real 256 MiB camera MP4 reported 1,753,168 bytes of metadata reads to
construct the index, with approximately 22 seconds of ooRexx CPU time.
Persisting a source-version-fenced sample index remains essential for true
repeated hot jumps.

`tests/test_mp4_track_elst.rex` exercises the full native MP4 class route from
`moov/mvhd` through `trak/edts/elst` to a 1 GiB sparse sample mapping with
an unchanged byte address, rather than calling the table parser directly.
