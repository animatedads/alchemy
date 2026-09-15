# Compatibility

## v0.22.6 ABI-native scalar compatibility

`long`, `unsigned long`, `size_t`, `ssize_t`, `ptrdiff_t`, `short`, `unsigned short`, and POSIX `socklen_t` now mean the corresponding host C ABI type. This corrects the prior generic aliases that treated `long` as fixed `i32` and `size_t` as fixed `u64`. Bridges that require a fixed width must name the fixed-width datatype (`i32`, `u32`, `i64`, `u64`, etc.) rather than a C implementation type.

This is a semantic correction, not an ABI-profile bypass: scalar carrier width can be derived from the compiled host ABI, while any struct offsets/padding containing those types still require independently qualified profile metadata. The sole qualified ABI-specific layout/constant profile remains `linux-x86_64-le-lp64`.


The base package requirement remains `REXX_INTERPRETER_5_0_0` and the ooRexx-facing native boundary is unchanged in principle.

v0.21.0 is source/API compatible with the v0.17.2 public ooRexx surface. New APIs are additive:

- `.ForeignPythonObject~asBuffer`
- `.ForeignBuffer~readonly`
- provider C ABI symbol `rexx_foreign_buffer_import_v1`

The existing v0.17 provider ABI exports remain available unchanged.

Python remains optional. The base Foreign Runtime has no libpython dependency. `libforeign_python.so` is built only when Python embed development support is available and remains tied to a compatible host Python ABI.

Imported Python buffers are limited to contiguous host memory in v0.18. Readonly is preserved. No promise is made that arbitrary strided arrays can be flattened without a copy; such exporters are rejected rather than misrepresented.

All v0.17.2 concurrency rules are inherited, including the elimination of concurrent native ooRexx object-to-string conversion and the explicit native-entry handshakes in resource pinning tests.


v0.20 adds an ABI-only provider surface; existing ooRexx APIs remain additive-compatible. Tensor ABI v1 descriptors are process-local and pointer-bearing. Consumers must acquire/release pins and must honor device_type, readonly, dtype and byte strides. CPU/host access is qualified; a non-CPU descriptor must not be dereferenced by a CPU consumer merely because `data` is non-null.


## v0.21 tensor ABI compatibility
Tensor descriptor ABI v1 is retained unchanged. v0.21 adds `rexx_foreign_tensor_import_v2`, `rexx_foreign_tensor_export_acquire_v2`, and `rexx_foreign_tensor_export_release_v2`. Existing v1 consumers do not need modification. v2-aware consumers must treat stream/fence handles as provider-owned opaque values and must not CPU-dereference non-CPU device pointers.

## v0.22 Vulkan compatibility
The Vulkan provider is optional and additive. Base Foreign Runtime, Python, OpenSSL, FFmpeg and PTY functionality do not depend on Vulkan. The provider uses Vulkan 1.0 core entry points resolved dynamically from `libvulkan.so.1`; no Vulkan SDK development package is required. Tensor ABI v1/v2 remain unchanged.

## v0.22.1 Python proxy compatibility
Python proxy marshalling is corrected without changing the public ooRexx API. `.ForeignPythonObject` and subclasses are now passed back into Python as the resident `PyObject *` represented by their registry handle, rather than by Rexx stringification.


## v0.22.2 Python collection compatibility

Python objects that remain resident proxies no longer require explicit `invoke("__getitem__", ...)` application code. Numeric Rexx bracket indices are one-based; `pythonAt` retains exact Python indexing. Nonnumeric bracket keys pass through unchanged for mappings.


## v0.22.3 managed pointer-field compatibility

Existing scalar/raw pointer struct fields remain accepted. Assigning a managed resource to a pointer field now additionally retains a relationship and participates in transitive call pinning. Closing a managed child before a later parent invocation causes the invocation to fail closed rather than dereference stale storage. Buffer slice methods are additive.

## v0.22.5 8-bit ABI compatibility

`i8` / `u8` are additive datatype names and do not alter existing numeric carriers or metadata. On the qualified x86-64 POSIX runtime-libffi path they use libffi's exact signed/unsigned 8-bit ABI types. Existing v0.22.3 schemas remain valid unchanged. The legacy typed-template fallback continues to fail closed for small-width scalar arguments rather than emulating them through a wider C prototype.

## ABI-specific bridge compatibility

v0.22.5 explicitly qualifies ABI-specific bridge metadata only for Linux x86-64 little-endian LP64 (`linux-x86_64-le-lp64`). Runtime ABI detection may identify other architectures/data models, but `abiQualified` is false and ABI-specific bridges are rejected until that profile has separate qualification evidence and is added to `qualifiedAbiProfiles`.
