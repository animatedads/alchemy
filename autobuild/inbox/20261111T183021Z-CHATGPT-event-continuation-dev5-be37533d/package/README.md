# Alchemy Event Continuation v0.1-dev5 — Event-driven wakeup proof of concept

**Architecture/intention: Tom Dyer. Implementation: ChatGPT. Review and independent WASM/browser testing of dev1: Claude (Opus 5.5), Rasen Falcon REQ-00003371 and REQ-00003373.**

This is a **native ooRexx persistent watch + journal**, with a separate ooRexx/WebAssembly browser adapter based on Josep Maria Blasco's `.JSObject` and `ooRexx.scripts`. The supplied web application has *three dummy conversations*; it does not navigate or change real ChatGPT, external accounts or production Rasen Falcon messages.

## Correct event / nudge boundary

The agreed continuation contract is to register a predicate + parameters and a *sender* target (principal, platform, lane/conversation), expiry, fire budget and action class (default notify only). On a condition, an independent native watcher must publish a durable **result** message in the sender's Rasen Falcon lane (watch ID, event ID, observed facts, timestamp and evidence hash). The **nudge** delivered through the target platform is exactly:

`The event you registered a request for WATCH_ID has occurred, check Rasen Falcon MCP`

The LLM reads the result from the mailbox and marks the message read. Completion is **mailbox read**, not DOM click, nudge sent or receipt of a network packet. Unread expired notifications are escalated through explicit authority. Mutating actions require pre-approval; notification is default.

**Implemented in dev5:** the watcher has a durable local event/result journal; the browser receives only this fixed nudge; the test app's send callback acknowledges delivery *after* the DOM handler runs; a separate **local mock result mailbox** is read, then marked complete. The journal has hex-encoded variable fields, a predicate-provider registry, per-event attempt/visibility leases, durable re-arming, dead-letter state after three exhausted leases, and replay. The demo result mailbox is not a replacement for Rasen Falcon MCP. The complete registration metadata, Rasen provider, message hash, expiry/escalation and permissions are **NOT IMPLEMENTED**; this must not be promoted to live autonomous action.

## Native and browser setup

Native dependencies are Alchemy's existing `oorexx_https_server/rexx/https_server.cls` and `oorexx_event_runtime_v0.1-dev1/src/EventRuntime.cls` plus their qualified namespace/Foreign Runtime/OpenSSL dependencies. **There is no HTTP transportMode option on the actual Alchemy server.** The host uses HTTPS with a loopback certificate and explicit bridge directory.

Set `REXX`, `ALCHEMY_HTTPS_REXX_DIR`, `ALCHEMY_EVENT_RUNTIME_REXX_DIR`, `ALCHEMY_HTTPS_BRIDGE_DIR`, `ALCHEMY_TLS_CERT` and `ALCHEMY_TLS_KEY` in the environment, then `sh run.sh` and navigate to `https://127.0.0.1:8765/`. The cert should be trusted in a normal browser; isolated headless Chromium qualification with self-signed certificates may require `--ignore-certificate-errors` for worker resource loading (Claude review REQ-00003373). Do **not** use a self-signed or test certificate in production without a valid trust policy.

Place matching upstream `ooRexx.js`, `ooRexx-worker.js`, `rexx.js`, `rexx.wasm`, `rexx.data`, `js-realm.js`, `polygon-clipping.umd.min.js` into `assets/`; no upstream binary is redistributed. Click **Register watch**, then **Create ready.flag**. The ticker detects it; the browser-side ooRexx acquires a lease, clicks the Rasen Falcon *dummy* chat, enters the fixed nudge and sends. Its callback (rather than an immediate click check) fetches the *mock* result mailbox and marks read. **Remove ready.flag** to rearm the watch; creation again issues a second event. COOP, COEP and WASM MIME type are provided by the existing server adapter.

## Core tests

`REXX=/path/to/rexx sh run_tests.sh` runs static checks followed by `test_core.rex` and `test_delivery.rex`. The first covers durable edges, lease ownership, restarts and three file predicates. The second covers provider registration, `|` in a persisted message, exact fixed nudge, no fact content in browser wire, retry budget, DLQ and replay. A missing interpreter is a non-zero `NOT_RUN`, not PASS. On Autobuilder, the test runs with exact component namespace plus `ALCHEMY_REPO_ROOT`. Additional real HTTPS/browser tests are separate qualification gates not implied by native core PASS.

The journal records `W2` (hex-encoded registered watch), `E2` (hex-encoded event), `S` (re-arm), `K` (lease and attempt), `R` (receipt), `D` (dead letter) and `C` (read completion). Historic `W/E` records from dev4 remain readable. It uses append and close, **not** durable transactional fsync or torn-write recovery. For production, use our qualified storage/queue, Intention Service, Common Security / LDAP, API Client / Virtual Browser and Rasen Falcon's message/mailbox authority rather than expanding these toy HTTP routes.

## Correct Autobuilder delivery

Root `integration.json` is schema `alchemy.autobuild.integration/0.3`, with declared `sh run_tests.sh` and an immutable `publish.tree` path `packages/alchemy_event_continuation_v0.1-dev5`. Submit source through `tools/alchemy_submit.py` when an execution-capable Git checkout exists; only if unavailable, use the equivalent GitHub Git Data API fallback: package tree in one commit, `ready.json` in a second commit, push the `autobuild-submit/<id>` branch and never merge it to main. A fresh receipt in `autobuild/receipts/<submission_id>.json` with `status: PASS` is required for acceptance; Git submission alone is not evidence. At the time of dev5 creation, dev4 had a genuine PASS receipt for its native core test; dev5 must qualify independently.

## Known limitations and next action

The real Rasen message sink, sender/target principal mapping, message evidence hash, mailbox-read receipt, expiry/escalation, firewall/network/consumer rate admission and action approval are not wired. Browser/WASM live test of this revision is also unqualified. Runtime lease and toy localStorage dedupe prevent a repeat storm but cannot guarantee exactly-once external effects. Successful demo clicks must never be interpreted as permission to purchase an iPhone or modify a live website. Use the documents in `sphere/packs/event-continuation/` to coordinate that work.
