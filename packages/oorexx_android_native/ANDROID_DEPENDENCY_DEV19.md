# Android runtime dependency qualification (dev18/dev19)

This branch brings the Android JNI/ooRexx work into source control without claiming handset qualification.

## Existing authority
- `packages/oorexx_android_jni_proof_v0.1-dev22-fixed`: installed JNI proof (native return 12345).
- `packages/oorexx_android_native`: dev17 source checkpoint, not an installed runtime.

## dev18 runtime build gate
Qualified Android ooRexx source commit: `135409288aaf8bbd8fe35945bab95fc830b3443d`.
Required Android flags: `-fwrapv -fno-strict-aliasing`; disable IPO.
Before compiling the host, verify the Android platform identity, compound-variable semantics and the `libandroid-posix-semaphore.so` dependency.
The Rexx entry asset should test `a.1 = 'one'` before returning `OO REXX WORKS`.

## dev19 APK static gate
Independently inspect arm64-v8a ELF headers, DT_NEEDED closure, JNI export and Rexx asset. This is **not** a substitute for Java/JNI declaration matching, package install validation or live interpreter execution.

## Known defects / boundaries
- dev23 reached Java nativeStart but closed; JNI Java class/export mismatch is suspected, not conclusively proven.
- dev24 failed Android package installation; do not treat its APK as a packaging baseline.
- dev22-fixed is the last handset-confirmed JNI installation.
- The dev17/dev18 host export is `Java_org_oorexx_wire_mobile_WireOoRexxRuntime_nativeStart`; the Java class and declaration must match exactly or use RegisterNatives.
- Normalise versioned ELF SONAME/DT_NEEDED dependencies for APK packaging; do not merely rename `.so.4` files.
- Keep Wire and RexxOS networking/storage capabilities optional until core interpreter invocation succeeds.

## Qualification stages
1. Validate exact source and build flags.
2. Validate native ELF dependency closure and Android ABI.
3. Validate Java class, native method signature and export.
4. Build using known-good dev22 packaging and verify signature/manifest.
5. Install on handset and collect durable Java/JNI/Rexx checkpoints.
6. Exercise RexxCreateInterpreter and CallProgram with compound variable.
7. Activate Wire semantics and native renderer.

Source archives from previous checkpoints must be committed as text source, not replaced by reports or assertions. The present branch is an initial synchronization and engineering ledger.