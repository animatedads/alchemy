# FlyLo Grok integration

## Passenger-facing structured chat

FlyLo v0.4.10 provides the current passenger assistant while keeping the canonical website command exactly:

```sh
./flylo
```

The same process serves the website and `POST /api/assistant`. There is no second web server, no Python runtime step, and no separately-started AI process.

The default credential mapping is:

```text
credential reference: xai-api-key
environment variable: XAI_API_KEY
```

The browser never receives the credential. `GET /healthz` reports configuration state, `transport=realtime`, `batch=false`, `structuredLanguage=true`, `structuredOutput=xai-json-schema-strict`, `structuredFrame=flylo.assistant.frame/0.2`, `structuredUtterance=structured.utterance/0.3`, and `toolAuthority=flylo-deterministic-orchestrator` without exposing the secret.

## Structured language is an authority boundary

Grok is used for language understanding and language generation. It is not used as an airline transaction engine and it does not decide which airline operation executes.

Each inbound turn follows this path:

```text
browser passenger text
    |
    v
POST /api/assistant
    |
    v
FlyLoGrokAssistant.interpretStructured()
    |  real-time Grok; xAI response_format=json_schema, strict=true
    |  proposes intent + typed slots only
    v
FlyLoLanguageFrame
    |  deterministic merge
    |  deterministic location aliases
    |  deterministic calendar resolution
    v
FlyLoAssistantOrchestrator
    |  airline-owned policy/decision point
    |  if search frame is complete, and only then:
    v
FlyLo Journey Engine SEARCH over Queue Fabric
    |  airline-owned read-only evidence
    v
FlyLoGrokAssistant.planStructuredResponse()
    |  real-time Grok; xAI response_format=json_schema, strict=true
    v
FlyLoStructuredReplyFactory
    |  Structured Utterance v0.3
    |  communicative act + generation intent + privacy + lineage
    |  seal before flattening
    v
passenger text + optional FLIGHT_SEARCH_RESULT UI action
```

The important separation is:

- **model interpretation** says what the passenger appears to mean;
- **FlyLo frame/orchestrator** owns deterministic state, date resolution and the decision to call an airline service;
- **Journey Engine** owns flight/fare/availability evidence;
- **Structured Utterance** records what the assistant is trying to communicate and where the information came from;
- flattened prose is delivery, not authority.

The model is therefore never handed an executable `SEARCH_FLIGHTS`, booking, inventory, payment or legal-effect capability. A malformed or imaginative model response cannot become an engine command merely because it contains convincing words.

## The reported booking conversation

With the FlyLo reference date `2026-08-28`, the structured frame evolves as follows:

```text
"I want to book a flight"
  intent = BOOK_JOURNEY

"Glasgow to New York"
  origin = GLA
  destination = EWR

"29th and 2"
  outboundDay = 29
  passengers = 2

"next month"
  monthRelation = NEXT_MONTH
  outboundDate = 2026-09-29

"one way please"
  tripType = ONE_WAY
  frame complete -> deterministic Journey Engine SEARCH
```

There is no second “would you like me to check?” permission loop. The fixture engine returns the available two-leg itinerary `GLA -> PIK -> EWR` on `FL201 + FL101`, £238.00 per passenger / £476.00 for two passengers, and the browser can render that engine-backed offer.

## Larger parties and inventory authority

A passenger count is valid structured language even when it exceeds the old nine-passenger retail assumption. For example:

```text
"can I book 10 tickets to new york"
  intent = BOOK_JOURNEY
  destination = EWR
  passengers = 10
  missing = origin, outboundDate, tripType
```

The xAI schema and `FlyLoLanguageFrame` preserve `10` exactly. When the remaining search facts arrive, Journey Engine performs the availability search. It may return an offer if every leg has enough seats, or `NO_ITINERARY_AVAILABLE` if route capacity is insufficient. The assistant maps that domain outcome to `SEARCH_UNAVAILABLE` evidence and explains it normally; a legitimate no-seat result is not an internal structured-runtime failure.

## Structured Utterance output

The final model response is not immediately treated as a string. `FlyLoStructuredReplyFactory` creates a Structured Utterance v0.3 object and records, where applicable:

- communicative act;
- intended act/register/outcome;
- customer-frame lineage (`DERIVED_FROM_CUSTOMER_FACT`);
- Journey Engine lineage (`DERIVED_FROM_EXTERNAL_DATA`, source `FLYLO_JOURNEY_ENGINE_SEARCH`);
- privacy classification;
- generation constraints including `AIRLINE_AUTHORITY_OUTSIDE_MODEL` and `STRUCTURED_BEFORE_FLATTENING`.

The utterance is sealed, then rendered to text for delivery. This preserves the distinction between semantic intent/evidence and its final prose representation.

## Real-time only — no Batch API

Passenger chat uses the Grok **real-time** `model.complete` path. It does not invoke Grok Batch, a Batch WLU planner, a deferred queue or a batch capability selector.

The self-contained launcher vendors `GrokProvider.cls` only from the Grok provider family. `GrokBatchProvider.cls` and `GrokBatchWLU.cls` are intentionally absent, and the chat qualification fails if a Batch source or `/v1/batches` reference appears in the passenger runtime.

The provider path is:

```text
FlyLoGrokAssistant
    -> FlyLoGrokStructuredProvider
    -> FlyLoGrokStructuredAdapter (subclass of GrokProviderAdapter)
    -> GrokProviderConfig + SecretBroker + GrokCurlTransport
    -> https://api.x.ai/v1/chat/completions
       response_format = json_schema, strict = true
```

The extension preserves the Grok-authored provider/secret/transport objects. It adds only the structured-output request envelope required by passenger language frames; it does not replace the Grok object with an unrelated HTTP client.

The ooRexx child invocation is an implementation detail owned by `./flylo`; Codex and the operator never start it separately.

## Privacy and server-side session state

`./flylo` holds a bounded typed assistant frame. Hidden browser application state is filtered before model invocation: passenger-list/email/payment-token fields are not silently injected. Text the passenger intentionally types into chat is sent as chat content and may contain names or other facts needed for the assistance they requested.

The Journey Engine evidence returned to the language layer is read-only. The current assistant cannot:

- reserve/commit seat inventory;
- create or cancel a booking;
- authorise or capture payment;
- alter operations truth;
- create legal-effect conclusions by assertion.

Those capabilities remain with their existing FlyLo authorities and would require separately designed and authorised workflows.

## Failure behaviour and runtime pinning

Missing `XAI_API_KEY` fails the assistant endpoint closed with HTTP 503 while the FlyLo website itself remains available. Provider failures do not silently switch to another model or to Batch. Invalid structured model output is rejected rather than interpreted as an airline command.

v0.4.5 also pins the exact compatible `json.cls` from the supplied ooRexx 5.3.0 r13196 distribution under `vendor/oorexx_stdlib_5.3.0_r13196/`. The launcher prepends that directory to the child `REXX_PATH` and runs `tools/flylo_runtime_probe.rex` before declaring assistant readiness. This prevents a different host standard-library version from changing the JSON boolean behaviour expected by strict structured-output decoding.

The bridge records its current stage (`INTERPRET_PROVIDER`, `INTERPRET_PARSE`, `ORCHESTRATE`, `RESPONSE_PROVIDER`, and so on). An internal ooRexx condition becomes a stable `FLYLO_ASSISTANT_INTERNAL_<STAGE>` code. `./flylo` logs a compact server-side diagnostic containing code, stage, condition and position, while the passenger receives no raw condition text and never sees the old `assistant structured runtime failed safely` string. For a small set of recognisable read-only intents, a deterministic degraded continuity reply may ask for the next safe facts. It cannot execute a booking, change a booking, mutate inventory, or authorise payment.

Qualification uses the exact supplied Grok v0.4 real-time provider/Secret Broker path with a deterministic local curl fixture; no live paid xAI request is claimed unless an actual credential is supplied to the environment. Exact regressions cover `tell me about my booking`, `I want to fly to new york`, `can I book 10 tickets to new york`, larger-party insufficient-inventory handling, and an injected internal ooRexx condition.

## Post-booking servicing is not flight shopping

The frame has two independent axes beyond intent:

- `serviceRequest`: `BOOKING_LOOKUP` / `ADD_CHECKED_BAG`;
- `informationRequest`: `BAGGAGE_RULES` / `IMMIGRATION_ENTRY` / `CUSTOMS_TOBACCO`.

`NONE` from a later language turn does not erase an already pending service request. Thus an immigration question can be answered while `ADD_CHECKED_BAG` remains pending. Booking servicing uses booking reference + family name as its lookup boundary; passenger count and trip type are not requested simply because the customer wants a bag.

`FlyLoTravelInformationAuthority` provides versioned, read-only evidence snapshots from official sources. The model is instructed to distinguish airline carriage/document checking from destination-government admission/customs decisions, to answer ordinary-cigarette checked-baggage questions directly from supplied security evidence, and to avoid treating duty-free purchases as customs-free. Child tobacco allowance questions become age-sensitive rather than assuming every passenger carries an adult allowance.
