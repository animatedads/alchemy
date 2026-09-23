# Foreign Runtime provider boundary

The pure ooRexx provider is permanent bootstrap/reference code, not a temporary substitute.

`foreign/ForeignCompressProvider.cls` is the optional accelerated provider in dev2. It calls `libzstd` through **ooRexx Foreign Runtime v0.22.6-style metadata**, without a bespoke C shim. gzip/DEFLATE and XXH64 continue to delegate to the native provider; Zstandard `AUTO`/`COMPRESSED` uses libzstd, while explicit `RAW`/`RLE` remains available through the native reference implementation.

The provider honours the public `checksum=` contract by using a `ZSTD_CCtx`, setting `ZSTD_c_compressionLevel` and `ZSTD_c_checksumFlag`, and invoking `ZSTD_compress2()`. Decompression uses `ZSTD_decompressBound()` plus an application output limit before allocating a managed `ForeignBuffer`, then `ZSTD_decompress()`.

## Target materialization

`foreign/libzstd.bridge.json` intentionally names `libzstd.so.1` relative to the bridge. A package RUN phase may therefore stage a target-compatible or freshly rebuilt library beside the bridge without hard-coding a host path in the package. Qualification generates a temporary bridge pointing at the host's discovered libzstd.

This dev2 package does **not** claim to contain libzstd source. A preferred packager must satisfy the foreign artifact through a separately verified source/provider package when a target rebuild is required.

Provider selection follows the package transaction rules:

1. PLAN records native and foreign candidates and the foreign artifact requirement.
2. DRY_RUN probes the target library/ABI without changing active state.
3. RUN may stage or rebuild libzstd from verified source, then load/probe it through Foreign Runtime.
4. RUN executes the foreign-provider qualification against the staged library.
5. COMMIT activates only a qualified provider set.

Required invariant: loss or incompatibility of every foreign binary must still leave enough pure ooRexx functionality to unpack and reconstruct Foreign Runtime and the foreign provider itself.
