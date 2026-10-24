# Scenario Comparison — `architecture.scenarios/0.1`

## Design position

Architecture Intention scenarios are non-executable counterfactuals over **one** business project. One project can be assessed as a local-only service, a conventional cloud deployment, and a RexxOS MU/MI deployment without silently installing platform layers. The same business intake, functional requirements, organisational/customer ground rules, and original interconnect intentions apply to each candidate. Each scenario carries independently authored choices and links.

- `ArchitectureScenario` is a proposed variant with stable ID, authority, rationale, choice changes, per-edge bindings/placements/intents, optional JMS bridge, and typed (provenance-required) quotation assumptions.
- `ArchitectureScenarioComparison` copies the project's source decisions, business scope, features, rules, reviews and link state. It does **not** mutate the project of record. Changed topology invalidates old link-placement evidence; changed connector discards old connector guarantees. ConnectSelector is only ever asked `explain()`, if a real adapter was explicitly injected.
- `ArchitectureScenarioWriter` exports one comparison, and a distinct plan/build-request JSON pair per scenario, checking all output paths for preexisting files before attempting publication. Output is **not** an atomic sealed release.

## Sample API

```rexx
::requires 'ArchitectureScenarios.cls'

engine = .ArchitectureScenarioComparison~new(planner)
local = .ArchitectureScenario~new('local','Local pilot','Small workload','architect')
local~choose('deployment_model','local','No distributed requirement identified')
local~bind('cat-status','direct_call','Same-process callback')
local~place('cat-status','SAME_PROCESS','Topology proposal')
local~intent('cat-status','catChanged','NOTIFY','IMMEDIATE','local-handler', -
  'Notification only, no durable processing contract')
engine~register(local)

cluster = .ArchitectureScenario~new('rexxos','RexxOS MU/MI','Grid candidate','architect')
cluster~choose('deployment_model','rexxos_mu_mi','Qualified grid deployment proposed')
cluster~choose('deployment_target','rexxos','Required MU/MI target')
cluster~choose('xtp_carrier','l2','On-site L2 proposal')
cluster~choose('network_scope','same_l2','No routed L2 implied')
cluster~bind('cat-status','queue_fabric','Durable asynchronous event')
cluster~intent('cat-status','catChanged','ENQUEUE','DURABLE','cat-events', -
  'Queue admission distinct from consumer execution')
engine~register(cluster)

comparison = engine~compare(project)
```

JMS scenarios explicitly call `scenario~bridge('edge','JMS_TO_QUEUE',source,target,rationale)` or `QUEUE_TO_JMS`. This requests a JMS bridge **beside** the three native ConnectSelector providers (`DIRECT`, `RPC`, `QUEUE`), not a fabricated fourth provider. A changed endpoint contract requires new per-transport delivery and failure evidence.

## Output and qualifications

The `alchemy.architecture.scenario-comparison/0.1` document contains:

| Field | Meaning |
|---|---|
| `scenarios` | Complete individual architecture plans, status, open questions and issues |
| `decisionMatrix` | Exact effective question choices, blanks retained for unresolved choices |
| `interconnectMatrix` | Binding/placement and unqualified selector outcome per edge |
| `dependencyMatrix` | Which unresolved semantic components each scenario requires |
| `operationalMatrix` | Candidate topology, cost-optimisation hypotheses and verification gaps |
| `costMatrix` | Only scenario-supplied quote assumptions, with explicit missing quotes |
| `rankingStatus` | `NOT_QUALIFIED_FOR_AUTOMATIC_RECOMMENDATION` until external approval |

All scenario build requests remain `executable=false`, `buildLock=null`, and have no activation request. A missing cost model **cannot** be interpreted as zero running cost. Scenario quotes are never implicitly inherited from a different topology; `NO_COST_DRIVERS_MODELED` indicates there is no usable scenario cost estimate. Missing resources or mixed currencies prevent a monthly total. Comparisons do not presume which design is cheapest or certified compliant.

A scenario is a proposed design **not** the project's new truth. Promotion must be a separate, authenticated and revision-checked action once the business owner approves the alternative, policy controls are independently qualified, SSC seals the dependency closure, and Deployment verifies target and carrier readiness.

## Tested boundaries

The regression exercises untouched project state, requirement closure, local/JSON-RPC/Queue alternatives, stale placement and guarantee invalidation, explicitly changed queue operation mode, scenario-specific cost arithmetic, POLICY-scoped contradiction, separately qualified JMS bridge, semantic mismatch blocking, JSON parse roundtrip and overwrite refusal. This is not a claim about deployed brokers, cloud services, hardware or pricing.

## Relationship ownership comparison (dev7)

`capabilityRelationshipMatrix` projects the same named business handoff into each alternative. Source/target record authority and selected owner may differ; relationship purpose and scope do not change. This allows comparison of in-house case coordination with externally owned cases without mutating the underlying customer requirements. An external owner remains an unresolved integration, not a nonexistent internal package.
