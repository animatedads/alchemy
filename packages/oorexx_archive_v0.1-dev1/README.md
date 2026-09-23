# ooRexx Archive v0.1-dev1

Pure-ooRexx ZIP container support for the preferred package/bootstrap path.

API: `oorexx.archive/0.1`

The archive layer deliberately separates container semantics from compression.
ZIP Method 8 is delegated to `oorexx-compress` and requires module level 4 so
entry expansion can be bounded by the central-directory uncompressed size.

## Native ZIP reader

The reader:

- finds and validates the End Of Central Directory record;
- parses the central directory before touching payloads;
- treats central-directory sizes/CRC/method as authoritative;
- validates each local header and optional data descriptor against it;
- accepts ZIP32 single-disk archives;
- extracts Stored (method 0) and DEFLATE (method 8) entries;
- verifies exact uncompressed size and CRC32;
- applies a live DEFLATE output ceiling before allocation can exceed the
  declared entry size;
- rejects encrypted entries, ZIP64 sentinels, multi-disk records, unsupported
  methods, overlapping local records, duplicate names and portable path
  collisions;
- rejects Unix symlink and other special-file entries.

## Native ZIP writer

`ZipWriter` produces ordinary ZIP32 archives using:

- method 0 Stored;
- method 8 fixed-Huffman DEFLATE from `oorexx-compress`.

The writer is intentionally small and deterministic enough for bootstrap
packaging. Reading is broader than writing: the reader accepts dynamic-Huffman
method-8 streams through the compression layer.

## Extraction safety

Archive names are checked conservatively across POSIX and Windows semantics:
absolute/drive paths, backslashes, `.`/`..`, empty segments, colons, control
bytes, trailing dot/space segments and Windows device basenames are rejected.
Exact and ASCII-case-fold name collisions are rejected before extraction.

`ZipArchive~extractFresh(root)` requires `root` not to exist, creates it, and
only creates regular files/directories described by the validated archive. This
is appropriate for the packager RUN staging model, where a new private staging
root is created for each transaction.

It is **not** claimed to be descriptor-relative race-proof extraction against a
same-user process actively replacing directories after creation. That stronger
property requires the outstanding POSIX `openat`/no-follow style capability.
See `SECURITY.md`.

## Explicit dev1 boundaries

- no ZIP64;
- no multi-disk ZIP;
- no encryption;
- no symlinks/hardlinks/devices/FIFOs;
- no compression methods other than 0 and 8;
- no descriptor-relative no-follow filesystem publication yet;
- the bootstrap writer does not preserve host executable/permission metadata; package qualification remains argv-first and does not rely on archive executable bits.

These are fail-closed boundaries, not silent fallbacks to `unzip`.
