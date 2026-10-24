# ooRexx Architecture Intentions v0.1-dev10

An **ooRexx-native, intention-driven architecture planner** for the Project
Alchemy stack. It accepts business scope statements and existing-estate facts,
asks questions rather than assuming a technology, models individual component
interconnects, enforces scoped ground rules, and exports a reviewable
non-executable architecture/build request. A future website is only a client.

## dev10: NotNotes publication request (2026-10-24)

`src/ArchitectureNotNotesPublication.cls` emits an immutable-by-value,
non-executable architecture publication **request** with optional verified
SSC evidence. NotNotes owns document identity, revision, access policy and
actual publication. There is no NotNotes write, no deployment and no
claim of production acceptance. See `docs/NOTNOTES_PUBLICATION_HANDOFF.md`.

The complete historical architecture source has been recovered from the
Library dev9 archive; `SSC_MANIFEST` now records source level 10. Native
r13196 qualification is still pending for the newly authored class.

## This release

## dev8: governed scenario promotion (2026-10-11)

`src/ArchitecturePromotion.cls` adds `ArchitecturePromotionReview` and
`ArchitecturePromotionWriter`. A design architect selects one immutable JSON
snapshot of a scenario comparison; the other options require explicit
REJECTED/DEFERRED/WITHDRAWN dispositions with evidence. A separate reviewer
records approval or refusal. Reviewer **names are claims**, not credentials:
`verifyApproval(trustedVerifier)` takes a host-injected authenticated policy
verifier and retains only a bounded proof reference.

- `handoff()` without a current comparison is always `DESIGN_ONLY_UNRESOLVED`.
- `handoff(currentComparison, trustedVerifier)` rejects a changed generation
  and revalidates external approval/policy authority on that handoff. It can produce
  `READY_FOR_SSC_REVIEW` only if the selected design has no issues, open questions,
  or unresolved external integrations, **and** approval is verified by the host.
- SSC gets a **request for resolution**, not a dependency lock, artifact choice
  or executable build. Deployment must separately qualify all targets and
  artifacts. No SSC or Deployment mutation is invoked by this package.
- Full unselected candidate plans and their review dispositions are retained.
  The writer emits five JSON files for unresolved designs, six if an SSC
  resolution request is eligible, without overwriting existing files.
- New negative tests reject self-approval, unreviewed alternatives, and stale
  plans; a synthetic fake verifier exercises only the API gate, **not** real
  signature/authentication qualification.

See `docs/GOVERNED_PROMOTION.md` and `examples/review_cats_options.rex`.


**dev7 adds governed cross-capability relationships.** The planner can link a
reputational observation to a case, a case to NotNotes document references, and
a legal review request to the external legal decision authority. Each link
records purpose, source/target ownership, typed source reference, optional
ConnectSelector edge, access/retention/failure controls, and outstanding
qualification. A relationship never copies record truth or adds a dependency
implicitly. Scenario output now includes a relationship ownership/status matrix.
The artifact writer adds `capability-relationships.json` (14 files total).


**dev6 adds business capability placement.** The architect now determines whether
legal, reputational, CRM, case, document, authentication, authorisation, privacy,
records, secrets, payments and communications capabilities belong in scope,
which existing Alchemy authority is a candidate, where it sits, and which
questions remain. No component becomes a runtime dependency until it is
explicitly required **and** placed. Authentication is modeled for each trust
boundary; Secret Broker is not assumed to be an identity provider.

Ground rules can require/forbid capabilities and specific owners, and scenario
comparison now includes a business capability placement matrix. An example is
`examples/cats_business_capabilities.rex`; the export includes
`business-capabilities.json`.

**dev5 adds the native architecture scenario-comparison engine.** The existing
ConnectSelector adapter remains read-only, and each local/cloud/RexxOS
MU/MI candidate is a separate plan over unchanged business scope and ground rules.
Changed interconnects invalidate transport guarantees; changed topologies invalidate
placement evidence. A JMS bridge remains an explicit separate qualification.

**dev4 added real ConnectSelector v0.1-dev1 integration.** Ordinary
service invocation is one of `DIRECT`, `RPC`, or `QUEUE` and its intended
operation and guarantee are explicit. `DIRECT` requires same-process placement.
JMS remains a separately qualified bridge with two directions, not a fictitious
fourth selectable provider. A read-only optional adapter calls the real
`ConnectSelector~explain()` method with injected connector registrations, never
`execute()`. Per-link policy matrices explain excluded alternatives.


- `ArchitectureDomainModel.cls`: stakeholder language, discovery facts,
  SUBJECT/PERSON/DEVICE/PRINCIPAL/SYSTEM/DATASET distinctions, relations,
  provenance, legacy inventories and scope questions.
- `ArchitectureGroundRules.cls`: revisioned rules for GLOBAL, ORGANISATION,
  CUSTOMER, PROJECT, SUBSYSTEM and LINK; cumulative `REQUIRE`, `ALLOW`, `DENY`
  rules, contradiction reporting and compliance control evidence gate.
- `ArchitectureInterconnects.cls`: per-edge patterns and DirectCall,
  JSON-RPC, Queue Fabric or JMS bridge bindings. Auth/delivery/recovery and transport-specific
  qualification questions; unresolved external adapters declared honestly.
- `ArchitecturePlanner.cls`: existing capability catalog and conditional
  decisions, RexxOS MU/MI network policy, cost assumptions/optimisation,
  features and component closure; integrates all new layers and distinguishes
  DESIGN-TIME architecture tooling from application dependencies.
- `ArchitectureIntentionAdapter.cls`: optionally integrates with Intention
  Service dev11, still dispatching architectural choices only after `READY`.
- `ArchitectureConnectSelectorAdapter.cls`: optional read-only evaluation against
  the actual `oorexx.connect_selector/0.1` API, no execution.
- `ArchitectureCapabilityRelationships.cls`: cross-domain authority-preserving references,
  governance, optional ConnectSelector edge mapping, and review questions.
- `ArchitectureScenarios.cls`: isolated, auditable local/cloud/RexxOS scenario variants,
  choice/interconnect/cost/operational matrices and independent build requests.
- `ArchitectureScenarioWriter.cls`: comparison JSON plus two artifacts per scenario.
- `ArchitecturePackageWriter.cls`: fourteen reviewable JSON artifacts, no
  installation, cloud acquisition, resolved dependency lock or compliance
  certification.

## Real interpreter qualification

The project's runtime target is ooRexx **5.3.0 r13196**, compatible with the
user-supplied `.deb`. To run without installing system-wide:

```sh
OOREXX_DEB='/path/to/oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb' \
INTENTION_SERVICE_ROOT='/path/to/oorexx_intention_service_v0.1-dev11' \
CONNECT_SELECTOR_ROOT='/path/to/oorexx_connect_selector_v0.1-dev2' \
  ./tests/run_environment.sh
```

Alternatively set `REXX_BIN`, `OOREXX_CLASSES` and `OOREXX_LIB` for an
already-extracted interpreter. The core resolves the runtime `json.cls` and
its own project classes via explicit `REXX_PATH`, not a vendored duplicate.

From the package root with ooRexx runtime paths configured:

```sh
rexx examples/cats_scope_and_policies.rex cats-discovery.json
rexx examples/connect_selector_choices.rex connector-example.json  # with selector src in REXX_PATH
rexx examples/generate_plan.rex rexxos-plan.json
rexx examples/compare_cats_scenarios.rex scenario-comparison.json
rexx examples/cats_case_and_legal_architecture.rex cat-case-design.json
mkdir -p /tmp/my-architecture-export
rexx examples/export_project.rex /tmp/my-architecture-export
```

The demonstration deliberately produces `NEEDS_DISCOVERY`: there is no basis
for choosing a 27-layer cluster from "I Love Cats" alone. `SPIRAL 1` is an
**example customer-named** compliance rule, not an invented external standard.

## Authority and safety

`INCONSISTENT` > `NEEDS_DISCOVERY` > `NEEDS_DECISIONS` >
`READY_FOR_DEPENDENCY_RESOLUTION`. The last state is **not** deployable.
Every candidate artifact has `resolutionStatus=UNRESOLVED` and a null digest.
Semantic Source Control and Deployment own exact dependency-lock selection,
artifact integrity, target qualification and deployment. No live resources
are commissioned and no laws or policies are claimed satisfied.

See `docs/CAPABILITY_RELATIONSHIPS.md`, `docs/ARCHITECTURE.md`, `docs/BUSINESS_CAPABILITY_PLACEMENT.md`, `docs/CONNECT_SELECTOR_CONTRACT.md`,
`docs/EXAMPLE_CATS.md`, and `docs/DECISION_TREE.md` for detailed contracts and choices.

## dev5 scenario output

A complete `ArchitectureScenarioComparison` projects local, cloud, and RexxOS MU/MI
variants over the same project and unchanged ground rules. Its output includes
`decisionMatrix`, `dependencyMatrix`, `interconnectMatrix`, `operationalMatrix`,
`costMatrix`, and per-variant non-executable plans/build requests. The example
proposes no prices, automatically qualified connectors, or preferred architecture.

For full usage and export examples see `docs/SCENARIO_COMPARISONS.md`.

## v0.1-dev10 — SSC evidence handoff

Adds the read-only `ArchitectureSscReceipt` and offline fake-authority test. It requires an external trusted SSC verifier; this module never fabricates a dependency lock or deploys a target. See `docs/SSC_HANDOFF_RECEIPT.md`.

## dev10 addition

Read-only NotNotes document publication request in `src/ArchitectureNotNotesPublication.cls`. This does not publish, modify or deploy anything.
