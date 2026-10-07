# Native memory-block connector

`memory_block_connector.cpp` is the host/guest native fast path for `memory.fabric.block/0.1`.
It maps a page-backed MU container with `MAP_SHARED`, optionally applies Linux `MADV_HUGEPAGE`, and performs bounded native block read/write/copy/zero operations.

The mapping/copy ABI is intentionally below Memory Fabric semantics. A QEMU integration can expose the same MU container to an MI (for example through a shared-memory BAR / DMA-capable device) and replace the copy engine without changing `MemoryBlockBag` or its block handles. This generic build does **not** claim that `memcpy()` itself is DMA.

Build:

    make OOREXX_INCLUDE=/usr/local/include

For the supplied ooRexx package, point `OOREXX_INCLUDE` at its extracted `usr/local/include` directory.
