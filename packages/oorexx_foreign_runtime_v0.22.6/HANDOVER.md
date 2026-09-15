# Foreign Runtime v0.22.6 handover


Authority: v0.22.6 supersedes v0.22.5 as the continuation candidate. v0.17.2 remains the accepted concurrency-repair ancestry.

Current maintenance increment: ABI-native C scalar aliases now resolve from the compiled host ABI instead of assuming `long=i32` and `size_t=u64`. The qualified `linux-x86_64-le-lp64` profile resolves `long`, `unsigned long`, `size_t`, `ssize_t`, and `ptrdiff_t` to 64-bit carriers and `socklen_t` to `u32`. Fixed-width metadata remains unchanged.

Consumer forcing evidence: the complete Unix Socket v0.4 suite passes against v0.22.6 once its stale exact-version assertion (`0.22.3`) is relaxed; the package already documents v0.22.3-or-later compatibility. Maths v0.5 passes its complete PURE/REFERENCE/exact/NumPy/SymPy/mpmath suite against v0.22.6, with only the pre-existing optional python-flint lane skipped.

Inherited v0.22.1 maintenance fix: Python proxy arguments are passed by resident registry reference, including ForeignTensor, kwargs, dict values and nested arrays. No tensor ABI or Vulkan schema change.

Inherited tensor increment: provider-neutral native tensor descriptor ABI layered under the existing Python-backed `.ForeignTensor` / provider-internal DLPack handoff.

Key invariants:

- `ForeignPythonObject~asTensor` requires `__dlpack__` and retains an independent Python registry reference/id.
- `.ForeignTensor` exposes dtype, shape, byte strides, DLPack device type/id/name, and readonly when knowable.
- DLPack capsules never cross into ooRexx.
- `.ForeignTensor~toDLPack(module[,function])` invokes the target Python consumer (default `from_dlpack`) under the provider GIL.
- NumPy byte strides are preserved; Torch element strides are multiplied by `element_size()` to normalize to bytes.
- CPU device qualification uses DLPack device type 1.
- Existing ForeignBuffer import/export pinning remains unchanged.

Qualification forcing cases:

1. NumPy uint8 array -> `.ForeignTensor` metadata.
2. Independent ForeignBuffer and ForeignTensor references survive closing the original NumPy proxy.
3. NumPy -> Torch DLPack handoff -> Torch `fill_` -> original NumPy storage changes with no copy.
4. Torch tensor metadata reports CPU and normalized byte stride.
5. Torch proxy closes while retained ForeignTensor remains usable.
6. Torch -> NumPy DLPack handoff preserves shared values.
7. Complete inherited binary gate passes, including Python v0.18 reverse import, NumPy zero-copy, PTY/errno, callbacks, OpenSSL and FFmpeg.
8. `test_threads.rex` passes 5/5 on the release candidate.

Not claimed: GPU/device execution or CPU dereference of non-CPU descriptors, DLPack stream negotiation, or a qualified non-Python tensor import provider.


## v0.20 native tensor descriptor acceptance
- Provider-neutral tensor ABI v1 exported by the base runtime.
- NumPy -> ForeignTensor -> independent C consumer: rank/shape/stride/dtype/device/read/write PASS.
- Torch -> ForeignTensor -> independent C consumer: descriptor/read/write PASS.
- Native export pin vs ForeignTensor close race: PASS.
- Existing v0.19 DLPack NumPy <-> Torch test remains PASS.
- Existing v0.17.2 concurrency regression test repeated 5/5 PASS on the candidate.


## v0.21 device-aware tensor execution context
- Tensor descriptor ABI v1 remains frozen.
- ABI v2 adds provider identity, opaque stream/fence handles, synchronization policy, and affinity kind.
- Synthetic CUDA-tagged acceptance: device type 2, stream 0x1111, fence 0x2222, stream-ordered sync, context affinity PASS.
- Generic CPU consumer rejects dereference of the synthetic device tensor.
- v2 export pin vs tensor close race PASS.
- Python non-CPU tensors are not published through the host-only v1 native descriptor path.
- No CUDA runtime was present; GPU execution is explicitly not claimed.

## v0.22 Vulkan hardware candidate
- New optional `libforeign_vulkan.so`, runtime-loaded against `libvulkan.so.1` only.
- Strict test selects vendor 0x8086 and rejects `VK_PHYSICAL_DEVICE_TYPE_CPU`, preventing llvmpipe from accidentally qualifying the GPU path.
- Provider allocates HOST_VISIBLE|HOST_COHERENT Vulkan buffer memory, preferring DEVICE_LOCAL, executes `vkCmdFillBuffer` through a real queue, waits on `VkFence`, and imports the mapped allocation as tensor descriptor v2 (`device_type=7`, provider=`vulkan`, sync=`explicit-fence`, affinity=`context`).
- The provider pins its own shared object for process lifetime after first use so tensor finalization cannot call an unloaded release routine.
- Local container qualification cannot see an Intel non-CPU Vulkan device, so the hardware test reports SKIP 77. The supplied GPD/Iris Xe host is the intended external hardware qualification target.


## v0.22.2 collection-proxy maintenance

v0.22.2 supersedes v0.22.1. It adds Rexx-native collection access for resident Python proxies: `items`, one-based `at`/`[]`, exact `pythonAt`, and nonnumeric mapping-key `[]`. The Python proxy argument marshalling repair from v0.22.1 is unchanged.


## v0.22.3 managed struct graph maintenance

Pointer-valued `ForeignStruct` fields can now retain managed child resources. The runtime stores both the ABI pointer value and the managed relationship, recursively pins all reachable children on invocation, rejects cycles, and prevents field mutation while the struct is actively pinned. This directly supports `msghdr -> iovec -> payload/control`-style layouts without external `memcpy` glue or dangling-pointer races. `ForeignBuffer~putBytes` / `getBytes` provide exact binary slices using zero-based offsets.

## v0.22.5 exact 8-bit scalar / struct-field maintenance

- Adds canonical datatypes `i8` and `u8` (aliases `int8`/`int8_t`, `uint8`/`uint8_t`).
- Size/alignment/sign metadata is 1 byte / 1 byte, signed and unsigned respectively.
- Runtime-loaded libffi maps scalars to `ffi_type_sint8` / `ffi_type_uint8`.
- Scalar arguments and returns preserve exact 8-bit ABI width.
- `ForeignStruct` and `ForeignStructArray` support read/write of `i8` / `u8` fields at exact offsets.
- Numeric conversion rejects i8 values outside -128..127 and u8 values outside 0..255; no silent wrap.
- The legacy no-libffi typed-template fallback rejects 8-bit scalar arguments explicitly; struct-field support is independent of libffi.
- Acceptance uses a real two-byte C struct `{ int8_t, uint8_t }` plus native scalar calls.

## v0.22.5 ABI-profile handover

The portable metadata API is separated from concrete ABI evidence. This release qualifies only `linux-x86_64-le-lp64`. `abiProfile` and `abiProfiles` definitions fail closed on mismatch/unqualified runtime profiles before `dlopen()`. Profile sections currently scope concrete `types` (including struct layouts) and `constants`. This is the intended mechanism for separately qualifying Linux AArch64, FreeBSD amd64, Windows ABI families, etc.; do not copy x86-64 `msghdr`, `cmsghdr`, `pollfd` layouts or constant values into another profile without independent qualification.
