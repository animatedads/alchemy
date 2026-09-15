# ooRexx Logging v0.7 API map

## Core constants

`.Log~TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`, `OFF`

`.Log~ENTRY`, `BODY`, `EXIT`, `ERROR_POINT`

`.Log~PUBLIC`, `CUSTOMER`, `INTERNAL`, `SECRET`

Both active and null logger objects also expose the level names as methods,
including `OFF`, for dynamic or crypto-locked package scopes.

## Structured scopes

Compatibility disclosure constants are still accepted wherever a scope is
required. Since v0.4 the API additionally accepts `LogScope` objects:

```rexx
publicScope   = .Log~scope(.Log~PUBLIC)
customerScope = .Log~customerScope("CUSTOMER-77", customerObject)
internalScope = .Log~internalScope("LOG-INTERNAL" [, subjectObject])
secretScope   = .Log~secretScope("OPS-SECRET" [, subjectObject])
normalized    = .Log~normalizeScope(scopeOrDisclosure [, domainId [, subject]])
```

`LogScope` exposes:

```rexx
scope~disclosure
scope~domainId
scope~scopeId
scope~subject
scope~subjectClass
scope~subjectIdentity
scope~rank
scope~equivalent(otherScope)
scope~requiresAuthorityTo(otherScope)
scope~metadata
```

`scopeId` is the disclosure value for an unqualified scope and
`DISCLOSURE:domainId` for a domain-bearing scope. Domain ids are exact values;
they are not case-folded. `subject` may be any live ooRexx object. Queue
persistence retains bounded subject class/identity metadata but intentionally
does not serialize that live subject graph.

## Deployment context

`LogDeploymentContext` is a bounded value object carried by runtime rules and
events. It deliberately has no dependency on Institutional Policy.

```rexx
context~serviceId
context~regionId
context~channelId
context~tenantId
context~cohortId
context~pointIdentity
context~deploymentIdentity
context~routeIdentity
context~rolloutIdentity
context~metadata
```

`deploymentIdentity` is exact historical Institutional deployment evidence at
activation time. `routeIdentity` is the stable cache/lifecycle identity used to
detect actual topology changes without treating clock movement as a change.
`rolloutIdentity` identifies the bounded progressive-overlap authority when one
is operative. The object implements Queue Fabric persistence as
`oorexx.logging.deployment-context/0.1`.

## Service

```rexx
service = .LogService~new(serviceId [, capabilityAuthority [, controlJournalLimit]])
service~addTarget(target)
service~addRule(rule [, escalationCapability [, initiallyEnabled]])
service~addDormantRule(rule [, escalationCapability])
service~replaceRules(ruleArray [, capabilityTable])
service~enableRule(ruleId [, reason [, actorId]])
service~disableRule(ruleId [, reason [, actorId]])
service~enableTarget(targetName [, reason [, actorId]])
service~disableTarget(targetName [, reason [, actorId]])
service~enable([reason [, actorId]])
service~disable([reason [, actorId]])

log = service~loggerFor(receiver, methodName, arguments, nativeScope)
registration = service~registerMethod(receiver, methodName, nativeScope)
service~unregisterMethod(receiver, methodName)
objectOrProxy = service~proxyIfRequired(receiver, nativeScope)
service~enableMetrics
service~disableMetrics
metrics = service~metrics
rules = service~rulesSnapshot
targets = service~targetsSnapshot
registrations = service~registrationsSnapshot
plans = service~plansSnapshot
controlEvents = service~controlEvents
```

`registerMethod` requires the target object to inherit
`LogInstrumentationParticipant`. `proxyIfRequired` does not.

`replaceRules` is the bulk/atomic configuration route. It validates the complete
Array before publication and recompiles the runtime indexes once. For rules that
cross an exact security scope, the optional capability Table/Directory is keyed
by rule id. Diagnostic metrics are disabled by default so counters do not become a
hidden condition-miss cost.

`addDormantRule()` validates the rule (including exact crypto scope authority)
but publishes it disabled before any plan/index rebuild, so there is no transient
window in which instrumentation becomes active. The optional third
`addRule()` argument provides the same atomic initial-state control.

`LogService` keeps a bounded structured control-change journal. The default
limit is 1024; `controlJournalLimit` and `controlEventsDropped` are inspectable.
The `actorId` on a control event is caller-supplied provenance only and is not a
substitute for Alchemy capability verification.

## Runtime control and inspection

`LoggingControl.cls` provides a narrow operational object:

```rexx
control = .LogRuntimeControl~new(service)
control~enableService(reason, actorId)
control~disableService(reason, actorId)
control~enableRule(ruleId, reason, actorId)
control~disableRule(ruleId, reason, actorId)
control~enableTarget(targetName, reason, actorId)
control~disableTarget(targetName, reason, actorId)
snapshot = control~snapshot
```

A `LogRuntimeSnapshot` contains structured service, rule, target, registration,
compiled-plan and control-event rows. Snapshot rows retain the underlying
objects; they are not configuration strings.

For NoSQLServer:

```rexx
adapter = .LogRuntimeNoSQLAdapter~new(service [, tablePrefix])
result = adapter~query("SELECT rule_id,class_name,method_name,operational FROM log_rules")
```

The runtime adapter creates a fresh snapshot for each `query()`. Its object
tables are intentionally read-only. SQL mutation is not an operational control
API; mutations must pass through `LogRuntimeControl` so wrapper/plan lifecycle
and structured control journalling remain coherent.

## Rule

```rexx
rule = .LogRule~new( -
    ruleId, component, className, methodName, -
    sourceScope, deliveryScope, minimumLevel, -
    condition, targets, points [, startPoint [, stopPoint [, registrationKind]]])
```

`targets` and `points` are Arrays. Conditions are objects implementing
`matches(receiver, arguments)`.

`sourceScope` and `deliveryScope` may be compatibility disclosure strings or
`LogScope` objects. `rule~requiresAuthority` is true whenever the exact source
and delivery scope ids differ, including same-rank cross-domain transitions.
For domain-bearing transitions the Alchemy capability must carry exact
`source_scope_id` and `delivery_scope_id` claims in addition to the compatibility
disclosure claims.

Runtime rules materialised by `LogPolicyBinding` also expose `policyId`,
`policyVersion`, and `policyIdentity`; emitted `LogEvent` objects carry those
fields beside the rule and cryptographic authorisation identities.

## Governed logging policy

`LoggingPolicy.cls` requires Institutional Policy v0.6 and provides a fixed,
reviewable configuration layer above runtime `LogRule` objects.

```rexx
spec = .LogRuleSpec~new( -
    ruleId, component, className, methodName, -
    sourceScope, deliveryScope, minimumLevel, -
    condition, targets, points [, startPoint [, stopPoint [, registrationKind [, conditionIdentity]]]])

policy = .LogRuleSetPolicy~new( -
    policyId, version, ruleSpecArray, -
    effectiveFrom, effectiveUntil, authoredBy, approvedBy [, supersedes])~seal

catalog = .LogPolicyCatalog~new([metadata [, sealer [, authority [, resultClass [, authorityEvaluator [, lifecycleEvaluator [, deploymentEvaluator]]]]]]])
catalog~publish(policy [, publicationRequest [, progressiveRequest]])

binding = .LogPolicyBinding~new(service, catalog, policyId [, deploymentPoint])
binding~setDeploymentPoint([deploymentPoint])
resolution = binding~activate([atTime [, capabilityTable]])
binding~needsRefresh([atTime])
binding~nextTransition([atTime])
binding~clear
status = binding~status
```

`LogRuleSetPolicy` directly satisfies the `InstitutionalPolicyCatalog` protocol.
Its rule set may be empty; an empty operative policy deliberately removes all
runtime rules for that binding. Runtime rules are freshly materialised at
activation so enabling/disabling a `LogRule` does not mutate the reviewed
policy object.

The policy semantic identity is canonical across rule insertion order and
set-like target/point order. Built-in logging conditions have deterministic
policy identities. A custom condition must provide `SEMANTICIDENTITY` or
`CANONICALTEXT`, or the `LogRuleSpec` must be constructed with an explicit
reviewed `conditionIdentity`. A sealed policy rechecks its canonical identity
before materialisation and fails closed if referenced state changed after seal.

Institutional publication authority and logging-scope capability authority are
independent. `catalog~publish()` may enforce Institutional Policy author,
approver, publisher, evidence, delegation, succession and emergency rules.
`binding~activate()` still passes every materialised scope-crossing rule through
`LogService~replaceRules()`, which requires the exact Alchemy crypto capability.

`needsRefresh`/`nextTransition` are lifecycle helpers; the logging hot path does
not query the policy catalog or current clock. With Institutional Policy v0.6,
activation may resolve deployment topology/progressive overlap for a supplied
service/region/channel/tenant/cohort point. The selected route is compiled once
and copied into `LogDeploymentContext`. `activate()` is a handover
boundary: policy/binding state is updated only after `LogService~replaceRules()`
has accepted the entire materialised rule set, so a failed crypto or validation
check leaves the previously active rules in service.

## Emitter

```rexx
log~log(level, payload [, point])
log~logFrom(level, producerObject, producerMessage [, producerArguments [, point]])
log~point(pointName [, payload [, level]])
log~enabledFor(level [, point])
log~active
```

`logFrom` is the deferred-payload route. It sends `producerMessage` to
`producerObject` only if the event is currently deliverable. This is the
preferred form for expensive diagnostic construction because normal ooRexx
message arguments are evaluated before `LOG` receives them.

## Conditions

```rexx
.LogConditionAlways~new
.LogConditionArgNil~new(argumentIndex)
.LogConditionArgOmitted~new(argumentIndex)
.LogConditionArgPathContains~new(argumentIndex, messagePathArray, needle [, caseless])
.LogConditionAny~new(conditionArray)
.LogConditionAll~new(conditionArray)
.LogConditionNot~new(condition)
```

`ArgNil` matches only an explicitly present `.nil` argument. `ArgOmitted`
matches an absent argument position. `ArgPathContains` follows the selected
argument by sending each named zero-argument message in the path.

## Cooperative method interposition

`LogInstrumentationParticipant` inherits `MethodInterpositionParticipant`.
The latter is framework-neutral and owns the one physical object-method wrapper.

```rexx
slot = object~__methodInterpositionAdd(methodName, providerId, interceptor [, priority])
object~__methodInterpositionRemove(methodName, providerId)
status = object~methodInterpositionStatus([methodName])
```

An interceptor supplies:

```rexx
interceptor~before(receiver, methodName, arguments)
interceptor~after(receiver, methodName, token, result)
interceptor~failure(receiver, methodName, token, conditionObject)
```

`BEFORE` returns `.nil` when that provider is inactive for the invocation. The
coordinator does not allocate a `MethodInterpositionInvocation` until at least
one provider returns a token. Lower numeric provider priorities run `BEFORE`
first; equal priorities preserve registration order. `AFTER`/`FAILURE` unwind in
reverse provider order. `methodInterpositionStatus()` includes provider priority
metadata.

Applications normally use `LogService~registerMethod`; the lower-level
interposition API exists so other ooRexx framework components can cooperate
without independently stacking `SETMETHOD` wrappers.

## Targets

```rexx
.LogMemoryTarget~new(name, scope)
.LogQueueDirectTarget~new(name, scope, queueManager, queueName [, principal [, options]])
.LogQueueTopicTarget~new(name, scope, topicFabric, topicName [, principal [, options]])
```

Queue targets pass `LogEvent` objects, not rendered lines. If the target scope
has a domain id, the real Queue Fabric queue/topic must have the same
`securityDomain`; mismatch is rejected before submission.

## NoSQL adapter

```rexx
adapter = .LogNoSQLAdapter~new(memoryTarget [, tablePrefix])
adapter~registerInto(objectDatabaseEngine)
result = adapter~query(sqlText)
```

SQL-visible columns are metadata projections, including
`source_scope_id`, `source_domain_id`, `delivery_scope_id`,
`delivery_domain_id`, `policy_id`, `policy_version`, `policy_identity`,
`deployment_service_id`, `deployment_region_id`, `deployment_channel_id`,
`deployment_tenant_id`, `deployment_cohort_id`, `deployment_route_identity`,
and `deployment_rollout_identity`. `DatabaseRow~rawAt()` retains the original
`LogEvent`, payload, source/delivery `LogScope`, and `LogDeploymentContext`
objects.

Runtime/configuration inspection is provided separately by
`LogRuntimeNoSQLAdapter` in `LoggingControl.cls`; it exposes `runtime`, `rules`,
`targets`, `registrations`, `plans`, and `control_events` tables as fresh
read-only snapshots and likewise preserves the actual underlying objects in raw
row values.

## Queue persistence

```rexx
.LogQueueSupport~registerPersistentTypes(queueCodecOrTypeRegistry)
```

This registers `LogScope`, `LogDeploymentContext`, current
`oorexx.logging.event/0.4`, and legacy `oorexx.logging.event/0.3`,
`oorexx.logging.event/0.2`, and `oorexx.logging.event/0.1` decoders. Current
events persist policy provenance, structured deployment/rollout provenance,
and the separate cryptographic `authorisation_id`. It
is required before recovering a durable
queue containing logging objects if no logging queue/topic target has yet
registered the types in that process.
