# API `oorexx.compress/0.1`

`Compress.cls` exports `Compress` and `CompressBuild`.

## Construction

```rexx
codec = .Compress~new
```

The default provider is `NativeCompressProvider`. An alternate provider may be
injected with `.Compress~new(provider)`.

## Methods

- `provider` -> provider name.
- `capabilities` -> array of explicit capability strings.
- `gzip(bytes, mode='FIXED')` -> gzip member. Native encode modes: `FIXED`, `STORED`.
- `gunzip(bytes)` -> validated uncompressed bytes for one gzip member; native
  decoding accepts Stored, Fixed and Dynamic DEFLATE blocks.
- `deflateFixed(bytes)` -> raw fixed-Huffman DEFLATE stream.
- `deflateStored(bytes)` -> raw stored-block DEFLATE stream.
- `inflate(bytes)` -> standalone Stored/Fixed/Dynamic DEFLATE decoding without
  preset history.
- `crc32(bytes)` -> four CRC32 bytes in gzip little-endian order.
- `zstd(bytes, mode='AUTO', checksum=.true)` -> Zstandard frame.
- `unzstd(bytes)` -> Zstandard frame-stream decoding.
- `xxh64(bytes, seed=0)` -> unsigned XXH64 numeric digest.

## Native DEFLATE capability strings

- `compress.deflate.fixed`
- `compress.deflate.stored`
- `decompress.deflate.fixed`
- `decompress.deflate.stored`
- `decompress.deflate.dynamic`
- `compress.gzip.fixed`
- `compress.gzip.stored`
- `decompress.gzip.fixed`
- `decompress.gzip.stored`
- `decompress.gzip.dynamic`

There is intentionally no `compress.deflate.dynamic` capability in dev3.

## Native Zstandard provider

Native `zstd()` modes are `AUTO`, `RAW`, and `RLE`. The bootstrap encoder emits
only Raw/RLE blocks.

Native `unzstd()` accepts dictionary-free standard Zstandard frames within its
8 MiB window policy and implements Raw/RLE/Compressed blocks, Huffman literals,
FSE sequences, table reuse, repeat offsets, concatenated frames, skippable
frames and optional XXH64 content checksums.

Native capability strings include:

- `compress.zstd.raw`
- `compress.zstd.rle`
- `decompress.zstd.raw`
- `decompress.zstd.rle`
- `decompress.zstd.compressed`
- `decompress.zstd.huffman`
- `decompress.zstd.fse`
- `decompress.zstd.repeat-mode`
- `frame.zstd.skippable`
- `checksum.xxh64`
- `bootstrap.no-foreign-runtime`

A non-zero `Dictionary_ID` is rejected explicitly because dictionary material
is not part of this API yet.

## Foreign Runtime/libzstd provider

`foreign/ForeignCompressProvider.cls` is optional and is never required by
`Compress.cls`. Construct it only after Foreign Runtime and a target-qualified
bridge have been staged:

```rexx
provider = .ForeignCompressProvider~new('/staged/libzstd.bridge.json')
codec = .Compress~new(provider)
```

`AUTO`/`COMPRESSED` uses libzstd. Explicit `RAW`/`RLE` delegates to the native
reference provider. The foreign decompressor accepts libzstd-supported frame
streams subject to its configured maximum output bound.
