# Wire3D Android / Termux cut

This cut follows the path-discovery pattern proven by `oorexx_rust_native_v0.1-dev27_android`: ooRexx source/build/include/lib roots are explicit and overrideable; no `/usr` ooRexx installation is assumed.

## Native prerequisites
Termux supplies the architecture-correct native toolchain and OpenSSL:

    pkg install clang make openssl libffi python

OpenSSL is intentionally **not** copied from the desktop Crypto archive. `android-env.sh` points direct Foreign Runtime metadata at Termux's `$PREFIX/lib/libcrypto.so`; `build-android.sh` rebuilds `libforeign_runtime.so` and Crypto's small `libcrypto_compat.so` on the phone.

Set `OOREXX_SRC` and `OOREXX_BUILD` if your working ooRexx tree differs from the Rust defaults, then:

    ./build-android.sh
    ./run_tests.sh
    ./run-phone-demo.sh

`REXX_PATH` is assembled from Wire3D plus every packaged dependency's `src`/`rexx` directory. `LD_LIBRARY_PATH` includes both the selected ooRexx build library directory and Termux `$PREFIX/lib`.

## Packaged dependency authorities
Exact upstream archives are retained under `dependencies/`; extracted copies under `vendor/` are convenience/runtime material, not forks. Included: Alchemy Objects 0.8, Crypto 0.8.3, Foreign Runtime 0.22.6, Runtime Reference 0.4, Observation 0.5, Queue Fabric 0.9-dev6, Queue Fabric Web Gateway 0.2, HTTPS Server 0.4.4, Wire UI Builder 0.11, Wire UI Server 0.17.

## Native SSL rule
The phone's Termux OpenSSL is the native SSL/crypto authority. Prebuilt `.so` files shipped inside upstream desktop archives are not trusted as Android binaries and are replaced/rebuilt where Wire3D's dependency chain needs them.

## dev11 AArch64 repair

If dev10 failed on `RTLD_DI_LINKMAP`, `lastNativeReturnText`, `activateCallback` or `invokeLibFFI`, those diagnostics all came from two upstream Foreign Runtime portability assumptions: glibc `dlinfo` and an x86-64-only libffi block. dev11 repairs both for Android/AArch64 and uses the Termux libffi development headers/ABI directly.

## dev12 layout repair
The Wire3D application is flattened into this Android package root (`src/`, `examples/`, `web/`, `tests/`). This is intentional: launchers, `REXX_PATH`, and the application files now share one package root. dev11 accidentally retained the dev9 application as a nested directory, causing `run-phone-demo.sh` to look for a non-existent root-level `examples/corporate_city.rex`.

The optional diagnostic no longer requires the Termux `file` command. `readelf`, when available, is used only as a non-fatal ELF diagnostic.

## dev22
Adds ooRexx-described deterministic projector tracking field (`wire3d-tracking/1`).

## dev23 HTTP server
`./run-phone-demo.sh` now starts the packaged ooRexx HTTPS Server in its HTTP transport mode. Python's development HTTP server is no longer part of the Wire3D demo path. Open `http://127.0.0.1:8080/`.

The qualification tracking profile is deliberately conspicuous: deterministic major registration lines plus seeded stars. The status line reports `FIELD ON` when active.
