# FlyLo v0.4.10

## v0.4.10 — durable airline runtime, Accounting Core v0.7 and Wire UI v0.17

FlyLo's package-root `./flylo` runtime is now durable. By default it stores authoritative development runtime state beneath `~/.flylo`; `FLYLO_DATA_DIR` selects another root. Queue Fabric booking/inventory projections and the native accounting book are persisted together, so a confirmed booking and its immutable passenger identities (`PAX-001...`) survive a launcher stop/start. This closes the failure where Manage Booking could appear to “lose” passenger rows after the process that created the booking had exited.

Durability is deliberately coupled: Queue Fabric state lives under `<data>/queue` and Accounting Core's append-only book under `<data>/accounting/flylo-stat.jsonl`. FlyLo retains normalized payment-capture events in Queue Fabric first and posts them to Accounting Core second. After restart, the native book is recovered first, current executable policies are registered, and retained Queue events reconcile as duplicates; a crash between source-event retention and accounting posting completes the missing transaction on recovery rather than creating two competing ledgers.

FlyLo now consumes **Accounting Core v0.7** while retaining the v0.4 precision/persistence contract: accounting packages operate under `NUMERIC DIGITS 50`, monetary minor units remain canonical integer strings, and the durable `AccountingFileStore` owns restart-safe journal identity/balance recovery. FlyLo's integration API advances to `flylo.accounting/0.4`. The newer v0.5-v0.7 scope/reporting, tax and settlement APIs are available to the platform but are not silently activated as airline tax/rounding policy.

Manage Booking also consumes **Wire UI Server v0.17 authoritative result revisions**. A servicing command is now bound not only to the exact query/scope/order/selection state and selected semantic passenger IDs, but also to the exact authoritative business result revision that was shown. If baggage/status/pricing results change while the same passenger remains selected, an old command context is rejected with `WORKSPACE_RESULT_REVISION_MISMATCH`.

`GET /healthz` and the visible page build badge report `0.4.10`, `wireUiServer=0.17`, `ACCOUNTING_CORE_0.7`, and durable runtime state. The one-command launch contract remains:

```sh
./flylo
```


## v0.4.9 — native accounting events, not booking-engine journals

FlyLo now consumes **Accounting Core v0.3** through its preferred operational transaction contract. Booking/Inventory/Payment remain operational authorities; they never write the general ledger directly. After explicit payment capture, FlyLo emits a normalized `accounting.event/0.1` projection onto a finance-only Queue Fabric topic. FlyLo's independent `AccountingEngine` resolves an exact effective-dated policy and executes `accounting.transaction/0.1` to produce an immutable journal.

Authorisation alone is not cash, settlement or revenue and therefore creates **no accounting journal**. A captured ticket payment posts **Dr card-processor receivable / Cr passenger-service contract liability**. Captured checked-bag consideration is a separate source event and separate journal. Neither becomes carriage/ancillary revenue merely because it was sold; revenue recognition remains deferred until performance evidence exists.

Every posted event retains the semantic policy ref plus an immutable executable `policyIdentity` derived from the SHA-256 identity of `FlyLoAccountingPolicyImpl.cls` and the exact event-policy configuration. Source-event replay/conflict is checked before current policy evaluation, preventing an old capture from being reinterpreted through a later accounting policy. Queue Fabric retains the normalized source projections so a fresh FlyLo accounting authority rebuilds the same book after restart.

The public `./flylo` path uses this same accounting authority: successful booking/ancillary responses expose capture/accounting status and journal identity, while browser/UI/model code never supplies journal lines, account numbers or accounting treatment.

## v0.4.8 — manage-booking lookup is a domain result, not an ooRexx crash

The public manage-booking path no longer turns `BOOKING_NOT_FOUND`/`BOOKING_NAME_MISMATCH` into passenger-visible `RUNTIME_CONDITION_88.900` diagnostics. The persistent ooRexx runtime decodes Queue-adapter domain rejection evidence, the HTTP boundary returns a privacy-preserving `BOOKING_LOOKUP_NOT_MATCHED`, and genuine runtime faults are logged server-side without leaking source positions. For a booking created in the current browser journey, **Manage these passengers** now opens the passenger workspace directly rather than asking the passenger to retype the reference.

Stateful FlyLo retail application on the Alchemy Wire UI / Queue Fabric platform.



## v0.4.7 — Wire UI v0.16 passenger workspaces are live

The public `./flylo` shell is no longer a static/demo action projection. Booking and manage-booking actions now enter the same package-root Node process, cross `/api/action`, are revalidated as Wire UI semantic actions by a persistent ooRexx `FlyLoWireApplication`, and then reach Queue Fabric-backed FlyLo engines. The development schedule/inventory/payment sources remain explicitly labelled fixture authorities; production AS/400/payment boundaries are not silently replaced.

Manage Booking is the first direct consumer of Wire UI Server v0.16 query/selection authority. Confirmed passengers receive immutable semantic IDs (`PAX-001`, `PAX-002`, ...). Looking up a booking creates `BOOKING.<ref>.PASSENGERS`; the browser may page/sort/select, but a servicing command must carry the exact server-minted workspace context (query/scope/order/selection revisions plus selected IDs). Sorting preserves semantic selection. Changed scope, stale revisions, omitted context, or forged IDs are rejected before `BOOKING.ADD_CHECKED_BAG` reaches FlyLo semantic dispatch.

Checked baggage is a separate idempotent booking-engine operation, not a rewrite of the original sale. The browser submits passenger selection, quantity and an opaque development payment token only. FlyLo prices the service authoritatively at the engine/controller boundary, obtains a separate payment authorisation, publishes the updated booking projection, and records ancillary-service evidence. Replaying the same workspace servicing identity does not duplicate baggage.

The browser search ceiling is now 99 rather than the old UI-level 9; Journey Engine inventory remains the authority on whether the requested party can actually travel together.

## One-command website launcher

Codex and humans start the FlyLo website with exactly one command from the package root:

```sh
./flylo
```

The launcher uses Node.js built-ins only; there is no Python web-server step and no second terminal to prepare. It prints one machine-readable ready line, normally:

```text
FLYLO_READY http://127.0.0.1:4173/
```

`FLYLO_HOST` / `FLYLO_PORT` or `--host` / `--port` may override the bind address when needed. `GET /healthz` is available for Codex/process probes. Ctrl-C or SIGTERM shuts the launcher down cleanly.

### Helpful Grok assistant — structured language first

The same `./flylo` process serves the passenger chat endpoint. If `XAI_API_KEY` is present, **Ask FlyLo** uses the Grok-authored ooRexx provider runtime in real time. Passenger chat never uses Grok Batch. The browser never receives the provider credential. Hidden application-state PII/payment fields are not injected into the model prompt; text the passenger deliberately types into chat is, necessarily, chat input.

FlyLo v0.4.10 does not let free-form model text drive airline actions. Each turn crosses a structured-language boundary:

```text
passenger text
   -> Grok strict JSON-schema interpretation (intent + typed slots; proposal only)
   -> FlyLoLanguageFrame (deterministic merge/date/location resolution)
   -> FlyLoAssistantOrchestrator (airline-owned decision)
   -> Journey/Booking/travel-information authority selected deterministically
   -> Grok strict JSON-schema response plan
   -> Structured Utterance v0.3 (lineage/intent/privacy, sealed)
   -> flattened passenger reply + optional flight-offer UI action
```

The model cannot issue a booking/inventory command. For example, on 28 August 2026 the sequence `29th` followed by `next month` deterministically becomes `2026-09-29`; once origin, destination, passenger count and trip type are also known, FlyLo queries its Journey Engine immediately rather than asking the passenger to authorise a lookup again.

### Larger parties are not a language error

Passenger count is preserved as typed structured state rather than constrained to the old retail 1-9 assumption. `can I book 10 tickets to new york` becomes `BOOK_JOURNEY`, destination `EWR`, passengers `10`; FlyLo then asks only for the missing origin/date/trip type. Once a search frame is complete, Journey Engine inventory decides whether enough seats exist. `NO_ITINERARY_AVAILABLE` is returned as airline search evidence and explained normally; it is not converted into a structured-runtime failure.

The ZIP vendors the exact Grok real-time, Structured Utterance, Queue Fabric, AI Access, Secret Broker, Alchemy, Crypto and Legal Effect source slices needed by the launcher/engine qualification, so Codex does not assemble a second backend by hand. See `docs/GROK_INTEGRATION.md` and `run_chat_tests.sh`.

### v0.4.5 structured-runtime hardening

v0.4.6 additionally closes the larger-party failure exposed by `can I book 10 tickets to new york`: the old 1-9 assumption is removed from language interpretation and journey search, and insufficient capacity is handled as ordinary inventory evidence.

v0.4.5 closed a deployment hole found by ordinary passenger turns such as `tell me about my booking` and `I want to fly to new york`. The structured assistant had been qualified against the supplied ooRexx 5.3.0 r13196 runtime but could still resolve a different host `json.cls` at launch. Because strict structured-output decoding depends on the r13196 JSON boolean semantics, that host-library drift could fail every assistant turn.

The package now vendors the exact compatible `json.cls` from the supplied r13196 distribution and prepends it to the child ooRexx runtime path. `./flylo` runs `tools/flylo_runtime_probe.rex` before declaring the assistant ready; the probe proves that JSON `true` can be emitted and decoded with the semantics expected by the structured bridge. The Grok structured provider now uses `.JSON~true` directly rather than repairing a serialized numeric boolean afterward.

Bridge failures are stage-labelled internally. A condition is logged server-side as a compact diagnostic code/stage/ooRexx condition/position, but raw runtime text is not shown to the passenger. For non-transactional continuity, FlyLo can still recognise a basic booking-help or flight-search request deterministically and ask for the next safe facts while marking the turn `degraded`. That continuity path cannot book, modify, pay, or mutate inventory. Exact ordinary-intent and injected-runtime-failure tests are release blockers.




FlyLo v0.4 adds a real backend-engine reference slice behind the existing retail journey.  The new Queue Fabric topology separates **Journey/Inventory**, **Booking**, and **Operations** authorities, adds multi-leg airport-to-airport routing, retained restart state, idempotent seat commitment, and a booking saga.

The v0.3.1 Wire UI/browser path is retained.  The browser is still an access point, not airline authority.

## v0.4 backend engines

```text
Wire UI / server-side sales process
        |
        v
FlyLoQueueOperationsAdapter
        |
        v
Queue Fabric
   +----+------------------+
   |                       |
Journey / Inventory     Operations
   |
   v
Booking completion saga
```

The reference fixture can now construct and sell a connected itinerary, for example `GLA -> PIK -> EWR`, and commits seat inventory on both legs exactly once.  Booking replay, fresh-runtime restart recovery, hostile fare tampering, direct channel-to-inventory access and poison-message handling all have executable regressions.

See `docs/ENGINE_ARCHITECTURE.md`.

v0.3 keeps FlyLo business, legal, operations, payment and AI authority in ooRexx objects and adds the long-lived `FlyLoWireApplication` that projects the sales process through Wire UI Server v0.10. The browser is a queue-connected semantic rendering access point rather than a second airline application.

## Authoritative journey

```text
SEARCH
  -> FLIGHT.SEARCH
OFFERS
  -> FLIGHT.SELECT
PASSENGERS
  -> PASSENGER.SAVE
EXTRAS
  -> ANCILLARY.SAVE
REVIEW
  -> SALE.REVIEW
PAYMENT
  -> PAYMENT.AUTHORIZE
CONFIRMED
```

`FlyLoWireApplication` advances the server-owned Wire UI journey through `WireUIApplication~advanceJourney()`. ACTIVE/PREFETCH/ON_DEMAND subscription planning and transition evidence therefore remain attached to the same authoritative journey; there is no browser or FlyLo shadow journey state machine.

## Wire UI projection

Builder v0.2 compiles exact versioned FlyLo definitions including search forms, offer collections, passenger and ancillary forms, review/payment surfaces, booking confirmation and the Ask FlyLo surface. Runtime instances are created only from definitions authorised by the current subscription plan.

The browser receives immutable definitions through subscription/caching and live snapshots/patches through direct queue traffic. Browser actions return semantic action names and the rendered revision.

## Ask FlyLo

`ASSISTANT.OPEN` and `ASSISTANT.ASK` remain semantic actions in the Wire UI architecture. The standalone `./flylo` public projection implements `POST /api/assistant` through the structured real-time Grok path above.

Server-side assistant session state contains a typed conversation frame rather than hidden model-owned booking state. Grok proposes structured understanding; deterministic FlyLo code resolves dates/locations and chooses the appropriate read-only airline or travel-information authority. Journey search evidence is separately identified as `FLYLO_JOURNEY_ENGINE_SEARCH`; post-booking servicing retains its own pending `serviceRequest` while immigration/customs questions use an independent `informationRequest`. The generated response is captured and sealed as Structured Utterance v0.3 before delivery. Hidden browser-state email/payment fields are excluded from model context; customer text typed into chat is treated as customer-provided chat content. No model output can commit inventory, create/change a booking, authorise payment or create legal/operational truth.

## Post-booking assistance and travel-rule evidence

A passenger saying “I booked a flight” moves the frame into `MANAGE_BOOKING`. Ancillary servicing is not treated as a fresh flight shop. An extra checked bag records `serviceRequest=ADD_CHECKED_BAG`; FlyLo asks only for the identifiers required to retrieve the booking (booking reference plus booking surname), not passenger count or one-way/return unless a later authoritative operation actually requires them.

Information questions are orthogonal. `IMMIGRATION_ENTRY` and `CUSTOMS_TOBACCO` can be answered while the bag request remains pending. Versioned FlyLo travel-information evidence uses official U.S. State Department, CBP and TSA sources checked on 2026-08-28. It keeps government admission/customs authority separate from airline carriage/baggage authority. For the reported example, the assistant can state that ordinary cigarettes are permitted in checked baggage by the cited TSA list, while separately explaining that duty-free purchase/checked-bag placement does not override customs rules and that the cited CBP tobacco exemption is for adults aged 21+. It does not infer a child’s allowance without an age or predict an immigration admission decision.

xAI structured output is enforced at transport level with `response_format.type=json_schema`, named schemas and `strict=true`, then parsed and validated again by FlyLo. The schemas are `flylo.assistant.interpretation/0.2` and `flylo.assistant.utterance-plan/0.2`.

## Transaction and authority boundaries

- offer selection resolves server-issued offer identity; the browser does not reconstruct fare truth;
- `saleId` is server-owned and browser-supplied sale identity is ignored;
- optional ancillary prices are calculated by the server sales process;
- payment receives an opaque payment-method token only;
- browser claims for total/currency are not authoritative;
- booking confirmation is projected only after backend booking authority reaches `CONFIRMED`; the production host path still requires the AS/400 booking host;
- production operations remain behind the AS/400 adapter boundary;
- Grok may explain/persuade within approved catalogue/policy context but cannot transact.

## Real gateway acceptance

The mandatory v0.3 runner includes a cross-process fixture using:

```text
Alchemy Wire UI JS v0.4-dev4
      <-> real WebSocket
Queue Fabric Web Gateway v0.2
      <-> same ObjectQueueManager
Wire UI Server v0.10
      <-> FlyLoWireApplication
```

It drives SEARCH -> OFFERS -> PASSENGERS -> Ask FlyLo -> EXTRAS -> REVIEW -> PAYMENT -> CONFIRMED. A DOM-compatible browser renderer harness executes the JS runtime in Node. This proves the real WebSocket and Queue Fabric/application boundaries; it is not represented as a Chromium result.

The fixture deliberately submits hostile browser values such as a false `saleId`, `totalMinor=1`, and `currency=XXX`. The authoritative sale remains £242.00 for the £199 fare plus £29 cabin bag and £14 seat selection and reaches `CONFIRMED`.

## Validation

v0.4 engine qualification passes under the supplied ooRexx 5.3.0 r13196 debug build with Alchemy Objects v0.8, Queue Fabric v0.9-dev4/ObjectQueueTopics, ooRexx Crypto v0.1 and Legal Effect v0.14.  The inherited v0.3.1 Wire UI surface remains unchanged; its historical full-browser qualification is retained in `VALIDATION.txt`.

The current 2026-08-27 roll-up does not contain Wire UI Builder v0.2, so this cut does not claim that the historical Builder/full-WebSocket suite was rerun from that roll-up alone. See `VALIDATION.txt` and `run_tests.sh`.

`run_engine_tests.sh` is the self-contained v0.4 backend qualification runner and does not require Wire UI Builder. `run_tests.sh` remains the inherited full-stack runner.

## v0.3.1 compatibility repair

- Accepts decoded `JsonBoolean` values at the Wire UI boundary using `REQUEST("STRING")` coercion, so browser checkbox true/false survives `json.cls` decoding.
- Qualified against the reconciled Wire UI Server v0.10 and Alchemy Wire UI JS v0.4-dev4 heads.
