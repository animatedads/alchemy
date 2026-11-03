# ooRexx Compress v0.1-dev3

## dev3 — RFC 1950 framing, Adler-32, indexed PNG (Claude (Opus 5.5), 2026-11-03; architecture Tom Dyer)

`src/IndexedPngEncoder.cls` (pure ooRexx, bootstrap-clean): `NativeAdler32`, `Rfc1950Framing~wrapStored`, and `IndexedPngEncoder(palette, scale[, provider])` writing 8-bit indexed PNG (IHDR/PLTE/IDAT/IEND, CRC-32 framed). `foreign/ForeignPngProvider.cls` is the optional accelerated provider (stdlib deflate in `python/oorexx_compress_native.py` via the ooRexx Foreign Runtime; text rows in, base64 out). `tests/run_png.sh` decodes both lanes with an independent stdlib checker and requires identical pixels; it is part of `run_all.sh`. First consumer: SLAM 450 v0.89 (onboard panoramas to a vision model).

# ooRexx Compress v0.1-dev2

Bootstrap-safe compression for ooRexx.

API: `oorexx.compress/0.1`

The default provider is pure ooRexx. It requires no Python, Java, shell compressor, zlib/libzstd, compiler, or Foreign Runtime. dev2 also contains an **optional** Foreign Runtime/libzstd provider; foreign acceleration is never a bootstrap prerequisite.

## Native capabilities

### gzip / DEFLATE

- CRC32;
- gzip framing;
- DEFLATE stored blocks (`BTYPE=00`);
- DEFLATE fixed-Huffman blocks (`BTYPE=01`);
- bounded 32 KiB LZ77 matching;
- gzip FHCRC and CRC32/ISIZE validation.

Dynamic-Huffman DEFLATE (`BTYPE=10`) is not yet implemented natively and fails explicitly.

### Zstandard

The pure ooRexx encoder intentionally remains a small bootstrap encoder: it emits standards-conformant Raw/RLE blocks and can therefore represent arbitrary byte strings without requiring Foreign Runtime.

The pure ooRexx decoder is broader. Within the native 8 MiB window policy and without an external dictionary it implements:

- standard and skippable frames, including concatenated frame streams;
- variable frame headers, optional/unknown Frame_Content_Size, Window_Descriptor and Single_Segment framing;
- Raw_Block, RLE_Block and Compressed_Block;
- Raw, RLE, Huffman-compressed and Treeless literals;
- direct and FSE-compressed Huffman weight descriptions;
- one-stream and four-stream Huffman literal payloads;
- predefined, RLE, FSE-compressed and Repeat_Mode sequence tables;
- literals-length, match-length and offset codes;
- repeat-offset/history execution across compressed blocks;
- 128 KiB Block_Maximum_Size enforcement;
- optional content checksum using native XXH64, seed 0, low 32 bits little-endian;
- standards-required reserved-bit/type rejection while ignoring the frame-header unused bit.

Non-zero dictionaries are an explicit capability boundary. The native decoder also deliberately refuses windows larger than 8 MiB as a local resource policy.

## Optional foreign provider

`foreign/ForeignCompressProvider.cls` uses libzstd through ooRexx Foreign Runtime. It provides accelerated general Zstandard compression/decompression while retaining the same `Compress` facade. Qualification proves native -> foreign, foreign -> foreign, foreign -> reference-tool, and reference-tool -> native interoperability.

The provider deliberately does not hide target compatibility. `libzstd.bridge.json` expects the package transaction to stage a compatible/rebuilt `libzstd.so.1` beside the bridge before activation.

## Bootstrap rule

Every capability required to install the bootstrap package set remains available in pure ooRexx. Package integrity remains SHA-256-authoritative; Zstandard's optional XXH64 frame checksum is additional transport-corruption detection.
