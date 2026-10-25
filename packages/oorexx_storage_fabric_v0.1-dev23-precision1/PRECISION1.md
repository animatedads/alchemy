# Storage Fabric v0.1-dev23-precision1

**Architecture:** Tom Dyer. **Coding:** ChatGPT and Codex (Storage Fabric to dev23 and the dev22 backup-floor line); Claude (Opus 5.5) for this port. **Written by:** Claude (Opus 5.5), 25 October 2026.

This is dev23 plus the large-file precision fixes from the dev22 backup-floor line (`oorexx_storage_fabric_v0.1-dev22(1)`). dev23 had dropped them, so the 2,005,735,208-byte bodycam AVI failure would have recurred. It is a hotfix candidate on dev23, deliberately not called dev24: the Library holds a different "dev24", and the reconciled next number is the architect's choice.

## What changed

| Change | Where | Why |
| --- | --- | --- |
| `::options digits 30` | every file in `src/` (20) | ooRexx's default 9 significant digits rounds any size or offset above 999,999,999. dev22(1) raised precision in 3 files; dev23 also does byte arithmetic in ranged fetch, peer transfer, FUSE, Git, Google Drive and media classes. No true divisions exist in these files, so nothing else changes. |
| `StorageCodec` `isCanonicalUnsigned`, `unsignedText`, `parseUnsigned` | `src/StorageFabric.cls` | Durable integers are written as plain decimal digits, never `2.18E+9`. Ported from dev22(1); `unsignedText` no longer uses `+0` coercion. |
| Checkpoint canonical integers | `src/StorageStreaming.cls` | Every numeric field of `STORAGE-XFER-CKPT-1`, including the Adler-32 trailer, is canonical. A legacy or exponent-form field fails closed and the transfer restarts from trusted byte 0. |
| `readChunk` is "at most" | `src/StorageStreaming.cls` | A positive short read is legal; only zero progress before the fenced size is an error (`premature source EOF`, or `source file changed during transfer`). |
| No `+0` coercion in the two touched methods | `openAt`, `readChunk` | House rule (fop E10). dev23 has 161 lines using `+0` in `src/`; this candidate removes 6 and leaves 155, all predating it. |
| `tests/test_large_file_precision.rex` | ported from dev22(1) | Sparse 2,005,735,208-byte file: exact tail read, exact transfer counters, canonical checkpoint, exponent checkpoint rejected. The backup-floor-only `StorageHostEntry` check is omitted. |
| `tests/run_precision.sh` | new | The gate: the precision test, the streaming checkpoint test and the streaming transfer test. |

## Not merged from dev22(1)

The backup-floor line's SSH/SFTP backend (`StorageSftp.cls`), host filesystem backup floor (`StorageHostFilesystem.cls`), and its FUSE handle operations (resize, release, truncate). They are features, not precision fixes.

## Validation status

LOCAL_PASS on ooRexx 5.3.0 r13196 (the Library .deb, SHA-256 8add57fd…), Linux x86_64, 25 October 2026. Run by Claude (Opus 5.5). FIELD_PASS is not claimed.

| Run | dev23 | precision1 |
| --- | --- | --- |
| `tests/test_large_file_precision.rex` (2,005,735,208-byte sparse file) | FAIL at the first check: the source identity records a rounded size | PASS |
| `tests/run_precision.sh` (precision, checkpoint, streaming transfer) | n/a | PASS, 3 of 3 |
| `tests/run.sh`, the dev23 core suite | 49 PASS, 0 FAIL | 50 PASS, 0 FAIL (the same 49 plus the precision test) |
| `tests/run_parallel_fetch_pressure.sh` (dev23's autobuild test) | PASS | PASS |

The only other difference between the two `run.sh` logs is the POSIX disk probe. dev23 printed the device size rounded, as `3.12937431E+10`; precision1 printed it exactly, as `31293706240`.

`integration.json` now points `SERVICE_DESCRIPTOR_ROOT` at the copy vendored inside `packages/ssh_over_xtp_v0.1-candidate4/vendor/`. dev23 pointed at `packages/oorexx_service_descriptors_v0.1-dev2`, which does not exist, so its autobuild test could not run. Publishing Service Descriptors dev2 as its own package remains open (ChatGPT answer H12).

Gate command:

```
REXX_BIN=/usr/local/bin/rexx bash tests/run_precision.sh
```
