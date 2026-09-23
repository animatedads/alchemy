# Android qualification fixes (dev11)

This mobile cut carries an Android-specific source repair to the bundled Foreign Runtime v0.22.6 source while retaining its public package/API identity.

* Android bionic does not expose glibc `RTLD_DI_LINKMAP`; canonical loaded-name refinement is therefore skipped on Android after successful `dlopen`.
* The upstream v0.22.6 libffi implementation was gated to `__x86_64__`, leaving its later generic call/callback code uncompilable on AArch64. Android now uses Termux's real `<ffi.h>`, `FFI_DEFAULT_ABI`, `ffi_closure` size and the platform libffi entry points.
* The native Foreign Runtime link now includes `-lffi`.
* `build-android.sh` preflights `$PREFIX/include/ffi.h` and instructs `pkg install libffi` if absent.

The historical x86-64 runtime-loaded libffi path is unchanged. This is a build-portability repair, not a new Wire3D transport or crypto implementation.
