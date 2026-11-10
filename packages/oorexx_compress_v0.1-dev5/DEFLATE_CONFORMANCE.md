# Native DEFLATE conformance

`NativeCompressProvider` is the Stage-0/reference DEFLATE implementation for
`oorexx.compress/0.1`.

## Native encoding

The bootstrap encoder intentionally emits only:

- Stored blocks (`BTYPE=00`);
- Fixed-Huffman blocks (`BTYPE=01`) with bounded 32 KiB LZ77 matching.

A dynamic-Huffman encoder is not required for bootstrap correctness and is not
claimed by this release.

## Native decoding

The native decoder accepts standalone DEFLATE streams containing:

- Stored blocks (`BTYPE=00`);
- Fixed-Huffman blocks (`BTYPE=01`);
- Dynamic-Huffman blocks (`BTYPE=10`).

Dynamic blocks implement the RFC 1951 code-length alphabet and repeat symbols
16/17/18, canonical Huffman reconstruction, literal/length and distance trees,
length/distance extra bits, overlapping history copies and exact EOB handling.

The decoder rejects:

- reserved block type `BTYPE=11`;
- encoded `HLIT` values representing more than 286 literal/length codes;
- over-subscribed Huffman trees;
- invalid incomplete code-length trees;
- repeat code 16 before a previous code length exists;
- repeat runs which exceed the combined literal/distance length sequence;
- a literal/length alphabet without symbol 256 (EOB);
- reserved literal/length symbols 286/287;
- reserved distance symbols 30/31 when encountered;
- a distance reference when the distance alphabet is empty;
- backward distances outside the already-produced history;
- truncated input and trailing bytes after the standalone stream.

RFC 1951's literal-only corner case is supported: one distance code length of
zero denotes an unused/empty distance alphabet. A one-symbol distance tree uses
one bit, not a zero-bit code.

## Bounded decoding

`inflate(bytes, maxOutputBytes)` enforces a live output ceiling while decoding Stored, Fixed and Dynamic blocks. The guard is applied before appending literals, stored chunks, or LZ77 match copies. This is intended for archive/package callers which have an authoritative declared uncompressed size and must not allocate arbitrary output before discovering a size mismatch.

## Scope boundary

`inflate(bytes, maxOutputBytes=.nil)` has no API for preset history/dictionaries. Therefore this
release claims complete ordinary standalone block decoding, not decoding that
requires caller-supplied preset DEFLATE history.

`gunzip(bytes)` applies the same Stored/Fixed/Dynamic decoder inside one gzip
member and validates FHCRC (when present), CRC32 and ISIZE. Concatenated gzip
members remain an explicit wrapper-level boundary.

## Bootstrap evidence

Required pure-ooRexx qualification contains embedded dynamic-Huffman fixtures;
it does not need `gzip`, a system DEFLATE library, Foreign Runtime, Python or
Java. Optional interoperability qualification additionally checks reference
gzip output.
