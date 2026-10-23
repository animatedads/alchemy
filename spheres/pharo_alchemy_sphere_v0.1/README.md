# Pharo Alchemy sphere

Read-only knowledge sphere for the resident ooRexx ↔ Pharo bridge. Runtime-authoritative dispatch, reversible live-object identity, generation-tagged handles, retain/release and synchronous call-thread reentry are governing contracts.

Dependency baseline: ooRexx 5.3.0 r13196, Alchemy Foreign Object 0.2, Alchemy Objects 0.8.1, Crypto 0.8.3, Foreign Runtime 0.22.6 and Pharo 12.

Qualification: dev15 and dev16 selector-shape C11 tests PASS (rerun 2026-10-23). Live selector dispatch and arbitrary-object identity through the new message ABI NOT_RUN. dev13 combined integer callback is historical evidence only, not rerun.

Source ZIP SHA-256: 8b437677093e8373b54f2a5b80a5a6c4f639091ca36a932282d18832cf7a7713.

Pending: native selector dispatcher integration, identity reversal, dynamic method mutation, omission/nil/empty differentiation, absent vs thrown exception, nested reentry, revoke/shutdown races and wrong-thread callback rejection.

This is sphere documentation, not a claim of canonical Gopher sphere validation.
