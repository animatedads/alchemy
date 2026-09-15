# ooRexx Lazy Read File v0.1-dev1

`LazyReadFile` is a small, read-only local-file object intended for multi-gigabyte files. It gives stream-like cursor operations while retaining at most one aligned block of source data.

## Why it exists

A normal whole-file load is the wrong abstraction for a 5 GiB object. `LazyReadFile` keeps a private ooRexx `.Stream` instance open, obtains its size once, and uses absolute `CHARIN` reads only when a requested byte range is not already in the retained block. Separate `LazyReadFile` objects therefore have independent stream lifetimes even when they address the same pathname.

The class uses `NUMERIC DIGITS 20` on byte-size and byte-offset arithmetic. This is part of the large-file contract: byte positions above the normal 9-digit precision range must not be rounded.

## API

```text
f = .LazyReadFile~new(path [, blockBytes])

f~sizeBytes             snapshot file size at construction
f~blockBytes            configured maximum read size; default 8 MiB
f~position              zero-based cursor
f~tell                   cursor position
f~seek(offset)           absolute zero-based cursor move
f~skip(delta)            relative cursor move
f~rewind                 cursor = 0
f~eof                    cursor >= sizeBytes
f~remaining              bytes from cursor to snapshot EOF

f~loadPartial(offset [, bytes])
                         absolute bounded read; cursor unchanged
f~read([bytes])          bounded cursor read; advances cursor
f~nextBlock              read(blockBytes)
f~byteAt(offset)         one-byte absolute read

f~cachedOffset           start of retained aligned block or -1
f~cachedBytes            retained source bytes
f~blocksLoaded           physical block loads
f~cacheHits              retained-block hits
f~release                drop retained source block
f~close                  release and close stream
```

Offsets are **zero-based**. A read request may not exceed `blockBytes`; this is deliberate protection against an accidental gigabyte-sized return String. Reads at EOF return an empty String, and a read crossing EOF returns only the remaining bytes.

## Memory semantics

The object itself retains at most one aligned source block. `release()` removes its strong reference to that block, making the String eligible for ooRexx garbage collection. It cannot invalidate a String that the caller still holds. A bounded-memory scan therefore processes each returned block and overwrites/drops that caller variable rather than collecting blocks in an Array.

Because `loadPartial()` may begin near the end of one aligned block, a single request can touch two source blocks internally, but only the newest block is retained by the object and the returned String is capped at `blockBytes`.

## Read-only and consistency boundary

The class publishes no write operation. `sizeBytes` is a snapshot taken at construction. It does not lock the underlying file against modification by another process; callers that require immutable evidence should pair it with their own file identity/hash/lifecycle policy.

## 5 GiB qualification

`tests/run.sh` creates a sparse file of exactly `5 GiB + 123 bytes`, writes sentinels beyond 4 GiB, beyond 5 GiB and at EOF, and reads them through `LazyReadFile`. This validates exact large offsets without consuming 5 GiB of disk space.

Set `LAZY_FILE_FULL_SCAN=1` to additionally stream across the full sparse 5 GiB fixture in 8 MiB blocks under `/usr/bin/time -v`.
