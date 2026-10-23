# ooRexx Generalized Compute Intentions v0.1-dev5

A separate convenience/intention package in front of Generalized Compute, the
Job-to-Node/allocation authority, Work Load Units, and the existing router. It
turns a workload intention into a **planned admittance route** without acquiring
any of those authorities.

The package follows the same object-preserving semantic pattern used between
Customer Service/NotNotes and the LLM Coding Workbench/code-generation tools:
callers hand over native workload/context objects and receive native route,
resource and evidence objects. Internal objects are not flattened into command
prose and reconstructed later.

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

## Instrumentation Mesh dev7

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
INSTRUMENTATION_MESH_ROOT=/path/to/oorexx_instrumentation_mesh_v0.1-dev7 \
INTENTION_SERVICE_ROOT=/path/to/oorexx_intention_service_v0.1-dev11 \
  ./tools/run_environment_test.sh
```

The semantic planning core has no hard external package dependency. Optional
integrations fail closed if their explicit `::requires` paths are not present.
