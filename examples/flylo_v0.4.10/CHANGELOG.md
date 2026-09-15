# FlyLo v0.4.10

- Makes the package-root `./flylo` airline runtime durable. `FLYLO_DATA_DIR` defaults to `~/.flylo`; Queue Fabric state is retained under `queue/` and the native accounting book under `accounting/flylo-stat.jsonl`.
- Fixes the root cause of passenger details disappearing after launcher restart: confirmed booking projections and stable `PAX-001...` passenger identities now recover across a literal stop/start of `./flylo`.
- Keeps Queue Fabric source evidence and Accounting Core durable accounting truth complementary rather than competing: retained capture event first, accounting post second; recovered journals turn retained-event reconciliation into exact duplicate handling, while a crash between the two writes completes the missing post on restart.
- Advances the accounting integration to Accounting Core v0.7 and `flylo.accounting/0.4`, retaining `NUMERIC DIGITS 50`, exact canonical integer minor units, append-only `AccountingFileStore` recovery, source-event conflict detection and deferred revenue treatment. v0.7 tax/settlement APIs are not implicitly adopted as FlyLo policy.
- Removes remaining FlyLo accounting-boundary numeric coercions that could weaken Accounting Core's exact-minor-unit precision contract.
- Advances the public Wire UI authority to Server v0.17 and Builder v0.11. Passenger servicing commands now bind authoritative `resultRevision` in addition to query/scope/order/selection revisions and selected semantic passenger IDs.
- Proves stale-result rejection: after one bag changes the booking result, replaying the still-selected passenger's old workspace context is rejected as `WORKSPACE_RESULT_REVISION_MISMATCH`.
- Makes sale/idempotency identity restart-safe; after recovering a durable `SALE-00001`, the next new sale is `SALE-00002` rather than reusing the old identity.
- Fixes a durable-Queue serialization edge where ooRexx `json.cls` wrapper strings could otherwise be rejected as non-persistable payloads.
- Adds a visible `v0.4.10 · durable` build badge sourced from `/healthz`, reducing the chance that an older process on port 4173 is mistaken for the current release.
- Requalifies the real-time Grok strict structured-language/Structured Utterance boundary unchanged; passenger chat still contains no Grok Batch path.

# FlyLo v0.4.9

- Adopts Accounting Core v0.3 and its preferred `accounting.event/0.1` -> `AccountingEngine~transact()` / `accounting.transaction/0.1` operational path. FlyLo no longer constructs accounting journal drafts in the normal booking/ancillary integration.
- Separates payment authorisation from capture. Booking inventory commitment still requires authorisation; explicit capture occurs only after booking confirmation. Capture failure leaves the already-confirmed sale in financial recovery state and never retries booking/inventory implicitly.
- Adds an independent FlyLo `AccountingBook` with accounts for card-processor receivable, passenger-service contract liability, carriage revenue and ancillary revenue. Captured ticket and checked-bag consideration post to receivable/liability only; no revenue is recognised merely on sale/capture.
- Registers separate effective-dated booking-capture and ancillary-capture policies. Journals retain semantic `policyRef`, exact `policyIdentity`, source event fingerprint/type, source-authority stamp and source evidence. The executable policy identity is based on the SHA-256 identity of `FlyLoAccountingPolicyImpl.cls` plus the exact event-policy configuration.
- Publishes normalized accounting-event projections to retained `FLYLO.ACCOUNTING.SOURCE.EVENTS`; only the finance principal can publish and only the accounting worker can browse. Browser/channel/booking principals do not write the GL.
- Locks Accounting Core v0.3 replay semantics: exact replay returns `DUPLICATE` before policy execution; a changed event with the same source reference returns `SOURCE_EVENT_CONFLICT` and cannot overwrite the retained source-event slot.
- Rebuilds the independent FlyLo accounting book from retained normalized events after restart.
- Adds booking and checked-bag accounting integration regressions, authorization-only rejection, policy identity/evidence checks, changed-replay conflict, Queue event-contract validation and restart reconstruction.
- Public `./flylo` health now reports `ACCOUNTING_CORE_0.3`; confirmed sale and manage-booking responses retain explicit capture/accounting status and journal identities.

# FlyLo v0.4.8

- Fixes the manage-booking failure reported from the public website where an ordinary missing booking was exposed as `RUNTIME_CONDITION_88.900: position=27`. The Queue adapter's `FLYLO_BACKEND_REJECTED` condition is now decoded back into its authoritative engine-domain result at the persistent public-runtime boundary.
- `BOOKING_NOT_FOUND` and `BOOKING_NAME_MISMATCH` are deliberately collapsed at the HTTP/browser boundary into `BOOKING_LOOKUP_NOT_MATCHED`, avoiding both internal ooRexx leakage and booking-reference enumeration. Genuine runtime faults remain server diagnostics and receive a non-transactional generic browser error.
- The confirmation-page **Manage these passengers** action now opens the just-confirmed booking's `BOOKING.<ref>.PASSENGERS` workspace directly using the server-issued booking identity and surname from the authoritative confirmed booking passenger projection; passengers no longer have to copy their new reference into the lookup form.
- Adds a launcher regression for the exact screenshot input (`bookingRef=12`, `familyName=dyer`) and for a surname mismatch, while retaining the successful two-passenger passenger-list/workspace path.

# Changelog

## v0.4.7

- Consumes Wire UI Server v0.16 workspace/query/selection authority rather than merely qualifying against it.
- Moves the public `./flylo` sales and manage-booking semantic actions onto a persistent ooRexx `FlyLoWireApplication` backed by Queue Fabric engines; the shipped public page no longer enables browser demo-action fallback.
- Vendors the qualified Wire UI Server v0.16 and Builder v0.9.1 source slices required by the one-command runtime.
- Assigns immutable `PAX-001...` passenger identities at booking confirmation and deterministically backfills them when older v0.4 booking projections are recovered.
- Adds `BOOKING.<ref>.PASSENGERS` workspaces, authoritative selection/sort mutation endpoints, and exact `WireUIWorkspaceCommandContext` validation before passenger-scoped servicing.
- Adds `BOOKING.ADD_CHECKED_BAG` as a separate idempotent booking-engine command with authoritative £49-per-passenger-per-bag pricing and a separate payment authorisation identity. The original booking/sale transaction is retained; servicing appends ancillary evidence.
- Proves sort preserves the daughter selected by `PAX-002`, stale pre-sort context is rejected, forged `PAX-999` is rejected, exact current context services only the intended passenger, and exact replay does not duplicate baggage.
- Adds a full `./flylo` HTTP regression that performs the booking, lookup, v0.16 selection/sort/adversarial checks and bag servicing through the actual single-command website runtime.
- Changes sale IDs from space-padded ooRexx formatting to canonical `SALE-00001` style.
- Raises the public browser passenger input ceiling from 9 to 99; the structured language and Journey Engine remain inventory-authoritative for larger parties.
- Isolates assistant-only ooRexx failure injection/configuration (`FLYLO_ASSISTANT_REXX`) from the persistent public booking runtime so a chat-runtime failure cannot accidentally replace the booking engine process.
- Retains real-time Grok strict structured outputs, Structured Utterance v0.3, no Grok Batch path, and the production AS/400 boundary.

## v0.4.6

- Fixes the reported passenger turn `can I book 10 tickets to new york` failing into the degraded language-layer continuity response.
- Removes the leaked 1-9 passenger ceiling from xAI strict interpretation schema, `FlyLoLanguageFrame`, and Journey Engine search validation. Passenger count is semantic/search data; actual route inventory decides whether the requested party can be offered.
- Preserves `passengers=10` and deterministic New York resolution (`EWR`) in the structured frame. The incomplete request now asks only for origin, travel date, and one-way/return.
- Strengthens the Grok interpretation prompt so `10 tickets` must remain exactly ten rather than being clamped to nine or discarded.
- Strengthens the deterministic degraded-continuity path to recognise booking/ticket language, retain an explicitly stated numeric party size, and avoid asking for passenger count again.
- Converts Journey Engine domain rejections such as `NO_ITINERARY_AVAILABLE` into normal passenger-facing search evidence instead of internal ooRexx/structured-runtime failures. Queue/infrastructure failures remain internal failures.
- Adds a ten-seat engine regression proving a PIK -> EWR fixture search succeeds when twelve seats exist, and a GLA -> EWR assistant regression proving ten passengers receive ordinary `SEARCH_UNAVAILABLE` evidence when the eight-seat feeder is the bottleneck.
- Adds exact full-launcher regressions for the reported ten-ticket turn, its degraded-continuity equivalent, and the subsequent insufficient-inventory conversation.
- Reconfirms FlyLo unchanged against the current `oorexxapis(20260828-114946).zip` platform line: Wire UI Server v0.15, Wire UI Builder v0.9.1, Alchemy Wire UI JS v0.4-dev4 and Queue Fabric v0.9-dev4.
- Retains strict xAI JSON-schema outputs, Structured Utterance v0.3, real-time Grok only, and the single package-root `./flylo` launcher.

## v0.4.5

- Fixes the passenger-visible `assistant structured runtime failed safely` failure reported for ordinary turns such as `tell me about my booking` and `I want to fly to new york`.
- Pins the supplied ooRexx 5.3.0 r13196 `json.cls` inside the FlyLo package and prepends that exact standard-library slice to the assistant child runtime, eliminating host `json.cls` drift in strict structured-output decoding.
- Adds `tools/flylo_runtime_probe.rex`; `./flylo` preflights JSON boolean encode/decode semantics before declaring Grok chat ready.
- Uses `.JSON~true` for xAI `json_schema.strict` instead of a post-serialization `"strict":1` string-rewrite workaround.
- Makes FlyLo structured truth conversion independent of `JSONBoolean` class identity while still correctly handling the r13196 JSON boolean proxy through its value interface.
- Reworks `flylo_assistant_turn.rex` into stage-labelled structured bridge phases. Internal conditions now carry a stable `FLYLO_ASSISTANT_INTERNAL_<STAGE>` code and safe stage/condition/position diagnostics.
- Prevents raw internal bridge failure text from being exposed to passengers. The server records the diagnostic and provides a limited deterministic, explicitly degraded continuity reply for basic booking-help or flight-search requests. This continuity path is non-transactional.
- Adds exact release-blocker regressions for the two reported ordinary passenger turns and a synthetic ooRexx internal-condition regression proving diagnostic isolation and continuity behaviour.
- Extends `/healthz` assistant status with runtime readiness, structured-runtime identity, configuration issues, degraded state, and last internal diagnostic code.
- Retains real-time Grok strict structured outputs, Structured Utterance v0.3, deterministic airline authority selection, single-command `./flylo` startup, and the no-Batch passenger-chat boundary.

## v0.4.4

- Enforces xAI **strict structured outputs at the transport boundary** for both interpretation and response planning using `response_format.type=json_schema`, named schemas and `strict=true`; FlyLo parses/validates the returned JSON again.
- Upgrades the structured frame/schema to `flylo.assistant.frame/0.2`, `flylo.assistant.interpretation/0.2` and `flylo.assistant.utterance-plan/0.2`.
- Adds post-booking state: `MANAGE_BOOKING`, `BOOKING_LOOKUP`, `ADD_CHECKED_BAG`, booking reference/surname, and separate information requests for baggage, immigration entry and customs tobacco.
- Keeps pending ancillary servicing independent from informational detours. Asking about immigration/customs no longer destroys an outstanding extra-bag task.
- Stops post-booking baggage servicing from asking shopping-stage passenger-count or one-way/return questions; it asks only for missing booking lookup identifiers.
- Adds `FlyLoTravelInformationAuthority` with versioned official-source evidence snapshots for U.S. entry, CBP tobacco/customs and TSA cigarette baggage rules, checked 2026-08-28.
- Handles the reported `Columbian` spelling as Colombia at the deterministic country resolver boundary.
- Distinguishes airline document/baggage authority from U.S. government admission/customs authority; the assistant must not predict admission or treat duty-free purchase/checked baggage as a customs exemption.
- Adds age-sensitive tobacco handling: when cigarettes are said to be for a daughter/child, FlyLo does not count a child allowance unless age supports it; cited CBP evidence records adult age 21+ and the 200-cigarette quantity for the cited personal exemption.
- Fixes ooRexx `JsonBoolean` handling in structured input, and preserves real JSON booleans at the HTTP API boundary.
- Fixes subclass state access in the Grok structured-output adapter: Grok provider object variables are class-private in ooRexx, so the FlyLo extension now keeps explicit references while continuing to use GrokProviderConfig, SecretBroker and GrokCurlTransport.
- Replays the exact reported post-booking transcript end-to-end through `./flylo` and the real-time Grok transport fixture.
- Keeps the earlier structured journey-search behavior: relative dates are resolved deterministically and complete shopping frames automatically query Journey Engine.
- Keeps `./flylo` as the only startup command and passenger chat real-time only; no Grok Batch source or `/v1/batches` path is present.

## v0.4.2

- Makes **Ask FlyLo** a real conversational panel rather than a decorative semantic-action button.
- Adds `POST /api/assistant` to the existing single-command `./flylo` launcher; no second web server or Python process is required.
- Uses the Grok-authored ooRexx `GrokRuntimeModule` / `GrokProviderAdapter` real-time `model.complete` path.
- Explicitly excludes Grok Batch from passenger chat; Batch provider/WLU sources are not vendored into the launcher runtime.
- Keeps `XAI_API_KEY` server-side behind Secret Broker; health output exposes configuration state only.
- Bounds assistant input/history and strips hidden passenger-list/email/payment-token fields from browser application context before model invocation; passenger-entered chat text remains chat input.
- Adds a self-contained vendored AI runtime slice from the supplied 2026-08-27 API roll-up.
- Adds unit and full launcher-to-provider fixture regressions, including proof that PII/payment-token fields are not sent to the model prompt.
- Fixes an ooRexx bridge regression caused by treating special variable `RESULT` as a mutable Directory.


## v0.4.1

- Adds the executable package-root `./flylo` launcher as the canonical way to start the FlyLo website.
- Uses Node.js built-ins only for static delivery; no Python HTTP server or multi-terminal startup recipe is required.
- Prints `FLYLO_READY <url>` for Codex/process discovery and provides `GET /healthz`.
- Adds clean SIGINT/SIGTERM shutdown, configurable host/port, path traversal rejection and a launcher regression test.
- Leaves the v0.4.0 airline engine authority model unchanged.

## v0.4.0

- Adds a split Queue Fabric backend with Journey/Inventory, Booking and Operations authorities, following the service/authority pattern proven by FederationBank without importing banking semantics.
- Adds direct and one-connection airport-to-airport route construction; the explicit fixture proves GLA -> PIK -> EWR.
- Adds server-issued multi-leg offers with authoritative schedule/fare revalidation before inventory mutation.
- Adds a booking -> inventory -> booking-completion saga with separate booking/inventory idempotency keys.
- Adds retained inventory and booking projections with full fresh-runtime restart reconstruction.
- Denies the channel principal direct `PUT` access to the inventory commit queue.
- Adds bounded poison-message handling to `FLYLO.BACKEND.DLQ`.
- Adds hostile fare-tamper regression proving a client cannot turn an issued itinerary into a one-penny fare.
- Adds `FlyLoQueueOperationsAdapter`, composing the existing `FlyLoSalesProcess` over backend engines without moving airline authority into Wire UI.
- Keeps `FlyLoAS400OperationsAdapter` as the production host boundary; all new schedule/fare/capacity data is explicitly labelled `ENGINE_FIXTURE`.

## v0.3.1

- Compatibility repair for the reconciled Wire UI platform head.
- Normalises `json.cls` `JsonBoolean` values using `REQUEST("STRING")` at the FlyLo Wire UI boundary; browser ancillary checkbox selections now survive JSON decoding.
- Requalified against Wire UI Server v0.10, Alchemy Wire UI JS v0.4-dev4 and Queue Fabric Web Gateway v0.2.
- Expands the full-gateway fixture startup allowance for clean/fresh ooRexx class loading without weakening any runtime assertion.
- No pricing, booking, payment, legal or AI authority is moved client-side.

## v0.3

- Stateful Wire UI retail journey through SEARCH, OFFERS, PASSENGERS, EXTRAS, REVIEW, PAYMENT and CONFIRMED.
- Real Queue Fabric WebSocket full-booking + Ask FlyLo acceptance.
