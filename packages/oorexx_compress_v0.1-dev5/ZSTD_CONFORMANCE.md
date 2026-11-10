# Zstandard conformance note

Normative format basis:

- RFC 8878, *Zstandard Compression and the 'application/zstd' Media Type*.
- Meta `zstd/doc/zstd_compression_format.md`, format version 0.4.5 (2026-05-14), used as the current implementation cross-reference.
- xxHash XXH64 algorithm specification for content-checksum calculation.

## Implemented native decoding set

The native decoder handles dictionary-free Zstandard frame streams within an explicit 8 MiB maximum Window_Size policy.

Implemented:

- standard and skippable frames;
- concatenation;
- Raw_Block and RLE_Block;
- Compressed_Block;
- Raw_Literals_Block and RLE_Literals_Block;
- Compressed_Literals_Block and Treeless_Literals_Block;
- direct and FSE-compressed Huffman weight descriptions;
- one-stream and four-stream Huffman payloads;
- sequence counts in all three standard encodings;
- Predefined_Mode, RLE_Mode, FSE_Compressed_Mode and Repeat_Mode for LL/OF/ML;
- sequence extra-bit decoding and exact reverse-bitstream exhaustion;
- repeat-offset update semantics and overlapping history copies;
- optional Frame_Content_Size;
- Single_Segment and Window_Descriptor framing;
- Content_Checksum;
- encoded Dictionary_ID zero;
- the frame-header unused bit is not interpreted;
- reserved header/block values fail closed.

Explicitly unsupported natively:

- non-zero / externally supplied dictionaries, including dictionary-provided entropy tables/history;
- windows larger than 8 MiB, by local resource policy rather than format impossibility.

## Encoder profile

The native encoder deliberately emits only standard Raw_Block and RLE_Block data. This is enough to encode arbitrary content while keeping Stage-0 independent of Foreign Runtime. Blocks are limited to 128 KiB. Frames larger than 8 MiB use the 8 MiB Window_Descriptor profile; because Raw/RLE blocks have no history references this does not constrain representable content length.

The native decoder is intentionally more capable than the native encoder so the bootstrap environment can consume ordinary reference-produced Zstandard content without requiring libzstd.

Package SHA-256 remains the package integrity authority; the optional Zstd content checksum is additional transport-corruption detection.

## Qualification scope

Pure ooRexx entropy tests cross-check the full predefined literal-length FSE decoding table against the published Appendix A and cross-check the published Huffman-weight example. Reference-tool qualification decodes frames produced by zstd v1.5.7 across multiple compression levels, checksum modes, frame-content-size modes and concatenation.

This is not a dictionary-support claim. A frame requiring a non-zero dictionary ID is rejected before block execution.

## Foreign provider

The optional Foreign Runtime provider delegates accelerated Zstandard entropy coding/decoding to a target-qualified libzstd. It is an accelerator/interoperability provider, not an excuse to remove the pure ooRexx bootstrap path.
