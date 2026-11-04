# ooRexx Generalized Compute Intentions v0.1-dev8

A separate convenience/intention package in front of Generalized Compute, the
Job-to-Node/allocation authority, Work Load Units, and the existing router. It
turns a workload intention into a **planned admittance route** without acquiring
any of those authorities.

The package follows the same object-preserving semantic pattern used between
Customer Service/NotNotes and the LLM Coding Workbench/code-generation tools:
callers hand over native workload/context objects and receive native route,
resource and evidence objects. Internal objects are not flattened into command
prose and reconstructed later.

## dev8: RexxOS RTO2 Grid compute projection

`GeneralizedComputeRTO2Adapter.cls` now binds the documented
RTO2 Grid -> Generalized Compute Intentions compute projection.

```text
RTO2 estate controller
    |
    +-- MU members  -> estate/control membership only
    |
    +-- MI members  -> GCI compute candidates
                         |
                         +-- injected Grid eligibility policy
                         +-- exact memberId + incarnation recheck
```

The native RTO2 member object is retained inside
`RexxOSGridComputeResource`; it is not flattened into a hostname or endpoint.
An optional native `estateSnapshot` is retained as discovery evidence.

GCI deliberately does not define which RTO2 membership-state strings mean
usable compute. The owning Grid-side eligibility policy is injected. A
previously discovered MI is rejected as
`RTO2_MEMBER_ABSENT_OR_REINCARNATED` if the same member ID is no longer
present at the same incarnation.

Even a current MI is only compute-membership evidence. WLU admission,
Job-to-Node placement/lease, ACTIVE/SPARE ownership and execution remain
separate authorities.

Reviewed Library baseline: `rexxos_rto2_grid_v0.1-dev15.zip`, SHA-256
`e94ba156182567752e7e3b86e88b6a0e8a25fb8710648bb373a4c33271226543`.

## dev7: Instrumentation Mesh dev8 correlation

The optional observation adapter is now rebased to qualified Instrumentation
Mesh `v0.1-dev8` while retaining `instrumentation.mesh/0.1`.

GCI propagates explicit caller-supplied operational correlation fields into its
bounded plan/handoff event timeline:

```text
INSTRUMENTATION_EVENT_OBSERVED_AT
INSTRUMENTATION_CORRELATION_ID
INSTRUMENTATION_CAUSATION_ID
INSTRUMENTATION_CONTEXT_REFS
```

Those values are evidence organisation only. GCI does not infer correlation or
causation from timestamps, node/resource identity, common service kind,
severity, candidate order or proximity. Missing fields remain empty.

No workload body, prompt, credentials, source text, model input/output or
arbitrary resource object is placed in the event correlation fields.

## dev6: real AI Model Router composition

LLM allocation now has a concrete optional adapter over the existing
`ai.model.router/0.1` package rather than a provider-specific branch inside the
Workbench or GCI.

`GeneralizedComputeAIModelRouterAdapter.cls` lets an AI Model Router make one
policy/WLU-backed route decision over the complete model candidate set for a
single planning turn. The resulting `AIModelRouteCandidate`,
`AIModelRoutePlan` and `AIModelRouteOutcome` remain ordinary Rexx objects and
are retained as evidence.

The authority boundary is explicit:

```text
AI Model Router
  selects/permitted model route using authenticated WLU route evidence
  + institutional policy
        |
        | AI_MODEL_ROUTE_PERMITTED_NOT_ADMITTED
        v
Generalized Compute Intentions
  composes compute + allocation + WLU + router assessments
        |
        v
PlannedAdmittanceHandoff
  still requires fresh COMPUTE + ALLOCATION + WLU + ROUTER revalidation
```

AI Model Router still performs no Runtime Registry acquisition, WLU admission,
provider invocation, credential lookup or transport. GCI still performs none of
those either.

The planner core now supports optional `beginPlan()` / `assessForPlan()`
router methods. Their returned state is local to one `planAdmittance()` call;
there is no cross-turn router cache, so changed policy/WLU evidence is
rediscovered.

## dev5: truthful plan/admission boundary and Mesh dev7

The Library has advanced in two relevant places:

- `oorexx_instrumentation_mesh_v0.1-dev7` adds independent observation freshness,
  bounded `instrumentation.event/1` operational timelines, relationship
  observation and repaired bounded history semantics;
- `job_node_allocator_v0.6-network5` adds observational runtime reconciliation
  (`RUNNING`, `ABSENT`, `UNKNOWN`) while explicitly retaining placement/release
  authority in Job-to-Node and the owning execution framework.

This package adopts the same principle: **a plan is evidence, not entitlement**.
Every `PlannedAdmittanceHandoff` now explicitly reports
`revalidationRequired = .true` and names the four authorities which must be
rechecked before mutation: COMPUTE, ALLOCATION, WLU and ROUTER.

That is intentionally compatible with allocator network5's runtime rule: an
observation may explain reality, but observation never releases a lease or
manufactures completion.

## Planned admission boundary

```text
semantic workload intention
        |
        v
Generalized Compute Intentions
        |
        +-- Generalized Compute capability assessment
        +-- Allocation / Job-to-Node assessment
        +-- WLU admission assessment
        +-- Router assessment
        +-- Instrumentation Mesh observation (advisory only)
        |
        v
PlannedAdmittanceRoute
        |
        v
PlannedAdmittanceHandoff
        |
        |  revalidationRequired = true
        |  COMPUTE + ALLOCATION + WLU + ROUTER
        v
existing authoritative admission/allocation/router path
```

`PREPARE_ADMISSION` remains non-mutating. It does not reserve WLU, allocate a
resource, acquire/renew/release a lease, dispatch work, invoke an LLM, or claim
that the planned candidate still exists by the time the authoritative route is
entered.

## Instrumentation Mesh dev8

`GeneralizedComputeInstrumentation.cls` consumes `instrumentation.mesh/0.1` as
an optional adapter. The planner's own state remains usable without the Mesh.

Two observation dimensions are kept separate:

```text
source health            service/resource-owned observation
observation freshness    collector evidence about recency
```

A resource can therefore be `HEALTHY` and `STALE`. Staleness may influence
route preference, but it cannot revoke authoritative admissibility. Missing
publication time yields `UNKNOWN` freshness and is neutral rather than being
invented as a failure.

The caller supplies authoritative POSIX `now` through planning context when
freshness should be assessed:

```text
INSTRUMENTATION_NOW_POSIX_SECONDS
INSTRUMENTATION_FRESH_WITHIN_SECONDS   (default 30)
INSTRUMENTATION_STALE_AFTER_SECONDS    (default 120)
```

The adapter does not parse a local clock string or invent time authority.

The planner telemetry source now exposes both `snapshot()` and `events()`.
Bounded replay-safe Mesh events include:

- `COMPUTE_PLAN_STARTED`
- `COMPUTE_PLAN_COMPLETED`
- `COMPUTE_PLAN_FAILED`
- `COMPUTE_HANDOFF_PREPARED`
- `COMPUTE_HANDOFF_REFUSED`

Events contain bounded operational evidence only. They do not carry prompt
content, workload payloads, credentials, source text, model inputs/outputs or
arbitrary compute-resource objects.

## Intention Service and dynamic discovery

The optional `GeneralizedComputeIntentionServiceAdapter` remains aligned to the
Intention Service dev11 model:

- planner core is independent of Intention Service;
- Intention Service owns UNKNOWN / CLARIFY / CONFIRM / READY;
- non-READY dispatch is rejected defensively;
- dispatch replans against current compute/WLU/allocation/router state;
- registration/discovery never reserve or entitle resources.

`discoverFor(workload, context)` returns current operation descriptors. PLAN and
EXPLAIN remain meaningful if no route is presently admissible; PREFERRED_ROUTE
and PREPARE_ADMISSION report unavailable until a READY plan exists.

The provider advertises semantic relationships:

```text
WORKLOAD --requires--> COMPUTE_REQUIREMENTS
COMPUTE_REQUIREMENTS --satisfied_by--> COMPUTE_RESOURCE
WORKLOAD --admitted_by--> WLU
WORKLOAD --placed_by--> ALLOCATION
WORKLOAD --routed_by--> ROUTER
COMPUTE_RESOURCE --observed_by--> INSTRUMENTATION_MESH
```

These relationships support Management-style discovery but transfer no domain
authority.

## Qualification

```sh
OOREXX_DEB=/path/to/oorexx-5.3.0-13196...deb \
INSTRUMENTATION_MESH_ROOT=/path/to/oorexx_instrumentation_mesh_v0.1-dev8 \
INTENTION_SERVICE_ROOT=/path/to/oorexx_intention_service_v0.1-dev11 \
AI_MODEL_ROUTER_ROOT=/path/to/oorexx_ai_model_router_v0.1 \
WLU_ROOT=/path/to/oorexx_work_load_units_v0.12 \
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8 \
INSTITUTIONAL_POLICY_ROOT=/path/to/institutional_policy_v0.6 \
  ./tools/run_environment_test.sh
```

The semantic planning core has no hard external package dependency. Optional
integrations fail closed if their explicit `::requires` paths are not present.
