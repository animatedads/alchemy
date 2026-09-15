# Foreign Runtime schema / provider model v0.22.6


## ABI-native scalar names

Metadata may use fixed-width types (`i8/u8/i16/u16/i32/u32/i64/u64`) or host C ABI names. v0.22.6 resolves the latter from the runtime build ABI: `short`, `unsigned short`, `int`, `unsigned int`, `long`, `unsigned long`, `long long`, `unsigned long long`, `size_t`, `ptrdiff_t`, and on POSIX `ssize_t` / `socklen_t`. Introspection reports the resolved size, alignment, signedness and carrier. Plain `char` remains deliberately unspecified because C leaves its signedness implementation-defined; use `i8`, `u8`, `signed char`, or `unsigned char` when byte signedness matters.

Host-native scalar resolution does not make struct layouts portable. A struct containing `long`, `size_t`, or `socklen_t` still needs ABI-qualified size/offset/alignment metadata under `abiProfile` / `abiProfiles`.

The native JSON schema remains compatible with v0.17.2. Python buffer import is provider plumbing rather than JSON syntax.

## Bidirectional host buffer contract

Foreign Runtime owns two storage classes behind `.ForeignBuffer`:

1. runtime-owned storage allocated by `.foreign~buffer(size)`;
2. borrowed external contiguous storage registered by a provider.

Both share the same public ForeignBuffer token, size/read/hex/u32 operations and call pinning. Imported storage additionally records readonly state, provider token and release callback.

The provider ABI is:

```text
export acquire(id) -> address, extent, readonly, opaque pin
export release(pin)
import(address, extent, readonly, provider-token, provider-release) -> ForeignBuffer id
```

Python uses `PyObject_GetBuffer(..., PyBUF_CONTIG_RO)` for import and `PyBuffer_Release()` from the provider release callback under the GIL.

A readonly imported buffer is incompatible with an argument whose schema direction is `out` or `inout`. `in` pointer use remains legal.

Not schema-defined in v0.18: dtype, shape, strides, DLPack device descriptors, or non-host address spaces.

## v0.20 Python tensor / DLPack model

Tensor semantics are provider objects rather than native-library JSON schema entries in v0.19. A Python object implementing `__dlpack__` may be retained as `.ForeignTensor`. DLPack capsules are consumed entirely within the Python provider by `ForeignTensor~toDLPack(targetModule[, targetFunction])`; they are never represented as ooRexx scalar values.

The exposed tensor metadata is dtype, shape, byte strides where discoverable, DLPack device type/id/name, and readonly when the Python buffer protocol can prove it. This is intentionally separate from `.ForeignBuffer`, which remains a byte-storage abstraction.


## v0.20 tensor provider ABI
Tensor descriptors are provider/runtime objects rather than JSON library function declarations. Normal native metadata may pass a tensor's opaque numeric `nativeHandle` to a cooperating provider. The cooperating provider obtains the actual descriptor through `rexx_foreign_tensor_export_acquire_v1` and must release the returned pin with `rexx_foreign_tensor_export_release_v1`.

## Tensor descriptor ABI v2

v2 is additive to the frozen tensor descriptor ABI v1. It carries the v1 data/type/layout/device fields plus an execution context:

- `execution_provider`: provider identity string (for example `synthetic.cuda` or a future CUDA/ROCm provider);
- `stream_handle`: opaque provider-owned stream/queue handle;
- `fence_handle`: opaque provider-owned completion/fence/event handle;
- `sync_policy`: `0` synchronous/none, `1` stream-ordered, `2` explicit-fence;
- `affinity_kind`: `0` none, `1` thread, `2` context.

These values describe coordination requirements; they do not grant permission to dereference `data`. Consumers must inspect `device_type` and provider policy. A generic CPU consumer must reject non-CPU device tensors.


## v0.22.3 managed struct pointer fields

A metadata field whose `type` is `pointer` may be assigned a managed Foreign Runtime resource. The struct records that relationship in addition to writing the current ABI pointer value. Supported children in v0.22.3 are ForeignBuffer, ForeignObject, ForeignStruct, ForeignPointerArray, ForeignStructArray, and `.nil`. Managed Struct-to-Struct cycles are rejected. When a struct is passed to native code, the full reachable managed-resource graph is pinned transitively for that call.

`ForeignBuffer~putBytes(offset,data)` and `getBytes(offset,size)` use zero-based offsets, exact byte lengths, bounds checking, and preserve embedded NUL bytes. `putBytes` rejects readonly buffers.


## v0.22.5 byte-sized integer datatypes

Metadata may use `i8` and `u8` anywhere a scalar datatype or scalar struct field is accepted. `i8` is a signed one-byte integer with range -128..127; `u8` is an unsigned one-byte integer with range 0..255. `ForeignStruct` and `ForeignStructArray` read/write exactly one byte at the declared field offset. Out-of-range ooRexx values are rejected rather than truncated.

Example:

```json
{
  "types": {
    "byte_flags": {
      "kind": "struct",
      "size": 2,
      "alignment": 1,
      "fields": [
        {"name": "signed_flag", "type": "i8", "offset": 0},
        {"name": "unsigned_flag", "type": "u8", "offset": 1}
      ]
    }
  }
}
```

## v0.22.5 ABI-qualified bridge profiles

Foreign Runtime distinguishes portable semantic metadata from ABI-qualified layout/constant metadata. The runtime reports an ABI identity such as `linux-x86_64-le-lp64`. A bridge can require one exact profile with `"abiProfile":"linux-x86_64-le-lp64"`, or provide an `abiProfiles` object keyed by ABI identity. When `abiProfiles` is present, the matching section's `types` and `constants` are overlaid on the root metadata; profile values win. A missing/mismatched profile fails before the target shared library is opened.

v0.22.5 contains qualification evidence for **only** `linux-x86_64-le-lp64`. An AArch64 or other ABI profile must be separately implemented/qualified and added to the runtime's qualified-profile catalogue; Foreign Runtime does not infer that Unix structure layouts/constants are interchangeable.
