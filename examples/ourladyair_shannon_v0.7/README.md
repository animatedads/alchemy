# OurLadyAir Shannon v0.7

Shannon is a deliberately commercially feral airline chatbot demonstrator written in ooRexx.

The model is encouraged to maximise ancillary revenue. It does **not** own booking facts, source evidence, Legal Effect, HardWorld state, or the final passenger-visible action.

v0.7 removes release-number gating from Shannon's runtime boundaries.  The current
project bundle was validated with **Legal Effect v0.10**, **Runtime Registry v0.11**,
**Queue Fabric v0.8.1 / API 0.8**, **Structured Relation v0.9**, **NoSQLServer
v0.75**, **HardWorld v0.19** and **Work Load Units v0.2**.  Shannon records those
loaded identities as evidence, but it does not reject a component merely because
its release string changed.  Compatibility is established by exercising the
required object/API behaviour and by the acceptance suite.


## Work Load Units v0.2 — work, not money

Shannon now has an explicit resource-admission seam for the terminal systems that
will sit behind the chatbot. `ShannonWorkLoadGate` consumes the real
`work.load.units/0.2` API. A terminal action is described as native facts such as
`FIELD_WRITE`, `AID`, `SCREEN_UPDATE` and `HOST_ROUND_TRIP`; the WLU authority
values and reserves those facts before the terminal is allowed to mutate host state.

This authority is deliberately narrow:

- WLU is normalized **work**, never euros/pounds or ancillary revenue;
- WLU can refuse work because entitlement/capacity/throughput is unavailable;
- denial occurs before `executeAID`, leaving the terminal untouched;
- rate-card id/version remain attached to the admitted work;
- WLU cannot make a product lawful, alter Structured Relation evidence, override
  Legal Effect, or select a HardWorld action.

The acceptance test deliberately exhausts a shared WLU capacity bucket, proves that
Shannon cannot press ENTER, releases the capacity, then proves one admitted ENTER
settles the expected 0.6 WLU. This is the intended seam for the real TN5250 and
PDP-10 terminal workers.

## Core inversion

```text
EDIFACT bytes
    |
    v
Structured Relation v0.9
  EdiFactDocumentContext
  source annotations / groups / spans
  rich projected rows
    |
    v
Authoritative ShannonBooking facts
    |
    +----------------------------+
    |                            |
    v                            v
feral model proposals       Legal Effect (loaded engine)
    |                       sealed normative evaluation
    |                            |
    +-------------> explicit promotion bridge
                                 |
                                 v
                         HardWorld v0.19
                                 |
                                 v
                        permissioned emission
```

The model can keep proposing beer, crisps, bags and reserved seats. Those proposals are evidence, not authority.

## Structured Relation is the EDI boundary

`src/ShannonPnrGovParser.cls` uses the real Structured Relation v0.9 EDIFACT implementation:

- `.EdiFactDocumentContext` parses and validates the source;
- `.EdiFactRelationProvider` defines explicit `pnr_messages`, `pnr_passengers`, `pnr_ssr`, `pnr_tickets` and `pnr_information` relations;
- relation projections retain their rich `.EdiFactProjectedRow` origin objects and source spans;
- source annotations and `UNG`/`UNE` functional-group identity remain available;
- the deliberately invalid outer demo envelope remains `INVALID`; Shannon does not silently repair it;
- `ShannonBooking` retains the source document, envelope report, adapter identity and rich per-passenger evidence.

Two EDI examples are shipped deliberately:

- `examples/ourladyair_shannon_ticket_groups_v1.edi` is byte-identical to the full source-preserving OurLadyAir fixture shipped by Structured Relation v0.9. It preserves the full comments/annotations and the deliberately contradictory Sean PTC/DOB evidence from the pasted demo.
- `examples/ourladyair_shannon_ticket_groups_v1_compact.edi` is the later compact EDI upload unchanged. Structured Relation parses that too; it carries fewer annotations and slightly different raw source facts, so it is tested separately rather than silently normalised into the full fixture.

This matters in practice. The G04 IFT annotation contains a literal `+`, an EDIFACT data-element separator. Shannon therefore inspects the rich source segment lexical value rather than pretending a single projected scalar contains the complete annotation. The custody warning survives because the source object survives.

## Maximum revenue, bounded by facts

### Beer + Crisps — €10

The scripted model proposes a `Beer + Crisps €10` bundle to **every passenger**. Each target is evaluated independently.

Booking role and age-restricted eligibility are separate facts:

- `ADULT` is not automatically proof of age-restricted eligibility;
- `INELIGIBLE` blocks the alcohol bundle;
- `UNKNOWN` fails closed;
- an eligible adult does not transfer eligibility to another passenger.

The ticket fixture exercises this directly:

- **G01**: Aoife is unambiguously eligible; Sean has a raw PTC/DOB contradiction and fails closed; the children/infant are blocked. Model gross €50, governed bar gross €10.
- **G03**: two adults plus 16-year-old Ife. Model gross €30, governed bar gross €20.
- **G05**: clean adult path, subject to the authoritative eligibility fact.
- **G06**: teacher plus three minors; alcohol remains target-scoped to the adult, never sprayed across the school party.

### Reserved seats together — €20 per passenger

Seat sales use authoritative SSR evidence, not the model's opinion about whether the existing seats are ugly.

- `SSR+SEAT` -> `RESERVED`: do **not** charge for another seat reservation.
- infant/no-own-seat -> `NOT_APPLICABLE`: do not sell a seat.
- `SSR+NSST ... SEAT NOT PURCHASED` -> `NOT_PURCHASED`: Shannon may propose the €20 reserved-seat product.
- `UNKNOWN` -> model may still propose, but Legal Effect blocks emission until the fact is resolved.

This creates the deliberately revenue-happy G07 result:

```text
3 adults
3 x Beer + Crisps @ €10      = €30
3 x reserved seat @ €20      = €60
-----------------------------------
governed candidate revenue   = €90
```

The G02 stag party is scattered across 3A / 7C / 11E / 18F / 24A, but every member already has `SSR+SEAT`. Shannon therefore gets **€0 seat-reservation revenue** from G02. “They are not together” is not permission to double-sell a seat reservation.

## Safety still owns the gate

G04 is the useful collision: a split family, a child with an EpiPen, a 10 kg bag that may be gate-checked, and unresolved custody.

Structured ticket evidence enters HardWorld as rich evidence-bearing facts. While custody is unresolved:

- commercial candidates remain visible in audit;
- governed commercial gross is €0;
- `NEEDS_INFORMATION` wins;
- the passenger sees the safety/custody path, not the latent sales proposal.

So maximum-revenue Shannon remains commercially enthusiastic without being authoritative.

## Legal Effect identity — do not make the numbers prettier

Shannon no longer treats a particular Legal Effect API number as a startup
password.  It records the exact loaded engine API/build identity, verifies the
operator policy bytes, compiles the policy through that engine, and exercises the
HardWorld promotion contract.  If those operations are incompatible they fail
closed at the operation which is actually incompatible.

The current clean bundle validates:

```text
loaded engine API      legal.effect/0.10
loaded engine build    0.10
promotion bridge       LegalEffectV05PromotionAdapter
promotion authority    LEGAL_EFFECT/0.5/<generation>@...
```

The last line remains deliberately `0.5`.  It identifies HardWorld's explicit
compatibility bridge contract and is **not** relabelled to match the loaded Legal
Effect engine.  Conversely, the engine's `legal.effect/0.10` identity is retained
in turn/audit evidence and is never inferred from the bridge namespace.

Legal Effect v0.10 also adds source-authority attestation requirements for *live
Runtime Registry acquisition*.  Shannon's present fictional operator policy is
compiled and used locally/offline; v0.7 does not claim that this local test policy
has passed a live source-authority trust profile.

Shannon does **not** vendor or patch HardWorld promotion adapter classes.
`run_rexx.sh` executes from the supplied HardWorld `integration/` directory so
its unmodified relative `::REQUIRES` resolve against the HardWorld package.

The test `test_shannon_legal_identity_and_promotion.rex` proves:

```text
Legal evaluation alone  != HardWorld mutation
explicit promotion      -> evidence-bearing HardWorld facts
HardWorld disposition   -> permissioned passenger emission
```

See `docs/LEGAL_EFFECT_IDENTITY_NOTE.md`.

## Legal policy v3

`policy/ourladyair_safety_policy.txt` is fictional OurLadyAir policy. Exact bytes are SHA-512 pinned, the source and every provision are verified, and Legal Effect compiles generation `OURLADYAIR-SHANNON-LEGAL-G3`.

The ten provisions cover:

1. unsafe medication/bag custody blocks commercial actions;
2. mandatory custody warning;
3. unresolved recognised safety relevance fails closed;
4. complaint/sales separation;
5. model output has no governance authority;
6. age-restricted product blocked for an ineligible target;
7. unknown age eligibility fails closed;
8. party eligibility never transfers between passengers;
9. reserved/no-own-seat passengers cannot be double-sold a reserved seat;
10. unknown seat-purchase status fails closed.

## Rich audit object

The v0.7 turn audit retains, as objects rather than CSV-shaped strings:

- passenger input and original feral model proposal;
- model/prompt identity;
- source format and `structured_relation_plugin/0.9` adapter identity;
- EDIFACT source document and envelope report;
- source annotation count and parser identity;
- passenger PNR/ticket/DOB/PTC/seat state;
- rich Structured Relation projected source evidence and source paths;
- Legal Effect API/build/generation/semantic identity;
- promotion authority for each legal evaluation;
- HardWorld world and action dispositions;
- candidate and governed commercial plans;
- model gross and governed gross;
- final permissioned text.

Queue Fabric transports the rich turn/audit object without flattening the evidence boundary.


## Queue Fabric: remote ingress without inventing a chatbot protocol

`ShannonSocketGateway.cls` uses the loaded Queue Fabric channel contract and authenticated TCP transport.  The current validation target is API `queue.fabric/0.8` from v0.8.1, which explicitly retains the accepted v0.7 channel/transport/topic surface. A remote producer sends the same `PASSENGER_TURN` object that a local caller would put into `SHANNON.INBOUND`; the normal trigger then calls Shannon.

```text
remote client
   |  HMAC-authenticated Queue Fabric TCP
   v
SHANNON.INBOUND
   |
ordinary queue trigger
   v
Shannon -> Legal Effect -> HardWorld
```

The transport identity binds manager, receiver channel, principal, key id, nonces and exact graph-codec envelope bytes. Shannon does not turn those facts into a second source of booking/legal authority. Queue Fabric provides authentication/integrity only; Shannon makes no TLS/confidentiality claim.

This is deliberately useful for the forthcoming terminal/legacy-host work: a terminal worker can live in another process while the application boundary remains an object queue rather than a bespoke JSON RPC invented for the demo.

## Queue Fabric topics: observation without authority leakage

`ShannonTopicBus.cls` uses the retained topic layer while preserving the queue primitive underneath it. Shannon publishes a governed-turn event to `ourladyair/shannon/turn/governed`, then a classification event to either `revenue/permitted` or `safety/suppressed`. Subscriptions fan those rich objects into ordinary observer queues.

```text
Shannon governed turn
        |
        v
ourladyair/shannon/...
        |
        +--> SHANNON.EVENTS.ALL
        +--> SHANNON.EVENTS.REVENUE
        `--> SHANNON.EVENTS.SAFETY
```

The audit explicitly labels this `DERIVED_EVENT_ROUTING_ONLY`. A topic delivery can help monitoring, analytics or downstream workflows; it cannot change Legal Effect, HardWorld or the already-governed passenger emission. Per-publication fan-out inherits the loaded Queue Fabric UOW all-or-none delivery semantics.

A second topic root, `ourladyair/terminal`, is intentionally prepared for the terminal-machine project. A terminal worker can publish the rich observation object it actually obtained from a 5250, PDP-10 console or another terminal session. Current observations may be retained so a later subscriber receives the last known observation as an object graph, including fields/cursor/session metadata, rather than a flattened screen string.

This is **not** yet an assertion that terminal observations are authoritative booking facts. Structured Relation / capability-specific mapping and HardWorld still determine what an observation means and whether any resulting action may occur.

The current Queue Fabric v0.8.1 line retains the authenticated transport used by Shannon and adds distributed topic interest propagation. Shannon v0.7 does not depend on, or claim authority from, that newer distributed-topic feature.

## NoSQLServer: query the audit without flattening the evidence

`ShannonAuditCatalog` creates two live object-table projections:

- `shannon_turns` — session/turn, state, legal generation, model gross, governed gross and final text;
- `shannon_offer_decisions` — target-scoped product, price, legal status, HardWorld disposition and permitted flag.

These are **derived management indexes**. The original nested audit object remains in `SHANNON.AUDIT`, including Structured Relation rows, source documents, Legal Effect objects and HardWorld results. The audit records the projection authority as `DERIVED_INDEX_ONLY`.

Example:

```sql
SELECT product_class,target_passenger_id,price_cents,legal_status,permitted
FROM shannon_offer_decisions
WHERE product_class='BAR_BUNDLE'
```

This is the intended flattening boundary: SQL gets inspectable scalar relations; source evidence remains rich objects.

## Dependencies

The current clean project bundle used for v0.7 validation is:

- `virtual_ryta_hardworld_v0.19`
- `legal_effect_v0.10`
- `runtime_registry_v0.11`
- `oorexx_queue_fabric_v0.8.1` (API `queue.fabric/0.8`)
- `structured_relation_plugin_v0.9`
- `nosqlserver_v0.75`
- `oorexx_work_load_units_v0.2`

These are **validated companions, not exact release locks**. Shannon records loaded
identities and exercises the surfaces it requires. See `DEPENDENCIES.txt`.

## Running

Tested with Open Object Rexx 5.3.0 r13196.

```bash
export HARDWORLD_ROOT=/path/to/virtual_ryta_hardworld_v0.19
export LEGAL_EFFECT_ROOT=/path/to/legal_effect_v0.10
export RUNTIME_REGISTRY_ROOT=/path/to/runtime_registry_v0.11
export QUEUE_FABRIC_ROOT=/path/to/oorexx_queue_fabric_v0.8.1
export STRUCTURED_RELATION_ROOT=/path/to/structured_relation_plugin_v0.9
export NOSQLSERVER_ROOT=/path/to/nosqlserver_v0.75
export WLU_ROOT=/path/to/oorexx_work_load_units_v0.2

./run_rexx.sh tests/test_shannon_queue_compatibility.rex "$PWD"
./run_rexx.sh tests/test_shannon_topic_bus.rex "$PWD"
./run_rexx.sh tests/test_shannon_pnrgov_parse.rex "$PWD"
./run_rexx.sh tests/test_shannon_pnrgov_compact_parse.rex "$PWD"
./run_rexx.sh tests/test_shannon_ticket_g07_max_revenue.rex "$PWD"
./run_rexx.sh examples/shannon_ticket_demo.rex "$PWD" G07
```

The default suite is deliberately consolidated so one verified Legal Effect generation covers the main commercial/safety scenarios:

```bash
./run_tests.sh quick
```

For the historical one-test-per-process regressions as well:

```bash
./run_tests.sh full
```

The Legal Effect source verification is deliberately pure and cryptographic. `full` therefore repeats expensive SHA-512 verification in independent processes; `quick` is the normal acceptance path.

## Deliberate boundary

This is an executable governance demonstrator using fictional OurLadyAir tickets and policy. It is not a live airline sales system and it makes no claim about Ryanair's private backend or prompts.
