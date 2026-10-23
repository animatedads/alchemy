# Rust Alchemy Bridge sphere v0.1

## Authority and scope

Native ooRexx 5.3 bridge for Rust, with standalone `oorexx-sys` and `oorexx` crates, C++ ABI shim, optional Alchemy Foreign Object projection, and same-interpreter live Rexx message dispatch. Rust-held `RexxObjectPtr` is an object identity, never a cached Rexx method. Rust-owned objects expose an explicit method authority table.

## Accepted evidence

User-reported dev27 qualification included Rust-owned proxy identity, sparse arguments, same-interpreter re-entry, retained Rexx object identity, monotonic retained IDs, release/stale rejection, and nested SYNTAX condition propagation. This is single-threaded evidence only. Dev28 and dev29 are subsequent repair candidates without recorded PC qualification.

## PC packaging work (dev30)

Full source archive `oorexx_rust_native_v0.1-dev30.zip` removes the Android artifact suffix, changes the build target label to `native`, and permits installed Linux SDK fallback include/lib paths. The `.so`, Unix linking, and `LD_LIBRARY_PATH` assumptions remain; Windows is not qualified. Build and run tests must use the selected PC's actual ooRexx headers, libraries and runtime. Do not claim native Rust or PC tests passed before obtaining their receipts.

## Pending engineering

1. Pin retained object invocation under registry lock; release registry lock before foreign invocation.
2. Close admission to new pins on release/revoke/shutdown, while preserving already admitted calls.
3. Defer final `ReleaseGlobalReference` until pin count reaches zero; prove exactly-once release.
4. Preserve interpreter/thread affinity; never persist `RexxCallContext *` beyond an activation.
5. Qualify concurrent call/release/revoke/shutdown and nested callback deadlock behavior on PC.
6. Qualify leading/middle/trailing omitted argument positions through locked methods and nested foreign dispatch.

## Dependencies

Alchemy Foreign Object and Alchemy Objects are optional projection dependencies; native Rust bridge must remain independently usable. Resolve exact ooRexx, Crypto, Foreign Runtime and optional RxMath components without relying on ambient path order. The 2026-09-27 portfolio review is an audit checkpoint, not a clean-code certificate.

## Delivery

Local full replacement source: `oorexx_rust_native_v0.1-dev30.zip`; SHA-256 `fa4a04da499564af05a79ce1b8a2a31834e45f05905fef9923e5d008fa55f5f4`. Shell syntax and ZIP integrity checked; Rust/ooRexx PC runtime qualification pending.
