# Changelog

## 0.1-dev8

- added a concrete optional RexxOS RTO2 Grid compute projection using the Grid's public estate-membership surface;
- only MI members are projected as compute candidates; MU members remain estate/control membership and are never treated as worker capacity;
- preserves the original RTO2 member object and optional estate snapshot as planning evidence;
- requires an injected Grid eligibility policy rather than inventing membership-state semantics inside GCI;
- rechecks exact member ID + incarnation before accepting compute-membership evidence, so a reincarnated or absent MI fails closed;
- retains the existing rule that Grid membership is not WLU admission, Job-to-Node placement, lease, ACTIVE/SPARE or execution authority;
- added regression coverage for MU exclusion, MI object identity, policy veto, incarnation fencing and dynamic rediscovery.

## 0.1-dev7

- rebased the optional observation integration to qualified Instrumentation Mesh v0.1-dev8 while retaining `instrumentation.mesh/0.1`;
- propagated only explicit caller-supplied event `correlation_id`, `causation_id`, `context_refs` and observation time into plan/handoff lifecycle events;
- deliberately does not infer correlation from timestamps, host/resource identity, service kind, severity, candidate order or event proximity;
- retained the existing privacy boundary: correlation metadata never includes workload/prompt/model/credential payloads;
- added a real dev8 regression to prove explicit propagation and absence of inferred correlation.

## 0.1-dev6

- added an optional concrete bridge to `ai.model.router/0.1` for LLM/model-route planning;
- added per-planning-call router state so whole-candidate-set authorities can evaluate once without global caching or per-candidate rerouting;
- retained the real `AIModelRouteCandidate` and router outcome objects as GCI evidence rather than flattening provider/model identity into text;
- a selected AI Model Router plan is labelled `AI_MODEL_ROUTE_PERMITTED_NOT_ADMITTED`: it is neither WLU admission nor executable/provider authority;
- missing router planning context fails closed and does not call the router;
- refreshed the Job-to-Node architectural baseline to v0.6-network6 without moving allocator authority into GCI.

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
