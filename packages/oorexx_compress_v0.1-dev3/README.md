# ooRexx Compress v0.1-dev3

Bootstrap-safe compression for ooRexx.

API: `oorexx.compress/0.1`

The default provider is pure ooRexx. It requires no Python, Java, shell
compressor, system compression library, compiler, or Foreign Runtime. dev3 also
contains an **optional** Foreign Runtime/libzstd provider; foreign acceleration
is never a bootstrap prerequisite.

## Native capabilities

### gzip / DEFLATE

- CRC32;
- gzip framing;
- DEFLATE stored blocks (`BTYPE=00`) encode/decode;
- DEFLATE fixed-Huffman blocks (`BTYPE=01`) encode/decode;
- DEFLATE dynamic-Huffman blocks (`BTYPE=10`) decode;
- RFC 1951 code-length alphabet and repeat rules;
- canonical literal/length and distance tree reconstruction;
- empty unused distance alphabet for literal-only dynamic blocks;
- bounded 32 KiB LZ77 matching in the native fixed encoder;
- overlapping history-copy semantics in all compressed decoders;
- gzip FHCRC and CRC32/ISIZE validation.

The bootstrap encoder deliberately stays Stored/Fixed. Dynamic-Huffman encoding
is not required to reconstruct the platform and is not claimed. `inflate()` also
has no preset-history API. See `DEFLATE_CONFORMANCE.md` for the exact native
boundary.

### Zstandard

The pure ooRexx encoder intentionally remains a small bootstrap encoder: it
emits standards-conformant Raw/RLE blocks and can therefore represent arbitrary
byte strings without requiring Foreign Runtime.

The pure ooRexx decoder is broader. Within the native 8 MiB window policy and
without an external dictionary it implements:

- standard and skippable frames, including concatenated frame streams;
- variable frame headers, optional/unknown Frame_Content_Size, Window_Descriptor
  and Single_Segment framing;
- Raw_Block, RLE_Block and Compressed_Block;
- Raw, RLE, Huffman-compressed and Treeless literals;
- direct and FSE-compressed Huffman weight descriptions;
- one-stream and four-stream Huffman literal payloads;
- predefined, RLE, FSE-compressed and Repeat_Mode sequence tables;
- literals-length, match-length and offset codes;
- repeat-offset/history execution across compressed blocks;
- 128 KiB Block_Maximum_Size enforcement;
- optional content checksum using native XXH64, seed 0, low 32 bits little-endian;
- standards-required reserved-bit/type rejection while ignoring the frame-header
  unused bit.

Non-zero dictionaries are an explicit capability boundary. The native decoder
also deliberately refuses windows larger than 8 MiB as a local resource policy.

## Optional foreign provider

`foreign/ForeignCompressProvider.cls` uses libzstd through ooRexx Foreign
Runtime. It provides accelerated general Zstandard compression/decompression
while retaining the same `Compress` facade. gzip/DEFLATE continue to use the
pure ooRexx reference implementation.

The provider deliberately does not hide target compatibility.
`libzstd.bridge.json` expects the package transaction to stage a compatible or
rebuilt `libzstd.so.1` beside the bridge before activation.

## Bootstrap rule

Every capability required to install the bootstrap package set remains
available in pure ooRexx. Package integrity remains SHA-256-authoritative;
container checksums are additional transport-corruption detection.
