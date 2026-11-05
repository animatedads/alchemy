# ooRexx Media Object Access v0.1-dev1 (initial source increment)

This is a media-file model, **not an FFmpeg wrapper**. Native decoders (FFmpeg or
others) are optional providers. The public surface is ooRexx objects and exact,
immutable-source, zero-based byte access.

Included:

* `MediaByteSource`, `MediaLazyReadSource` (existing LazyReadFile adapter),
  `MediaStorageRangeSource` (existing Storage Fabric ranged stream adapter).
* `MediaFile`, `MediaMp4File`, `Mp4Atom`, `MediaMp4Track` for bounded MP4 atom
  discovery and basic track metadata (including `moov` after 1 GiB `mdat`).
* `MediaAccessPoint`, `MediaSeekIndex`: integer-tick binary search over
  explicitly validated random-access points.
* Synthetic sparse-1-GiB fixture; no 1-GiB payload allocation or sequential
  mdat scan.

**Unqualified / not yet implemented:** `stts`, `ctts`, `stsc`, `stsz`,
`stco`/`co64`, `stss`, `elst` and fragmented `moof`/`trun` sample mapping,
codec decoder priming, persistence/loading of sidecar indexes, VFR decode and
exact-frame seek. `MediaMp4Track~seekTime` deliberately fails closed until
these are implemented and qualified. The sparse fixture demonstrates
metadata-only access, not production hot-seek performance.

The repo environment used for this initial increment has no `rexx` interpreter;
therefore `tests/*.rex` are source tests awaiting execution on the approved
ooRexx 5.3 runtime. No PASS claim is made for those tests.

See `docs/DESIGN.md` for interface boundaries and acceptance tests.
