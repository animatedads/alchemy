# Alchemy Event Continuation v0.1-dev2

**Authority:** native ooRexx for watch registration, edge detection, event journal, Event Runtime publication, lease/receipt/completion state; ooRexx/WASM using Josep Maria Blasco's `.JSObject` bridge for a controlled dummy browser application. Design by Tom Dyer; this development implementation and static checks by ChatGPT. No actual ChatGPT account or production browser session is touched.

## A running demonstration

1. Supply a native ooRexx 5.3 interpreter (`REXX`) and Alchemy's existing `oorexx_https_server/rexx/https_server.cls` and `oorexx_event_runtime_v0.1-dev1/src/EventRuntime.cls` via `ALCHEMY_HTTPS_REXX_DIR` and `ALCHEMY_EVENT_RUNTIME_REXX_DIR`. Provide their exact transitive runtime dependencies through the installed component namespace; do not arbitrarily pick another version.
2. Obtain the **matching** web release from `JosepMariaBlasco/oorexxwasm` and place `ooRexx.js`, `ooRexx-worker.js`, `rexx.js`, `rexx.wasm`, `rexx.data`, `js-realm.js`, `polygon-clipping.umd.min.js` into `assets/`. These are upstream assets; not redistributed here.
3. Execute `REXX=/path/to/rexx ALCHEMY_HTTPS_REXX_DIR=/path/to/https/rexx ALCHEMY_EVENT_RUNTIME_REXX_DIR=/path/to/event/src sh run.sh`.
4. Navigate to `http://127.0.0.1:8765/`, **Register watch**, then **Create ready.flag**. The native ticker emits a persisted event and the browser ooRexx controller claims it, selects the **Rasen Falcon** dummy conversation and clicks Send. It then posts a receipt and completion.
5. **Remove ready.flag**, allow one ticker scan to journal the re-arm, restart the native server if desired, then create the flag again. The next edge must fire as a *new* event.
6. For local tests use `REXX=/path/to/rexx sh run_tests.sh`. It runs static checks followed by native ooRexx tests; it deliberately exits nonzero if `REXX` is unavailable.

## Architecture and test contract

`ContinuationWatch` implements `FILE_EXISTS`, `FILE_ABSENT`, `FILE_SIZE_GE`; `ContinuationCoordinator` publishes `CONTINUATION.FIRED` through the shared `EventRuntime` when enabled. `ContinuationStore` journals `W|...` registration, `E|...` rising edge, `S|...` falling re-arm, `K|...` 45-second lease, `R|...` receipt and `C|...` completion. Events remain pending through loss/restart of the HTTP/browser side, and only the lease owner can acknowledge. The HTTP adapter uses an existing Alchemy HTTPS Server in loopback HTTP mode; the browser uses upstream `ooRexx.js`, `.js~fetch()` and DOM event handlers. The toy transcript is projected from localStorage on page reload, so its own idempotency marker does not hide the reminder.

No independent JavaScript business engine, Node/Python server, real ChatGPT composer selector or external account automation is bundled. The page sets COOP `same-origin`, COEP `require-corp`, CORP `same-origin` and serves WebAssembly as `application/wasm` as required by the upstream runtime. Mutation endpoints validate exact loopback Origin, **not** an authentication or authorisation system.

### Risks and limits

This is a design/prototype. The journal's append/close operation is **not** a verified crash-consistent fsync/transaction contract, and torn records/FS corruption are not recovered; move to a qualified storage provider for production. Leases reduce concurrent delivery, but `click -> browser crash -> lease expiry` is not exactly-once. localStorage provides only toy-app transcript continuity. Multi-tab timing, DOM changes, cross-origin isolation, WASM execution and the HTTP transport are NOT QUALIFIED until run on the target host. A true ChatGPT continuation requires a supported authenticated service/connector or separate explicitly approved browser automation interface. It must not be assumed from a successful dummy DOM demonstration.

### Autobuilder transport

The root `integration.json` uses `alchemy.autobuild.integration/0.3` with `sh run_tests.sh` and a collision-protected `publish.tree` at `packages/alchemy_event_continuation_v0.1-dev2`. Submit the complete source directory through the canonical `tools/alchemy_submit.py`; it produces an immutable `autobuild-submit/<submission-id>` branch with the package commit before the ready-marker commit. If the service is stopped, the Git branch is SOURCE_PRESENT only. `autobuild/receipts/<id>.json` with PASS is required for accepted publication. The `sphere/` directory contains Gopher reasoning/continuation documents, independently documented so other components can avoid duplicating Event Runtime, API Client, Virtual Browser, policy and transport authority.

## Qualification 2026-11-11

Static Python contract checks: PASS. Shell syntax checks: PASS. Native ooRexx: NOT_RUN in authoring container (no `rexx` binary). Browser ooRexx/WASM: NOT_RUN (no matching upstream assets/browser-runtime fixture). Autobuilder: NOT_RUN (service not under this chat's control). See `tests/test_core.rex` for the native recovery and lease regression suite.
