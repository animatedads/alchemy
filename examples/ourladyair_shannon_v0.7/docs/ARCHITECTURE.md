# Shannon v0.7 architecture

## Authority and evidence boundaries

```text
      FICTIONAL PNRGOV / EDIFACT BYTES
                     |
                     v
          STRUCTURED RELATION v0.9
   EdiFactDocumentContext + rich relations
       | source spans / groups / origins
       v
           ShannonBooking (sealed)
       /             |               \
      /              |                \
     v               v                 v
safety facts     passenger facts      seat facts
     |          role / eligibility   reserved / NSST
     +---------------+----------------+
                     |
                     v
               HardWorld world
                     ^
                     |
FERAL MODEL -> offer candidates -> loaded Legal Effect engine
   |                                 |
   |                                 v
   |                     explicit v0.5 compatibility
   |                         promotion objects
   |                                 |
   +----------- proposal ------------+
                                     v
                                  HardWorld
                                     |
                                     v
                           permissioned emission
```

The language model proposes. Structured Relation preserves source evidence. Booking objects state what the ticket evidence supports. Legal Effect evaluates norms. The promotion adapter explicitly projects legal conclusions into HardWorld. HardWorld owns the final action disposition.

## EDIFACT intake is not a Shannon string parser

`ShannonPnrGovParser` creates an `.EdiFactDocumentContext` and defines five rich relations through `.EdiFactRelationProvider`:

- `pnr_messages`
- `pnr_passengers`
- `pnr_ssr`
- `pnr_tickets`
- `pnr_information`

A passenger therefore retains `.EdiFactProjectedRow` evidence whose origin points back to the native EDIFACT source object/span. The booking retains the original document and envelope report.

The demo source deliberately contains non-EDIFACT `/* ... */` source annotations between segments and a deliberately invalid outer envelope. Structured Relation preserves the annotations and reports the envelope defects. Shannon does not pre-clean either fact away.

## Fact derivation

### Passenger role and age-restricted eligibility

DOB and raw passenger type are compared rather than blindly trusted. A contradiction fails closed to `UNKNOWN`.

This is visible in G01: Sean has an adult DOB but a raw `C` passenger type. Shannon does not quietly choose the convenient commercial interpretation; his target eligibility remains unresolved.

### Seat reservation state

The source-derived states are:

```text
SSR+SEAT -> RESERVED
SSR+NSST -> NOT_PURCHASED
INF/no-own-seat -> NOT_APPLICABLE
missing/conflicting -> UNKNOWN
```

Only `NOT_PURCHASED` can survive the Legal/HardWorld gate for the €20 reserved-seat product. The feral model is allowed to propose against `UNKNOWN`; policy P10 blocks it.

### Medication custody

MEDA/EpiPen evidence is retained as structured source evidence. When the IFT source states custody is unresolved, the world receives evidence-bearing `ESSENTIAL_MEDICATION`, `IMMEDIATE_ACCESS`, safety-relevance and UNKNOWN custody facts.

The IFT source contains a literal `+`; this is significant because `+` is an EDIFACT separator. Shannon checks the rich source segment lexical value, not just one scalar projection, so source meaning is not lost at the relation boundary.

## Target isolation

Every offer candidate is evaluated in a fresh target world snapshot. Target-specific facts include the product class and the passenger's authoritative role/eligibility/seat state.

An adult's eligibility cannot flow to a child. A scattered party cannot turn an already reserved seat into an unpurchased seat. The model has no mutation path into these facts.

## Legal identity and promotion

The engine identity and the HardWorld bridge identity are different facts. The
current validated bundle reports:

```text
engine API             legal.effect/0.10
engine build           0.10
promotion bridge       LegalEffectV05PromotionAdapter
bridge authority       LEGAL_EFFECT/0.5/...
```

Shannon does not hard-pin the engine API. It verifies and compiles its exact policy
with the loaded engine and records the engine identity. The `0.5` bridge namespace
is a separate explicit compatibility contract and is never renumbered to make the
identities look uniform. Compilation is not application; evaluation is not
promotion; promotion is not final selection.

## Revenue examples

- G07 `NSST` x3: €60 seat candidates survive + €30 adult bar candidates = €90 governed candidate revenue.
- G02 scattered but `SSR+SEAT` x5: €0 reserved-seat revenue; no double-sell.
- G03 two adults + teen: €20 governed bar revenue.
- G04 EpiPen + unresolved custody: model remains commercially active in audit, but governed commercial revenue is €0 until safety state is resolved.

## Audit

The audit object keeps the source document, envelope report, projected source evidence, legal identities/promotions, target HardWorld runs and the final emission. This is deliberately an object graph, not a CSV summary of conclusions.

## Queue/transport boundary

The current validation baseline is Queue Fabric v0.8.1 / API 0.8, whose release notes explicitly retain the accepted v0.7 queue/channel/transport/topic surface. `ShannonSocketGateway` only transports the ordinary queue payload across a process boundary:

```text
PASSENGER_TURN object
  -> QueueChannelFabric
  -> QueueSocketClientTransport
  -> authenticated TCP
  -> QueueSocketListener
  -> receiver channel
  -> SHANNON.INBOUND
  -> existing Shannon queue worker
```

Transport authentication establishes who delivered the queue envelope; it does not establish booking facts, customer consent, legal entitlement or transaction authority. Those continue through their existing evidence/governance paths.

## Audit SQL boundary

The full `ourladyair.shannon.turn.v3` object remains queued. `ShannonAuditCatalog` derives scalar `shannon_turns` and `shannon_offer_decisions` object relations for the loaded NoSQLServer (validated with v0.75). The projection is marked `DERIVED_INDEX_ONLY` and is therefore suitable for filtering/aggregation, not as a replacement evidence source.

This separation is intentional for future legacy terminal work: terminal observations and host objects may be rich and provenance-bearing while management queries can still ask conventional SQL questions about revenue, blocks and dispositions.


## Queue Fabric topic boundary

Topics are routing objects over queues, not a second state authority. `ShannonTopicBus` publishes rich governed-turn events under `ourladyair/shannon` and rich terminal observations under `ourladyair/terminal`. Revenue/safety/all-observer subscriptions are local broker wiring. The authoritative turn remains the Legal Effect/HardWorld result and the rich audit object; topic routing is labelled `DERIVED_EVENT_ROUTING_ONLY`.

The terminal topic is deliberately capability-neutral. A 5250 or PDP-10 terminal worker may publish an observation object, and retained replay can restore the latest observation to a new subscriber. No terminal observation is promoted to a booking/world fact merely because it arrived on the topic. Mapping/evidence and HardWorld promotion remain explicit later steps.

## Work Load Units boundary

Work Load Units v0.2 adds a fourth independent authority domain: resource
admission. Shannon and terminal workers emit native work facts; WLU policy values
and reserves them before host mutation. WLU is not currency and does not decide
what is legal or true.

```text
Shannon proposes terminal action
        |
        v
WLU reserve/admit (work + capacity only)
        | denied -> terminal untouched
        v
Terminal host mutation
        |
        v
WLU settle actual work

Legal Effect / HardWorld remain separate transaction authority.
```

The terminal acceptance uses the same fact vocabulary as the WLU package's native
terminal consumer (`FIELD_WRITE`, `AID`, `SCREEN_UPDATE`, `HOST_ROUND_TRIP`).
The WLU reservation retains its rate-card id/version so later policy changes do not
reinterpret already-admitted work.
