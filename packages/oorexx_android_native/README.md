# Android native host dev17
Build-only checkpoint from the dev16 host. It isolates Android -> JNI -> RexxCreateInterpreter -> RexxArrayObject -> CallProgram. It deliberately contains no Wire dependencies yet. Logging brackets NewArray(0), CallProgram, and CheckCondition, and the Termux build log is persisted to Download.

## dev18 source checkpoint (2026-10-29)
The original dev18 JNI host and Termux build script from the local `oorexx_android_native_dev18.zip` archive are now versioned alongside dev17:
- `wire_mobile_host_dev18.cpp` implements the JNI entry, asset extraction, interpreter creation and CallProgram checkpoints.
- `build-wire-mobile-host-dev18.sh` checks the pinned ooRexx source revision when a Git checkout is present, Android identity, compound-variable behavior and the POSIX semaphore native dependency, then stages APK-native inputs.
- `mobile_main_dev18.rex` is the matching Rexx compound-variable smoke test. For this build script, copy it to `mobile_main.rex` or use the existing identical bootstrap asset.

**Qualification limit:** dev18 is a build-input bundle, not an APK or handset pass. The host exports `Java_org_oorexx_wire_mobile_WireOoRexxRuntime_nativeStart`; the Java class must use that exact JNI name/signature, or the native binding must be changed deliberately. This checkpoint does not enable public HTTPS, LDAP, mail or MU/MI communications; it is a consumer-side mobile runtime dependency.
