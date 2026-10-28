# Provenance: oorexx_socket_provider_v0.1-dev14-halfclose1

- Architecture: Tom Dyer
- Coding: Claude (Opus 5.5), cloud session, Rasen Falcon lane `estate-pickup`
- Written by: Claude (Opus 5.5)
- Date: 2026-10-28

## Base

A byte copy of `packages/oorexx_socket_provider` at repository commit `e3844dab`, whose `VERSION.txt` says `0.1-dev14`. `MANIFEST.sha256` was dropped from the copy because it no longer matches; a new one covers this package.

## Why the label is dev14-halfclose1, not dev17

`CURRENT_PROVIDER_COMPATIBILITY.md` names `oorexx_socket_provider_v0.1-dev16.zip` (SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`) as the current authority and says the repository source must not be relabelled without the exact dev16 source. On 2026-10-28 Tom confirmed that nobody holds the dev16 source. A dev17 label would claim the dev15 and dev16 changes, which this package does not contain. The estate already uses this naming for an increment on an older base (`oorexx_storage_fabric_v0.1-dev23-precision1`).

If the dev16 source is recovered: re-apply the changes listed in `CHANGELOG.md` under `0.1-dev14-halfclose1` on top of it, as dev17, and rerun every test listed in `VALIDATION_HALFCLOSE1.txt`.

## What changed

Files changed from the dev14 base:

- `src/SocketProvider.cls`: version constants; `SocketCapabilities~halfCloseSend`; TCP and UNIX family flags; `ProviderSocketConnection` half-close state, `shutdownSend`, guarded `send`/`sendAll`, end-of-stream `recv`, tolerant `capabilities`; `SocketStreamAdapter~closeWrite`; `ProviderSocketListener` half-closer hand-off and the `address` fallback fix.
- `src/SocketIntentions.cls`: `requireHalfCloseSend` and the `HALF_CLOSE_REQUIRED` rejection.
- `src/RxSockSocketBinding.cls`: `RxSockHalfCloser`, passed to listeners and senders.
- `src/UnixSocketBinding.cls`: `UnixHalfCloser`, passed to listeners and senders.
- `tests/environment_test.sh`, `qualification/run_environment_test.sh`: the new tests.
- `README.md`, `CHANGELOG.md`, `VERSION.txt`, `PACKAGE.json`.

New files: `tests/test_halfclose_contract.rex`, `tests/test_halfclose_negotiation.rex`, `tests/test_rxsock_shutdown_route.rex`, `tests/test_real_halfclose_tcp.rex`, `tests/test_real_halfclose_unix.rex`, `tests/HalfCloseRoundTrip.cls`, this file, `VALIDATION_HALFCLOSE1.txt`, `MANIFEST.sha256`.

Unchanged: `src/XtpSocketProvider.cls`, `src/TLSSocketFamily.cls`, `src/RxSockUdpBinding.cls`, and every other test and document.

## Review

Before commit, a separate Claude agent reviewed the diff read-only. Its findings and the fixes are listed in `VALIDATION_HALFCLOSE1.txt`.

## Not included, and why

- TCP6: the rxsock6 provider is a sibling package, and its qualified dev3 / rxsock6 0.1.2 source has not been recovered (`packages/oorexx_socket_provider_rxsock6/SOURCE_RECOVERY_STATUS.md`). That package's fail-closed rule forbids patching around the gap.
- TLS: needs a half-close operation in the injected `TLSEngine` contract, and only TLS 1.3 sessions can support it.
- QUIC: a sibling package; needs a native wrapper around OpenSSL `SSL_stream_conclude`.
- XTP: libxtp dev30 sends every FIRST with `RCLOSE|WCLOSE|EOM`; this waits for the persistent FIRST-to-KEY context.
