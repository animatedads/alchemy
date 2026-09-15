# ooRexx Foreign Runtime v0.22.6


## v0.22.6 ABI-native C scalar aliases

v0.22.6 closes a portability gap exposed by the new ABI-profile model. C implementation types are no longer silently collapsed to fixed widths where the host ABI disagrees. `long`, `unsigned long`, `size_t`, `ssize_t`, `ptrdiff_t`, `short`, `unsigned short`, and POSIX `socklen_t` resolve to the carrier width/alignment of the runtime that built Foreign Runtime; fixed-width code should continue to use `i32`, `u32`, `i64`, `u64`, etc. On the sole qualified ABI-specific profile in this release (`linux-x86_64-le-lp64`), `long`/`unsigned long`/`size_t`/`ssize_t`/`ptrdiff_t` are 64-bit while `socklen_t` is 32-bit.

This distinction is intentional: a function argument typed `size_t` can be host-native and portable, while a struct containing `long` still needs ABI-qualified offsets/size metadata. v0.22.6 advertises capability `abi-native-c-scalars`.

## v0.22.5 exact 8-bit integer support

v0.22.4 added first-class `i8` / `u8` datatypes for metadata-defined scalar arguments/returns and struct/struct-array fields. The qualified libffi path maps them to `ffi_type_sint8` / `ffi_type_uint8`, preserves one-byte storage, and rejects out-of-range values rather than wrapping. This closes the byte-sized ABI gap needed by portable structures such as `MYSQL_BIND` provider metadata. v0.22.5 preserves that support unchanged.

## v0.22.3 managed struct pointer graphs and buffer slices

v0.22.3 supersedes v0.22.2. `ForeignStruct~set()` now accepts managed pointer-field resources (`ForeignBuffer`, `ForeignObject`, `ForeignStruct`, `ForeignPointerArray`, `ForeignStructArray`, or `.nil`) and records the relationship. Passing a parent struct to native code recursively pins the complete reachable managed graph for the duration of the call. Pointer-field cycles are rejected. Struct mutation waits for active native pins to drain. `ForeignBuffer~putBytes(offset,data)` and `getBytes(offset,size)` add exact, zero-based, bounds-checked binary slices with embedded-NUL preservation and readonly enforcement.

## v0.22.2 Python proxy argument marshalling

Resident `.ForeignPythonObject` subclasses, including `.ForeignTensor`, now marshal by Python registry reference rather than falling through to Rexx string conversion. The rule applies to direct positional arguments, nested Rexx arrays, keyword values, and explicit Python dict values. This fixes module-level calls such as Torchaudio receiving `"a FOREIGNTENSOR"` instead of the underlying `PyObject *`.


v0.22.2 supersedes v0.22.0 as the continuation candidate. v0.22.2 is a maintenance release fixing Python proxy/tensor argument marshalling; v0.22 Vulkan behavior is unchanged. It preserves the externally accepted v0.17.2 concurrency repairs, v0.18 bidirectional ForeignBuffer/Python zero-copy semantics, and v0.19 ForeignTensor/DLPack behavior, while adding a provider-neutral native tensor descriptor ABI.

## v0.21 device-aware tensor descriptor v2

The base runtime keeps tensor descriptor ABI v1 frozen and adds v2 execution-context metadata for device-aware consumers: `execution_provider`, opaque `stream_handle`, opaque `fence_handle`, `sync_policy`, and `affinity_kind`. The v2 ABI is additive; existing v1 CPU consumers remain valid.

A consumer must inspect `device_type` before dereferencing `data`. Qualification uses a synthetic CUDA-tagged tensor with stream/fence/context metadata and proves that the generic CPU tensor consumer refuses to dereference it. There is no CUDA runtime on the qualification host, so GPU execution is not claimed. Python non-CPU tensors are not published through the old v1 native descriptor path; native publication is withheld until a v2-capable provider can supply execution context.

## v0.20 provider-neutral native tensor descriptors

`.ForeignTensor` now owns both its resident Python object and a provider-neutral Foreign Runtime tensor handle. The base runtime exports `rexx_foreign_tensor_import_v1`, `rexx_foreign_tensor_export_acquire_v1`, `rexx_foreign_tensor_export_release_v1`, and `rexx_foreign_tensor_close_v1`. A pinned descriptor contains data address, logical byte extent, readonly state, DLPack-compatible dtype code/bits/lanes, shape, byte strides, and device type/id. Shape/stride metadata is copied into the base runtime; provider storage remains provider-owned behind an opaque release callback.

The acceptance consumer is a separate `libtensor_probe.so`, not the Python provider. It receives only `ForeignTensor~nativeHandle`, dynamically acquires the descriptor API, reads and mutates NumPy- and Torch-owned CPU storage, and releases its pin. `.ForeignTensor~close` waits for active native descriptor pins before releasing provider ownership. DLPack capsules remain provider-internal. GPU/device metadata can be represented, but v0.20 qualification is CPU/host memory only.

## ForeignTensor

A resident Python object implementing `__dlpack__` can be retained as a `.ForeignTensor`:

```rexx
arr=np~arange(8,kw)
t=arr~asTensor
say t~dtype
say t~shape[1]
say t~strides[1]
say t~device
```

`.ForeignTensor` retains an independent Python registry reference. Closing the source proxy therefore does not invalidate the tensor view.

Exposed tensor metadata:

- protocol (`dlpack`)
- dtype
- shape
- byte strides where discoverable
- DLPack device type and device id
- normalized device name
- readonly state when the Python buffer protocol can prove it

For PyTorch, element strides are normalized to byte strides using `element_size()`.

## DLPack handoff

DLPack capsules never enter ooRexx. The Python provider performs the producer/consumer handoff internally:

```rexx
torch=t~toDLPack('torch')
```

This calls the target module's `from_dlpack` with the resident source object. A custom function name may be supplied as the second argument.

The qualification test proves NumPy -> Torch zero-copy by mutating the Torch tensor and observing the same bytes through an independently pinned ForeignBuffer derived from the original NumPy allocation. The reverse Torch -> NumPy DLPack handoff is also qualified.

## Inherited memory model

v0.18 bidirectional host-memory sharing remains intact:

- ForeignBuffer -> Python memoryview is zero-copy and pin-aware;
- Python contiguous buffer -> ForeignBuffer is zero-copy and provider-release-aware;
- readonly imports cannot satisfy writable native parameters;
- close waits for active pins;
- Python and native resource lifetimes remain independent but coordinated.

## Threading

The accepted v0.17.2 rules remain authoritative: no concurrent native ObjectToStringValue marshalling, immutable/published native introspection wrappers, resource pinning, and no global invocation lock. Python remains GIL-managed per call.

## Not claimed in v0.21

- direct exposure of DLPack capsules to ooRexx;
- actual CUDA/ROCm/device tensor execution on this qualification host;
- general strided ForeignBuffer import;
- non-Python tensor import providers beyond the generic ABI contract;
- DLPack stream negotiation for asynchronous device transfers.

## v0.22 optional real Vulkan provider
v0.22 adds `examples/libforeign_vulkan.so`, an optional headless Vulkan provider that runtime-loads `libvulkan.so.1` and requires no Vulkan SDK headers at build or run time. The mandatory hardware acceptance target is an Intel non-CPU physical device (vendor 0x8086) and explicitly rejects Vulkan CPU devices such as llvmpipe.

The first hardware operation deliberately uses `vkCmdFillBuffer` rather than a compute shader. It creates a Vulkan instance/device/queue, allocates a storage buffer from HOST_VISIBLE|HOST_COHERENT memory (preferring DEVICE_LOCAL as well), maps it, records a queue command, submits it with a `VkFence`, waits for completion, and publishes the allocation as a Foreign Runtime tensor descriptor v2 with device type Vulkan (7), execution provider `vulkan`, explicit-fence synchronization, and context affinity.

The provider is process-resident after first use so a ForeignTensor release callback cannot point into an unloaded provider module. Vulkan handles remain opaque to ooRexx. This release does not claim a SPIR-V compute shader yet; `u32 *= 2` is the next step once a reproducible shader build path is available.

## ABI profile boundary

v0.22.5 makes ABI qualification executable. `.foreign~runtimeInfo~abiProfile` identifies the actual process ABI, `.foreign~qualifiedAbiProfiles` lists profiles this release is qualified to load as ABI-specific metadata, and `.ForeignLibrary~abiProfile` / `abiQualified` expose the selected bridge profile. The sole qualified ABI-specific profile in this release is `linux-x86_64-le-lp64`; AArch64 and other Unix ABIs are intentionally not claimed.
