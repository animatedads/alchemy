# Changelog

## v0.7 - 2026-08-22

- Removed exact runtime release/API gates from Shannon. v0.6 rejected newer compatible companions before exercising the surfaces it actually used (for example Queue Fabric 0.8 versus an exact 0.7 check).
- Rebased validation to the clean `oorexx-libs(20260822-022521).zip` component set: HardWorld v0.19, Legal Effect v0.10, Runtime Registry v0.11, Queue Fabric v0.8.1/API 0.8, Structured Relation v0.9, NoSQLServer v0.75 and Work Load Units v0.2.
- Compatibility is now behaviour-gated: exact policy bytes must verify and compile/evaluate under the loaded Legal Effect engine; Queue/topic/transport/NoSQL and WLU operations must actually execute. Loaded identities are retained as audit evidence rather than used as startup passwords.
- Preserved the deliberately explicit HardWorld `LegalEffectV05PromotionAdapter` identity. A v0.10 Legal Effect evaluation still promotes through `LEGAL_EFFECT/0.5/...`; Shannon does not cosmetically relabel the bridge.
- Removed stale `LEGAL07-*` policy/reason labels from HardWorld overlay wiring.
- Added Queue Fabric API identity to queue audit metadata while retaining implementation version separately.
- Added `test_shannon_no_hard_release_gates.sh` so the exact anti-pattern cannot quietly return.
- Renamed queue/legal acceptance tests around compatibility and identity rather than old component release numbers.
- Updated dependency/root guidance so package paths are not semantically tied to historical versioned directory names.

## v0.6

- Added `oorexx_work_load_units_v0.2` as the resource-admission baseline.
- Added `ShannonWorkLoadGate` and `ShannonTerminalWorkController`.
- Terminal mutation is now demonstrably gateable by authenticated WLU admission:
  capacity denial occurs before `executeAID`; admitted work settles actual WLU.
- Preserved the authority boundary: WLU is work/capacity, not money, booking truth,
  Legal Effect, or HardWorld authority.
- Added `test_shannon_wlu_terminal_gate.rex` to the quick acceptance suite.
- Reworded the cryptographic test note to describe the consolidated verified-generation
  path rather than imply the normal suite necessarily takes minutes.

## v0.5 - 2026-08-21

- Advanced Shannon to **Object Queue Fabric v0.7** while retaining HardWorld v0.19, Legal Effect v0.7, Runtime Registry v0.8, Structured Relation v0.9 and NoSQLServer v0.74.
- Added `ShannonTopicBus` using Queue Fabric v0.7 topics as a routing/observation layer over ordinary object queues; topics do not become Legal Effect or HardWorld authority.
- Added hierarchical `ourladyair/shannon/...` publications with atomic per-publication fan-out to all-event, revenue and safety observer queues.
- Added explicit `DERIVED_EVENT_ROUTING_ONLY` audit metadata so topic observability is not confused with authoritative audit evidence.
- Added a `ourladyair/terminal/...` topic seam for the terminal-machine work. Rich terminal observations may be retained and replayed to late subscribers without inventing a Shannon-specific JSON API.
- Added retained terminal-observation acceptance using a structured IBM-i-style sign-on observation (`screen`, keyboard state and field object), including late-subscriber replay.
- Added Queue Topic NoSQL projection acceptance against **NoSQLServer v0.74**, despite Queue Fabric v0.7's packaged baseline documenting v0.73.
- Verified Queue Fabric v0.7 topic semantics (135 assertions), topic NoSQL projection (44 assertions), core queue acceptance (62 assertions), channel NoSQL (38 assertions) and transport NoSQL (27 assertions) under the supplied ooRexx 5.3.0 r13196 / NoSQLServer v0.74 environment.
- Retained the v0.6 authenticated TCP wire contract `queue.transport/1`; Shannon does not claim that v0.7 adds TLS/confidentiality or native remote topic federation.

## v0.4 - 2026-08-21

- Advanced the executable baseline to **Object Queue Fabric v0.6** and **NoSQLServer v0.74** while retaining HardWorld v0.19, Legal Effect v0.7, Runtime Registry v0.8 and Structured Relation v0.9.
- Added `ShannonAuditCatalog`: live NoSQLServer object-table projections `shannon_turns` and `shannon_offer_decisions` for management/audit SQL. The queued rich audit graph remains the authority; SQL rows are explicitly `DERIVED_INDEX_ONLY`.
- Added `ShannonSocketGateway`: authenticated Queue Fabric v0.6 TCP ingress using the existing queue/channel transport contract, HMAC-bound peer identity and the ordinary `SHANNON.INBOUND` trigger path. No chatbot-specific wire protocol was invented.
- Added a transport-isolation acceptance using a lightweight session stub so TCP framing/authentication can be tested without repeatedly paying Legal Effect SHA-512 compilation cost; separate real-Shannon acceptance proves governance.
- Added combined G01/G02/G03/G04/G07 acceptance that compiles the legal generation once and reuses it across the commercial/safety cases.
- Verified Queue Fabric v0.6 core/channel/NoSQL and socket security paths against NoSQLServer v0.74 despite Queue Fabric being originally validated against v0.73.
- Verified NoSQLServer v0.74 native SQLite/GeoPackage smoke under ooRexx 5.3.0 r13196.
- Removed ordinary `result` local usage from Shannon queue depth handling (`depthOperation`), following the same ooRexx special-variable discipline adopted upstream in Queue Fabric v0.6.

## v0.3 - 2026-08-20

- Replaced the crash-era ad-hoc PNRGOV parsing path with **Structured Relation v0.9**.
- Added `EdiFactDocumentContext` + `EdiFactRelationProvider` intake and explicit rich `pnr_messages`, `pnr_passengers`, `pnr_ssr`, `pnr_tickets` and `pnr_information` relations.
- Retained native EDIFACT document, envelope validation report, functional-group identity, source annotations, source spans and projected-row origin objects.
- Made the canonical source-preserving EDI example byte-identical to the Structured Relation v0.9 OurLadyAir PNRGOV fixture.
- Preserved the later compact user-supplied EDI as a second example and added a separate Structured Relation parse regression instead of silently reconciling its differing raw facts.
- Preserved the fixture's deliberately invalid outer envelope rather than silently repairing it.
- Fixed IFT custody extraction to use the rich source segment lexical value; this retains text after a literal EDIFACT `+` separator.
- Added PNR/ticket/DOB/PTC/seat/SSR evidence to sealed `ShannonBooking` / `ShannonPassenger` objects.
- Added rich Structured Relation evidence to HardWorld medication facts and v0.3 audit objects.
- Added €20-per-passenger reserved-seat candidates for authoritative `NSST` / `NOT_PURCHASED` targets.
- Added Legal policy P9 to prevent reserved/no-seat-applicable double-selling and P10 to fail closed on unknown seat status.
- Added G07 maximum-revenue acceptance: 3 adult bar bundles (€30) + 3 reserved seats (€60) = €90 governed candidate revenue.
- Added G02 no-double-sell acceptance: scattered seats are already `SSR+SEAT`, so seat-reservation revenue is €0.
- Added G01 contradictory passenger-type/DOB fail-closed acceptance.
- Added G03 teen alcohol-block acceptance.
- Added G04 EpiPen/custody acceptance proving rich Structured Relation evidence reaches HardWorld and governed commercial revenue falls to €0.
- Corrected Legal Effect identity handling: engine API is `legal.effect/0.7`, upstream build convenience constant remains `0.6`, and the validated HardWorld promotion bridge remains explicitly `LEGAL_EFFECT/0.5/...`; no cosmetic native-0.7 authority was invented.
- Removed Shannon-local copies of HardWorld Legal Effect promotion adapters. `run_rexx.sh` resolves the unmodified upstream HardWorld v0.19 integration files in their own package layout instead of shadowing/relabeling another package.

## v0.2 - 2026-08-20

- Advanced executable baseline to HardWorld v0.19, Legal Effect v0.7 and Runtime Registry v0.8.
- Added sealed authoritative booking/passenger objects.
- Added age-restricted eligibility separate from generic ADULT/CHILD booking role.
- Added feral `Beer + Crisps €10` candidate offers.
- Added target-scoped age controls and party isolation.
- Added per-target HardWorld evaluation and model-gross versus governed-gross accounting.
- Hardened deterministic safety paraphrase handling with explicit unresolved relevance.

## v0.1 - 2026-08-20

- Initial Shannon demonstrator: commercially feral model proposals constrained by deterministic safety facts, Legal Effect, HardWorld and Queue Fabric audit.
