# Changelog

## 0.1-dev5

- rebased the optional observability adapter from Instrumentation Mesh dev3 to dev7 while retaining `instrumentation.mesh/0.1`;
- separated source health from observation freshness (`FRESH`, `LATE`, `STALE`, `UNKNOWN`) and made stale telemetry preference-only evidence rather than service-failure authority;
- accepted only caller-supplied numeric POSIX time for freshness assessment; no local time parsing or invented clock authority;
- added bounded `instrumentation.event/1` lifecycle events for plan start/completion/failure and handoff prepared/refused;
- ensured event evidence excludes workload/prompt/model/credential payloads;
- made every `PlannedAdmittanceHandoff` explicitly require authoritative COMPUTE + ALLOCATION + WLU + ROUTER revalidation before any mutation;
- aligned that handoff rule with Job-to-Node v0.6-network5 runtime reconciliation, whose RUNNING/ABSENT/UNKNOWN observations never imply release authority;
- added regression coverage for fresh-vs-stale healthy resources, event timeline publication and the handoff revalidation contract.

## 0.1-dev4

- aligned the optional Intention Service integration with the current dev11 pattern used by Architecture Intentions dev6;
- added `GeneralizedComputeIntentionServiceAdapter` for fresh-service dynamic registration while keeping the planner core independent of Intention Service;
- added defensive `READY` guards to both registered and structured dispatch events;
- added dynamic operation descriptors: planning/explanation remain discoverable while route-dependent operations report current availability and reason;
- added typed relationship discovery for Workload -> Compute Requirements -> Compute Resource plus WLU, Allocation, Router and Instrumentation Mesh authority edges;
- retained fresh replanning at dispatch so staged/registered intentions do not turn discovery-time health, quota or capacity into authority;
- added standard Instrumentation Mesh rejected-request telemetry for refused planned-admission handoffs;
- added regression coverage for dynamic discovery, relationships, READY dispatch and Intention Service-shaped integration.

## 0.1-dev3

- added optional Instrumentation Mesh dev3 observation and telemetry adapter;
- resource observations can affect preference only, never admissibility;
- planner emits standard request lifecycle and compute-intention planning metrics.
