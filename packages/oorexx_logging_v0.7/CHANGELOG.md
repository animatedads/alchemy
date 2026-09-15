# Changelog

## v0.7 — 2026-08-24

Seventh executable framework cut, continuing on
`oorexxapis(20260824-191406).zip` and focused on runtime incident activation and
self-inspection without adding control-plane work to the logging hot path.

- added atomic `addDormantRule()` and optional `addRule(..., initiallyEnabled)`;
- proved dormant lightweight-object rules create zero compiled plans and zero
  proxies until explicitly armed;
- proved benign calls through an armed selective proxy still create zero
  invocation/logger/event objects;
- proved an already-issued proxy performs zero plan work after its rule is
  disarmed, so proxy lifetime cannot preserve stale logging authority;
- added narrow `LogRuntimeControl` enable/disable facade for service, rules and
  targets with reason/actor provenance;
- added structured `LogControlEvent` journal independent from normal LogEvent
  delivery, so SERVICE DISABLE cannot recursively suppress its own control
  record;
- bounded the in-memory control journal (default 1024) and exposed dropped-count
  visibility;
- added `LogRuntimeSnapshot` plus structured service/rule/target/registration/
  plan status objects;
- added `LogRuntimeNoSQLAdapter` with fresh read-only snapshot tables for
  runtime, rules, targets, registrations, plans and control events;
- NoSQL raw rows retain actual underlying ooRexx rule/target/registration/plan/
  service/control objects instead of flattening them;
- executable test proves SQL UPDATE cannot bypass runtime control and mutate a
  logging rule;
- retained the full v0.6 performance, Institutional Policy, Alchemy v0.8,
  NoSQL event, Queue Fabric persistence, crypto-scope and locked-method suite.

## v0.6 — 2026-08-24

Sixth executable framework cut, rebased on `oorexxapis(20260824-191406).zip`.

- Rebased successfully on Alchemy Objects v0.8 and Institutional Policy v0.6;
  the complete v0.5 regression floor remains green.
- Added deployment-point-aware `LogPolicyBinding` using Institutional Policy
  topology/progressive resolution only at activation/refresh boundaries.
- Added persistent structured `LogDeploymentContext` carrying service, region,
  channel, tenant, cohort, exact deployment identity, stable route identity and
  bounded progressive-rollout authority identity.
- Separated historical deployment identity (contains evaluation time) from a
  stable route identity so `needsRefresh()` reacts to actual topology/lifecycle
  changes rather than clock movement.
- Added bounded progressive overlap/canary acceptance: ordinary cohort v1, PILOT
  cohort v2, global cutover to v2, and fail-closed atomic retention after rollout
  authority expiry. 1,000 runtime business calls perform zero policy-topology
  resolutions after activation.
- Added NoSQL deployment provenance columns while retaining the actual
  `LogDeploymentContext` object in raw rows.
- Advanced Queue persistence to `oorexx.logging.event/0.4`; added legacy
  event/0.3 recovery while retaining event/0.2 and event/0.1 compatibility.
- Added executable Logging-first / Alchemy-v0.8-second cooperative interposition
  test proving one physical wrapper and independent provider release.

## v0.5 — 2026-08-24

Fifth executable framework cut, rebased on `oorexxapis(20260824-162610).zip`
and focused on governed, effective-dated logging configuration without adding
policy work to the invocation hot path.

- added `LoggingPolicy.cls` integration with Institutional Policy v0.3;
- separated reviewed `LogRuleSpec` / `LogRuleSetPolicy` objects from mutable
  runtime `LogRule` objects;
- added effective-dated `LogPolicyCatalog` publication/resolution and
  `LogPolicyBinding` activation;
- added `nextTransition` / `needsRefresh()` lifecycle signals so a scheduler or
  Runtime Registry can refresh policy at configuration time instead of looking
  at the clock during application method calls;
- made an empty published rule set a valid reviewed OFF policy which removes
  compiled plans and restores original methods;
- kept Institutional publication authority distinct from Alchemy cryptographic
  `LOG_SCOPE_ESCALATE` authority; publication alone cannot authorize a
  cross-customer or other exact-scope log delivery;
- added canonical policy/rule semantic identities, deterministic set ordering,
  explicit identities for custom conditions, and fail-closed detection of
  post-seal mutation;
- added author/approver/publisher separation-of-duties publication tests using
  the real Institutional Policy authority evaluator;
- made policy handover atomic: a replacement which fails scope-capability
  validation leaves the previously active policy/rules installed;
- added policy id/version/exact identity provenance to `LogRule`, `LogEvent`,
  NoSQL projections, and durable Queue Fabric event state;
- moved the current persistent event type to `oorexx.logging.event/0.3` while
  retaining executable event/0.2 and event/0.1 recovery;
- explicitly kept SecurityEffect out of logging core to avoid a circular
  security-observability dependency;
- explicitly kept the current JMS bridge outside core logging delivery because
  its text-message boundary stringifies arbitrary payload objects; structured
  Queue Fabric delivery remains the native path;
- retained all v0.4 scope/domain, hot-path, NoSQL, Queue Fabric, Alchemy, crypto,
  proxy, interposition and crypto-locked-method regressions.

## v0.4 — 2026-08-24

Fourth executable framework cut, rebased on `oorexxapis(20260824-141327).zip`
and focused on structured security domains.

- added first-class `LogScope` objects carrying disclosure class, exact domain
  id, optional live subject, and bounded subject identity metadata;
- retained `.Log~PUBLIC/CUSTOMER/INTERNAL/SECRET` compatibility while adding
  `.Log~scope`, `customerScope`, `internalScope`, `secretScope`, and
  `normalizeScope`;
- changed compiled method/proxy indexes to use exact scope ids rather than bare
  disclosure rank;
- made same-rank cross-domain movement (for example customer A -> customer B)
  a cryptographically authorised operation;
- bound domain-bearing authorisations to exact `source_scope_id` and
  `delivery_scope_id` claims in addition to compatibility disclosure claims;
- added structured source/delivery scope and domain fields to `LogEvent`;
- moved durable event schema to `oorexx.logging.event/0.2` and added
  `oorexx.logging.scope/0.1`;
- retained backward recovery of legacy `oorexx.logging.event/0.1` objects;
- durable scopes retain bounded subject class/identity but intentionally do not
  serialize the live customer/security subject graph;
- expanded NoSQL projection with exact scope/domain metadata while preserving
  original `LogScope`, `LogEvent`, and payload objects through `rawAt()`;
- integrated Queue Fabric v0.9-dev4 security domains: a domain-bearing logging
  target must match the actual queue/topic `securityDomain` or fails closed;
- updated Queue Fabric test/runtime path for its new Alchemy dependency;
- verified coexistence with Alchemy Objects v0.7 execution provenance;
- retained all v0.3 hot-path, interposition, deferred payload, selective method,
  proxy, persistence, crypto and locked-method regressions.

## v0.3 — 2026-08-24

Third executable framework cut focused on hot-path correctness and reusable
interposition infrastructure.

- made read-only logging selection paths explicitly `UNGUARDED` so shared
  plans/conditions do not serialize unrelated ooRexx application calls;
- made diagnostic counters opt-in and compiled them out of condition-miss plans
  by default;
- added exact rule-predicate evaluation metrics for acceptance testing;
- added whole-rule-set `replaceRules()` with pre-publication validation and one
  plan-index rebuild;
- stale active loggers are prevented from emitting after their rule is replaced
  or removed;
- verified 1,001 compiled rules with zero unrelated predicate scans and exactly
  one selected predicate evaluation;
- added generic method-interposition provider priorities with reverse-order
  unwind and structural priority introspection;
- added executable priority/reprioritisation, metrics-opt-in, large-rule-index,
  rejected-replacement and stale-logger regressions;
- retained full NoSQLServer, Queue Fabric, Alchemy telemetry, crypto scope, and
  crypto-locked-method compatibility from v0.2.

## v0.2 — 2026-08-23

Second executable framework cut, retaining the v0.1 event and delivery model.

- added framework-neutral `MethodInterpositionParticipant` with one physical
  per-object/per-method wrapper and cooperative provider registration;
- removed the process-global `.local["OOREXX.LOG.RUNTIME"]` dispatch pointer;
- multiple independent `LogService` instances can now share one method wrapper
  and withdraw independently;
- provider lists are copy-on-replace snapshots for clean configuration/runtime
  separation;
- a logging condition miss allocates no interposition invocation object;
- pre-existing object-specific method layers are retained and restored;
- executable Alchemy interop proves logging can sit over existing Alchemy method
  telemetry and restore it intact on logging disable;
- added `log~logFrom(level, object, message, arguments, point)` deferred payload
  construction, including suppression after target disable;
- distinguished explicit `.nil` arguments from omitted ooRexx arguments;
- fixed positional condition handling for sparse `arg(1,"A")` Arrays using
  `HASINDEX` rather than `ITEMS`;
- added `OFF` level-name/accessor symmetry;
- added coordinated multi-service, propagated failure, deferred payload and
  argument-semantics regression tests.

## v0.1 — 2026-08-23

Initial executable framework cut.

- singleton no-op logger with `.Log` severity constants;
- compiled class/method/scope logging rules;
- conditional argument and object-path predicates;
- direct per-object `SETMETHOD` instrumentation through an ooRexx participant
  mixin;
- on-demand `UNKNOWN`/`SENDWITH` proxy path for lightweight objects;
- named start/stop points and entry/exit/error method points;
- global, rule and output-target enable/disable controls;
- Alchemy capability-authorised scope escalation;
- structured `LogEvent` objects retaining structured payloads;
- NoSQLServer live object-table projection;
- Queue Fabric direct and topic/subscriber targets;
- Queue Fabric persistent object-graph support for `LogEvent`;
- real Alchemy crypto-locked method logging test;
- performance and selective `WebsiteUI~generateCustomerPanel` acceptance tests.
