# Qualification

Qualified on the supplied ooRexx 5.3.0 r13196 debug build.

## gzip / DEFLATE required native qualification

`tests/test_native.rex` requires no external compressor and verifies:

- CRC32 known vector;
- empty, one-byte, text, all-byte-value and repetitive fixed/stored round trips;
- gzip FHCRC validation;
- active LZ77 path;
- embedded dynamic-Huffman raw-DEFLATE and gzip fixtures;
- the RFC 1951 literal-only dynamic case with an empty distance alphabet;
- over-subscribed Huffman-tree rejection;
- invalid incomplete code-length-tree rejection;
- acceptance of the legal one-symbol one-bit distance tree;
- acceptance of an unused empty distance alphabet;
- rejection of the reserved encoded HLIT range above 286 symbols.

The native-source purity scan forbids process/library delegation in the
bootstrap implementation.

## gzip / DEFLATE optional reference interoperability

`tests/run_interop.sh` verifies:

- native Fixed and Stored gzip output is accepted by standard gzip;
- reference `gzip -9 -n` dynamic-Huffman output decodes byte-for-byte in native
  ooRexx;
- gzip CRC corruption fails closed.

An additional development matrix was run against reference raw DEFLATE produced
at levels 1-9 and several strategies; it covered Stored, Fixed and Dynamic first
blocks and decoded byte-for-byte. The required package qualification does not
depend on that foreign/reference producer.

## Zstandard native

`tests/run_zstd_native.sh` verifies:

- XXH64 empty-input vector `EF46DB3751D8E999`;
- XXH64 `hello` vector `26C7827D889F6DA3`;
- checksummed Raw/RLE round trips;
- Frame_Content_Size boundaries 255/256 and 65791/65792;
- 128 KiB block transition and multi-block input;
- multi-block RLE;
- concatenated data frames;
- skippable and skippable-only streams;
- the frame-header unused bit is ignored;
- reserved frame-header bit and reserved block type are rejected;
- non-zero Dictionary_ID is rejected explicitly;
- content-checksum corruption rejection;
- the complete published Appendix-A predefined literal-length FSE table;
- the format-spec Huffman weights example, including inferred final weight;
- direct Huffman tree-description nibble order;
- source purity scan forbidding process/library delegation in native
  Zstd/XXH64/entropy code.

## Zstandard reference interoperability

`tests/run_zstd_interop.sh` against reference CLI v1.5.7 verifies:

- reference zstd validates and decodes native checksummed Raw frames;
- reference zstd validates and decodes native RLE frames;
- native decoder decodes an incompressible reference-produced frame byte-for-byte;
- native decoder decodes reference Compressed_Block streams produced at levels
  1, 3, 9 and 15;
- reference no-checksum frames decode natively;
- an unknown-size streaming reference frame with Window_Descriptor/no
  Frame_Content_Size decodes natively;
- concatenated reference-produced frames decode as concatenated content.

## Foreign Runtime/libzstd

`tests/run_foreign_zstd.sh` uses Foreign Runtime v0.22.6 and the qualification
host's libzstd. It verifies:

- context-based libzstd compression through Foreign Runtime;
- requested frame checksum is present (`zstd -lv` reports `Check: XXH64`);
- foreign-provider round trip;
- native Raw/checksummed frame -> foreign provider;
- reference `zstd -t` accepts foreign-provider output;
- regression guard against using ooRexx's special `RESULT` variable as the
  returned compressed payload.

The foreign qualification is optional; native bootstrap qualification is
required.
