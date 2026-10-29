# Changelog

## Android native host source sync (2026-10-29)
- Import dev18 JNI C++ host and Termux build script under packages/oorexx_android_native on PR #19.
- Keep the Wire UI Android sphere qualification boundary: source import and native dependency checks do not imply APK installation, interpreter execution on handset or production service activation.
- Android runtime is a consumer of native platform services, not an authority for public HTTPS, LDAP, SMTP/IMAP or MU/MI transport.

## 0.1 — Android runtime dependency clarification (2026-10-23)
- Add `wire-ui.android-native-runtime-dependency` to the Wire UI authority sphere.
- Distinguish semantic dependency locking, native ELF closure, APK installation, JNI dispatch, interpreter execution and Wire activation.
- Preserve dev22-fixed as the handset-confirmed JNI proof; dev23/dev24 remain unresolved.
- Documentation only: no claim of APK rebuild or device qualification.

## 0.1
- Establish authoritative row/list/workspace documentation for shared Wire UI adoption across FlyLo and Federation-company UIs.
- Initial sphere scaffold.
