# ooRexx Social Media v0.1-dev4 — restart-aware publication outbox

## Scope

This increment consumes the exact v0.1-dev3 publication request, authority and provider contracts without importing or impersonating CMS Brand Builder, Dynamic Story, Queue Fabric or Institutional Policy. It adds an optional journal to `SocialPublicationService~new(library[, journal])`. `journal` obeys the two-method `SocialPublicationJournal` interface: `replay() -> Directory(requestId -> SocialPublicationReceipt)` and `save(ticket) -> acknowledged completion`. `SocialPublicationService~new(library)` remains the original in-memory mode.

`SocialFilePublicationJournal~new(path)` is an explicit **single-process, single-writer development implementation**, not a production durability provider. It appends hex-safe complete receipt snapshots with monotonic sequence numbers and an arithmetic checksum. It preserves newlines and special characters, and detects malformed/corrupt/torn rows. The checksum detects accidental damage, not adversarial tampering. File closing does **not** establish fsync or storage-durable commit; there is no interprocess fencing, exclusive locking, directory sync, secure append-only storage, backup guarantee or power-loss qualification. Therefore never connect it to a live provider.

## Admission and replay

`submit(request)` checks exact publication authority, provider capability, and library policy before admitting any new request. It records `prepared` through the injected journal, then records `dispatching` before making the provider call. Each acknowledgement/state is journaled. A failed pre-dispatch journal save prevents the provider call. A post-dispatch journal save failure is reported; the previously persisted `dispatching` entry blocks safe retry. An uncertain provider outcome is recorded `unknown` if saving is available. In-memory lookup can expose `dispatching` immediately after a pre-dispatch storage failure; such a receipt is not eligible for re-dispatch.

On process restart `replay()` checks **every** record, sequence, checksum, request-ID/fingerprint binding and transition. If any record is malformed or incomplete, construction fails closed and **no** dispatch is allowed. A `prepared` or `dispatching` last state is restored as `unknown` requiring external reconciliation; the development file adapter first appends a durable-as-supported recovery marker. If this recovery-marker write fails, construction fails closed. A recovered `unknown` can then receive verified `delivered` or `rejected` evidence without breaking journal transition validation. `submitted`, `unknown`, `simulated`, `rejected` and `delivered` are restored without falsely changing remote status. `simulated` remains nonlive and cannot be reconciled into delivery.

A previously seen request ID with identical fingerprint returns the receipt and never dispatches. A changed fingerprint for the same ID is an error, even across process restart. A new intent to publish again needs a new request ID and independent authorisation.

`reconcile()` continues to require a delivery verifier bound to the exact existing request and provider outcome. Before updating a recovered ticket, it journals a **separate candidate receipt**; failed storage must not silently change the prior in-memory authoritative state. Accepted terminal outcomes are immutable. The synthetic verifier supplied here must never be used as a production verifier.

## Provider/estate authority

This is not distributed exactly-once publishing. Queue Fabric scheduling or a saved local outbox does not establish a remote platform commit. A production journal must guarantee durable acknowledged append and atomic/fenced single-writer recovery using the authoritative estate persistence services; a production adapter must reconcile with the provider using authenticated account-scoped evidence (or native idempotency when available), and must guard against changes in permission, channel membership, policy and consent between queueing and dispatch.

Content revisions, approved claims and brand voice remain under CMS Brand Builder authority. Dynamic Story owns selection and narrative truth, not network dispatch. ConnectSelector may provide direct call, standalone JSON-RPC or Queue Fabric as optional service transport. Intention Service performs **dynamic** intention discovery and must not cache a permanent capability catalogue. No integration method names are assumed for these independently evolving services. CMS/Brand effect assessment must consume the detached evidence projections and may not treat receipt `submitted` as delivered or favourable reception.

## Development test matrix

- Previous v0.1-dev3 smoke, surface and publisher suites unchanged and passing.
- v0.1-dev4 `outbox.rex`: persisted simulated acknowledgement, restart without second dispatch, request collision detection, damaged journal fails closed.
- `outbox_unknown.rex`: post-remote ambiguous outcome, restart, verified terminal outcome and restart, prepared-only crash window requires reconciliation.
- `outbox_failure.rex`: injected preparation/dispatch checkpoint failures cannot call provider.
- `outbox_process.rex` run twice as two separate ooRexx interpreter processes: complete replay of multiline content/assets and no duplicate provider call.
- All source classes syntax checked using the user-supplied ooRexx 5.3.0 r13196 debug build.

## Open work

1. Replace the development file journal with the existing authoritative Journal Pointed State / Storage Fabric integration after verifying exact current interfaces. Add fsync, fencing and concurrent worker crash/restart qualification before production use.
2. Add a real provider operation claim using account + social-surface permissions and expiry at execution time, not generic provider family alone.
3. Introduce explicit inbound retention/redaction and external evidence verifier adapters with test fixtures for Steam, Discord, YouTube, marketplace reviews and email groups.
4. Verify CMS/Brand Builder and Dynamic Story revisions, then provide an optional direct adapter and intention registrations, not guessed upstream methods.
