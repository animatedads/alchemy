# Architecture Intentions — design contract, 0.1

## Purpose

Produce an auditable architect's plan from high-level intent and progressively more concrete questions, using **existing Project Alchemy stack boundaries**. This is not an LLM generating arbitrary software packages or guessing binaries. A planner should be able to explain *why* each layer was chosen, what alternatives were rejected, which obligations remain, what can be reused, and what needs authority/qualification before a build.

## Ownership and component flow

```text
Human intent / website / CLI / NotNotes
        |
        v
Intention Service dev11                 <-- recognises / clarifies / confirms meaning
 UNKNOWN -> CLARIFY -> CONFIRM -> READY     (no unconfirmed dispatch)
        |
        v
Architecture Intentions (this module)   <-- project, feature, question, decision, rules,
        |                                    semantic architecture, explanatory tracing
        +--> Catalog providers             <-- component capabilities, contracts, options,
        |                                    topology and architectural policies
        +--> Network intention observations <-- XTP, Socket Provider, real path evidence
        +--> Cost/placement observations   <-- capacity, price quotes, legal residency
        +--> Project NotNotes model        <-- long-lived architecture document & relations
        |
        v
Governed Promotion review              <-- approved option, alternatives, current
        |                                    authority check, NO EXECUTION
        v
Architecture build request              <-- requested component/feature closure,
        |                                    target, reasons, pending checks, NO LOCK
        v
Semantic Source Control (SSC)           <-- authoritative component/source lineage,
        |                                    ::requires closure and source-level floors
        v
Deployment component                    <-- target capability probes, lock, artifact selection,
        |                                    ABI/native load probes, path construction
        v
Governed build / stage / qualify / deploy
```

**Authority is not interchangeable.** Recognition confidence is not authorisation. A semantic architectural choice is not proof of an available runtime. `::requires` is not a component version. A ZIP file name is not SSC source authority. A network route advertisement is not a PASS connectivity witness. A price hypothesis is not a supplier tariff. An architecture request is not a live deployment.

## Domain graph, not a rigid wizard

Every question has `id`, `section`, `options`, `required`, and an optional AND-of-memberships `when` predicate. A choice carries component capabilities to request (`adds`). Conditions are evaluated against recorded decisions; inactive descendants are suppressed from the *effective* architecture but retained in the decision history so exploration remains reversible. This is an initial typed, deterministic grammar; future extensions may add typed quantities, range constraints, policies, evidence expiration and versioned provider-supplied questions.

Top-level intent/deployment/front-end decisions activate downstream questions such as XTP carrier, MU/MI network reachability, cloud host/purchase strategy, storage replication, SQL personality, and restoration objective. The question set should be projected by the website instead of reimplemented as hard-coded forms.

Features are separate first-class objects with an ID, requested outcome, priority, acceptance criterion, accountable authority and optional known component requirements. They participate in the same semantic requirement closure and generate a why-selected trace.

## Where existing packages fit

| Layer | Existing authority | What the planner requests | What it must not do |
|---|---|---|---|
| Meaning and interaction | Intention Service dev11 | READY-gated, confirmed intent | Classify NLP itself or skip confirmation |
| Foundation | Alchemy Objects | Common object contracts | Vend copies of common classes |
| Presentation | Wire UI / native renderers | Browser/native view projection | Move UI truth into toolkit wrappers |
| External API | API Client / web edge | HTTPS/WebSocket access as appropriate | Equate browser network with MU/MI internal network |
| Semantic transport | XTP dev18 | Peer and multicast XTP capability | Claim path selection or health on intent alone |
| Socket acquisition | Socket Provider dev14 | Underlay/provider candidates | Instantiate transport implementations directly |
| MU/MI execution | RexxOS RTO2 Grid dev11 | MU/MI estate membership and reachability | Treat Grid as scheduler, memory or storage authority |
| Scheduling | Queue Fabric / Job-to-Node | Admission, placement, job delivery | Infer the live node allocation from architecture intent |
| Memory | Memory Fabric dev7 candidate | Capacity and large-block requests | Put large native DMA/shared blocks into XTP |
| Storage | Storage Fabric dev22 candidate | Namespace, placement, lifecycle/recovery requirements | Treat a metadata observation as a committed replica |
| Data | Native Database Backends / NoSQLServer / NotNotes | Typed data personality and continuity | Implement local DB parsing/JSON materialisation |
| Observability | Instrumentation Mesh | Instrumentation sources and evidence queries | Override authoritative resource/placement state |
| Security | Secret Broker | Principal, secret references and policy envelope | Include credentials in build requests |
| Dependencies | SSC + Alchemy Dependency Floor | Source and package contract closure | Guess versions from ZIP names or REXX_PATH order |
| Deployment | General Deployment | Qualified target, sealed/artifact lock, probes | Activate before authorization or a stable lock |

Versions in catalog are **candidate hints backed by observed materials**, not immutable locks. Source lineages, native ABI, target architecture, hashes and `::requires` must be rechecked against the exact selected release.

## MU/MI and network policy

RexxOS has first-class **Management Units (MUs)** and **Managed/Mesh Instances (MIs)**. In the current architecture, **MU↔MI semantic traffic must use XTP**. Plain TCP/ordinary UDP is not a substitute for that internal semantic contract. A choice of carrier is a separate, lower-level question:

- Pure L2 XTP using EtherType `0x817D`, only within the same qualified Layer-2 domain;
- native IP protocol 36 to route XTP between domains, if target networking/policy supports it;
- external UDP-encapsulated XTP is a *different carrier option*, not default permission to replace the internal XTP boundary; MU/MI internal use is blocked by this policy until governance is explicitly extended.

XTP semantic multicast is distinct from PIM-SM, IGMPv3, SSM and other network routing/membership services. Socket Provider and Network Transport Intentions own appropriate capability/observation projections. The planner requests those capabilities and must demand live/fresh provider evidence before Deployment.

Large MI/MU Memory Fabric block-bag payloads use native fenced shared-memory/DMA facilities; XTP may coordinate control, not carry those bulk bytes. Grid authority is identity/membership/reachability; Memory/Storage Fabrics own their respective resource truth.

## Cost and optimization

Architecture picks *optimization objectives*, not pricing facts. Cost resources are derived from active topology choices and quotes are accepted only with explicit `unitRate`, `monthlyQuantity`, currency, basis and provenance. Missing rates or mixed currencies make the estimate `INCOMPLETE`; otherwise it is `ASSUMPTION_ONLY`. There are no claims of real-time cloud-provider pricing or savings.

Potential optimisations (cloud reservation/interruptibility, region egress, reusing qualified MIs, tiered Storage Fabric) are expressed as comparisons with specified evidence required. Spot/interruptible capacity is blocked outside an explicitly safe-to-retry batch workload in this starter rulebook. Later provider adapters should supply typed `cost.quote/0.1` evidence, budgets, carbon, legal residency, life-cycle costs, P90/peak capacity, traffic egress matrices, recovery and licensing.

## Build request: contract and safety

Example entry fields:

```json
{
  "schema": "alchemy.architecture.build-request/0.1",
  "state": "READY_FOR_DEPENDENCY_RESOLUTION",
  "target": "rexxos",
  "buildLock": null,
  "executable": false,
  "activationRequested": false,
  "requirements": [
    {
      "componentId": "xtp",
      "resolutionStatus": "UNRESOLVED",
      "artifactDigest": null,
      "candidateVersion": "0.1-dev18",
      "selectedBecause": ["Decision deployment_model=rexxos_mu_mi"],
      "dependsOn": ["socket_provider"]
    }
  ]
}
```

This simplified example describes the shape; the actual request contains fuller component metadata. Real lock production requires SSC-manifest source-level/lineage authority, entry-package `::requires` closure, duplicate-file prevention, test vs runtime closure, target capabilities, native load probes, explicit REXX_PATH and artifact content hash. Only then can Deployment return a sealed, qualified, deployable build. The dev1 writer intentionally produces an unsealed handoff bundle and does not install it.

## Website projection — follow-on

The website should use read-only projections of the same underlying API: `GET_PROJECT`, `GET_NEXT_QUESTIONS`, `EXPLAIN_OPTION`, `GET_COMPONENT_FIT`, `GET_DECISION_TRACE`, `GET_COST_COMPARISONS`, `GET_BUILD_REQUEST`, `GET_QUALIFICATION_GAPS`. Mutations (`PROPOSE_DECISION`, `CONFIRM_DECISION`, `REQUEST_BUILD`) must carry a principal, project revision and authorization token; request builders must refuse stale revisions and unconfirmed changes. Wire UI/web edge owns rendering and browser-session mechanics. API Client / Queue Fabric or a governed gateway owns service exchange; the planner must not run a web server itself.

The visual view can be a progressive tree: intent → workload → execution/MU-MI → transport/carrier → capacity/memory → storage/continuation → DB/data → governance → economics → dependency closure. Every branch can expand `why`, evidence, incompatible alternatives and pending questions. No UI choice may silently set a high-risk infrastructure policy.

## Further increments

1. SSC adapter and real accepted-source artifact resolver, producing an immutable lock from a selected release; typed `::requires`/source-floor probes.
2. Intention Service discovery provider, entity/slot resolvers, semantic query vocabulary and revision-checked mutation events, beyond dev1's exact confirmed option phrases.
3. Read-only catalog adapters for current NotNotes stack graph, Grid/Socket Provider/XTP, Memory/Storage Fabrics and instrumentation; provider facts timestamped and differentiated from design decisions.
4. Cost quotes and objective modelling with actual region/provider pricing, Monte Carlo sensitivity, placement admission and legal/sovereignty policy.
5. Journaled persistent project state, multi-principal approvals, sealed plan snapshots, conflict/revision policy and incremental plan comparison.
6. Wire web client and APIs; then a governed build orchestrator, dependency archive materialization and live deployment tests.

## Qualification scope

This release is a native ooRexx architectural core plus an Intention Service adapter, not a complete compiler/release/deployment platform. It was tested with the supplied ooRexx 5.3.0 r13196 x86_64 debug runtime on Linux. No live cloud, NIC, hardware, native library, or MU/MI endpoint was provisioned or claimed tested. The writer is non-atomic and intended as a development-stage handoff; production publication should use the estate's durable-record/journaled filesystem semantics.

---

## dev3: scope-first architectural discovery and externally imposed ground rules

The domain-intake authority precedes infrastructure selection. A phrase such as
"I Love Cats business platform" is retained as an uninterpreted, sourced
statement. Before anyone suggests a 27-layer cluster, the architectural design
must ask about business outcome, existing estate (MySQL/flat files included),
actors and real principals, record of truth, expected scale, integration
boundaries, and operations. These are **scope facts**, not deployment choices.
A cat is a SUBJECT, not an implicitly authenticating PRINCIPAL. Actor-to-principal
and principal-to-subject relations must be explicitly modelled.

The scope, ground-rule and interconnect objects are ordinary ooRexx domain
objects, not HTML forms; website, NewShell and NotNotes clients can all project
the same structured objects. A sparse design remains sparse: catalog foundation
identifies DESIGN-TIME tooling; the build request contains only selected runtime
components plus actual transitive requirements.

### Ground-rule hierarchy

`ArchitectureGroundRules` records every rule's identifier, issuing policy,
revision, organisational authority, source and exact applicability scope:

- GLOBAL (all projects), ORGANISATION, CUSTOMER, PROJECT, SUBSYSTEM, LINK;
- `REQUIRE_CHOICE`, `ALLOW_CHOICE`, `DENY_CHOICE` constrain architectural decisions;
- `REQUIRE_BINDING`, `ALLOW_BINDING`, `DENY_BINDING` constrain interconnects;
- `CONTROL` records compliance obligations and the exact controls/assessments still needed.

GLOBAL/ORGANISATION/CUSTOMER/PROJECT constraints are **cumulative**, not
specificity-overrides. LINK/SUBSYSTEM binding constraints further narrow the
per-edge set. Impossible intersections become `ARCH_POLICY_CONFLICT` and
`INCONSISTENT` rather than silently choosing the more specific rule. Unknown
catalog decisions/options are explicit policy issues. Customer/organisation
rules require explicit project membership. An unattached customer rule does not
silently influence another customer's design. Exceptions or waivers must be
modelled as separately authorised governance actions in a later revision;
dev3 does not provide a bypass/waiver switch.

A policy named `SPIRAL 1` is **not** assumed to mean any particular regulation
or programme. It may be attached as a CONTROL rule, but it must carry the
customer's authoritative control catalogue, exact revision and assessor
evidence before claiming the policy has been addressed. Empty control sets
*always* generate a question even after a reviewer records a PASS. A recorded
PASS is an attributed assertion, not an independent certificate of compliance.
The planner never certifies compliance. Legal, regulatory and local approval
systems retain final authority.

### Each interconnect is an edge, not a global transport preference

`ArchitectureInterconnects` separates the interaction pattern from its binding:

| Concern | JSON-RPC | Queue Fabric | JMS |
| --- | --- | --- | --- |
| Baseline model | Remote request/response or notification | Queue and governed asynchronous work | Broker/message destination with JMS client |
| Role | API/adapter contract; does not select carrier | Existing Alchemy semantic component | External interoperability requirement; broker and adapter must be qualified |
| Essential questions | JSON-RPC version, carrier/server, auth, timeouts/retry | Auth, delivery/ack, recovery, backpressure, authority | Provider/broker, Java/interop, auth, delivery, selectors/correlation, recovery |
| Build output | Unresolved adapter requirement | Known component requirement passed to SSC | Unresolved adapter/provider/broker requirement |

Two edges in the same solution may legitimately use different bindings. The
engine cannot substitute JSON-RPC for queue execution or JMS for an XTP carrier
by simply renaming an interface. The guarantee register is intentionally reset
if a binding changes, because earlier evidence no longer proves the new model.

A `READY_FOR_DEPENDENCY_RESOLUTION` design is **not deployable**. SSC must
resolve exact source/package identities and Deployment must qualify target
capabilities and produce a pinned dependency lock. For JSON-RPC and JMS, the
unresolved integration adapter/provider contract remains explicit; the planner
does not invent existing Alchemy packages. No pricing or compliance
certification is inferred from design statements.

### Plan and publication schemas

The existing `alchemy.architecture.plan/0.1` now contains:

- `scope` (`alchemy.architecture.domain/0.1`): stakeholder statements,
  domain entities, relations and discovery facts;
- `groundRules` (`alchemy.architecture.ground-rules/0.1`): applicable hard
  policy rules, attested control evidence and review-only certification status;
- `interconnects` (`alchemy.architecture.interconnects/0.1`): per-edge
  integration models, proposed bindings and open guarantee questions;
- `buildRequest.designTimeTooling`: non-runtime planner infrastructure;
- `buildRequest.externalIntegrationRequirements`: integration proof/adapter
  requests for JSON-RPC and JMS, not purported package locks.

The writer emits ten JSON files into an existing empty directory: the prior
seven plus `scope.json`, `ground-rules.json`, `interconnects.json`.

A project with an unqualified business statement receives `NEEDS_DISCOVERY`
(priority below `INCONSISTENT`, above `NEEDS_DECISIONS`), even if somebody
clicked enough technology options to otherwise complete the design.

---

## dev4: ConnectSelector integration (actual v0.1-dev1 API)

ConnectSelector now owns route selection across `DIRECT`, `RPC` and `QUEUE`;
Architecture Intentions records operation/mode/assurance and policy per edge,
never picks sockets or dispatches a call. The optional read-only adapter calls
`ConnectSelector~explain()` with a concrete registry. A registered, eligible
provider is not a successfully executed call nor proof of live secure reachability.
No Queue enqueue receipt can be elevated to synchronous request/reply completion.
JMS remains an explicit two-way bridge over Queue Fabric with duplicate/recovery
risks, not a native fourth selector provider. Local DirectCall is rejected for
remote or same-host/different-process placements.

`ArchitectureGroundRules~bindingOptions(project)` now reports policy-admissible
and excluded bindings for each link, with governing rule/reason traces. Policy
permission is separate from runtime capability. `connectSelectorReviews`,
`interconnectAlternatives` and their exported JSON files make this distinction
available to browser, NotNotes and NewShell projections.

See `docs/CONNECT_SELECTOR_CONTRACT.md` and
`tests/test_connect_selector_integration.rex`.


## dev5: scenario comparison

`ArchitectureScenarioComparison` now composes `ArchitecturePlanner~plan()` for
multiple counterfactuals without altering the original project. Business scope,
scoped ground rules and component catalog are common to all candidates; choice,
connection, placement, operation mode and quote assumptions are per scenario.
See `docs/SCENARIO_COMPARISONS.md` for the object contract and guardrails.

## dev6 — business capability placement and trust enforcement

Architecture Intentions now owns the *question* of **where a business capability
fits** rather than treating legal, CRM, case, reputation, documents or
identity as arbitrary boxes on a feature checklist. The new business-capability
inventory carries observed and proposed candidate owner service IDs, layer,
limitations and unresolved architectural questions. Names or inventories **do
not** imply a service is required.

`ArchitectureCapabilityPlacement` maintains four independent authorities:

1. `assess(id, REQUIRED|NOT_REQUIRED|UNDECIDED, authority, rationale, evidence)`:
   explicit business scope of the capability;
2. `place(id, layer, ownerComponent|EXTERNAL, recordAuthority, boundary,
   architectAuthority, rationale, evidence)`: where the record of truth is
   proposed to live; candidates are not deployed or automatically validated;
3. `clarify(id, questionId, answer, authority, evidence)`: human/contract
   evidence for questions associated with a required domain; and
4. `protect(boundaryId, actorId, principalId, resourceId, operation,
   enforcementPoint, authenticatingAuthority, architectAuthority, rationale,
   evidence)`: per-trust-boundary security assertion, not a system-wide login
   checkbox. Authentication and authorisation remain distinct.

Selection is intentionally asymmetric. Adding a `REQUIRED` capability with no
placement asks an ownership question but adds **no package**. An explicit
placement on an internal catalog candidate adds that *component request* plus
existing dependency closure, still `UNRESOLVED` for SSC/Deployment. Choosing
`EXTERNAL` produces a separate integration/contract requirement. Revoking a
capability removes its now-unjustified placement and any associated answers.
No `UNDECIDED`, `NOT_REQUIRED` or unassessed capability inflates the runtime.

The first capability domains are legal, reputation, CRM, cases, documents,
authentication, authorisation, privacy/consent, record retention, secrets,
payments and communications. Their candidates were located in the Alchemy
portfolio, but are **candidate hints**, not runtime proofs. `Institutional
Policy` can express rules and evidence; lawyers or courts own legal conclusions.
`Relationship Case` coordinates cases; it does not own the underlying domain
legal effect. `Relationship CRM` owns relationship records, not account balances.
`Brand Interaction Effect` measures interaction outcomes, not independent truth
about public reputation. `NotNotes` owns document semantics, not all bytes,
legal signatures or storage durability. `Secret Broker` handles secrets, not
human or device authentication.

Policy kinds `REQUIRE_CAPABILITY`, `DENY_CAPABILITY`, `REQUIRE_CAPABILITY_OWNER`,
`DENY_CAPABILITY_OWNER` accept explicit scope and authority. They use the same
cumulative ground-rule mechanism as transport choice. Conflicts remain visible
and no policy silently decides a runtime package. For SPIRAL 1 and other named
external rules, the actual control set and independent reviewer evidence remain
required.

`ArchitectureScenario~placeCapability(...)` changes the proposed owner of an
already-required capability in one scenario without altering the business need
or original project. Scenario output includes `businessCapabilityMatrix` with
state, owner and layer per alternative. The 14-file architecture export includes
`business-capabilities.json` and the build request includes a separate
`businessCapabilityRequirements` array for external owners. The existing
`externalIntegrationRequirements` retains its transport/JMS meaning.

Capability decisions remain below Intention Service clarification/confirmation,
above SSC dependency resolution and Deployment target qualification. The
ConnectSelector handles eligible communication mechanisms between selected
services; it cannot decide which domain owns relationship, case, document,
legal or authentication truth. The web UI renders these records, never owns them.

### Authentication-coverage qualification

When authentication is scoped as `REQUIRED`, every explicitly declared
component link without a matching `protect(linkId, ...)` or attributed
`exemptBoundary(linkId, ...)` receives a `cap_auth_link_<id>` question. This
gives the website the exact places to ask about authentication; it does not
imply that every such link actually needs a second authentication handshake.
An exemption is only a design proposal and may not bypass a scoped
`REQUIRE_AUTH_BOUNDARY` or `DENY_AUTH_EXEMPTION` rule. Such a conflict appears
as `ARCH_POLICY_AUTH_EXEMPTION_DENIED` and blocks the plan. The declaration
of a protected boundary is not runtime evidence that an identity provider,
authoriser or link security control has actually been installed or tested.

Questions are presented with ground rules and business scope first, then
capability-placement questions, followed by technical choices. The original
request and decision history are retained for audit independently of this
presentation order.

## Cross-capability relationship graph (dev7)

`ArchitectureCapabilityRelationships` is a composition of independent domain capabilities. It records business handoff semantics, source-issued typed reference, policy and record authority, interconnect edge, access/classification and retention/failure decisions. It never moves authoritative record contents from CRM to a case, from NotNotes to legal, or from a case to the reputation register. A case can request qualified counsel action but cannot itself issue a legal conclusion. Scenario plans project one relationship graph across selected alternative owners, with no mutation of the baseline. See `docs/CAPABILITY_RELATIONSHIPS.md`.

ConnectSelector 0.1-dev2 strict route policy is authoritative for actual selection eligibility. The dev7 adapter remains read-only; without registered, policy-allowed, exact-destination routes, a proposal is not eligible. Dev1's historical permissive contract is tested separately. No production route is qualified here.
