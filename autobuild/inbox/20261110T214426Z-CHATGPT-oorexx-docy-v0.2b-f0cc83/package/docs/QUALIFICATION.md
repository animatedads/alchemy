# DOCY v0.2 candidate local qualification

Date: 2026-11-08
Runtime: user-supplied ooRexx 5.3.0 r13196 x86_64 Debian package, unpacked to a disposable local staging directory.

Test commands:

```sh
OO=/path/to/unpacked/usr/local
REXX_PATH="$OO/bin:." LD_LIBRARY_PATH="$OO/lib:$OO/lib64" "$OO/bin/rexx" demo_test.rex
REXX_PATH="$OO/bin:." LD_LIBRARY_PATH="$OO/lib:$OO/lib64" "$OO/bin/rexx" test_extension.rex
```

Results:

- `demo_test.rex`: 44 PASS, 0 FAIL.
- `test_extension.rex`: 2 PASS, 0 FAIL.
- Stable semantic keys; template inheritance and nested templates; variant, document, project and template precedence; shared placements including repeated placement; affected-output plans and override warnings; typed fact and table references; command/Credits STOP validation; unknown binding WARN; stale revision-fenced plans; template-cycle STOP; `.docy` snapshot round-trip; event predecessor restoration; SVG source and passive HTML rendering; multi-STOP damaged loader; externally registered node type.
- The synthetic fixture intentionally models `etc/machines` and test-run receipts without reading those real files.
- No concurrency, Storage Fabric, Git, accepted release, hash-chain cryptographic verification, source adapter or production qualification tests conducted.
