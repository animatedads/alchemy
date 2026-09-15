# ooRexx Logging Framework v0.7 — design

## Design position

This is an application framework for ooRexx objects, not a text-line logging
library.  A log event is an ooRexx object.  A payload is an ooRexx object.  A
rule is an ooRexx object.  Targets consume the event object and may project or
persist it only at an explicit boundary.

The inactive state is deliberately represented by an object too:
`.LogNullLogger~instance`.  Application code can therefore retain the normal
message form:

```rexx
log~log(.Log~WARN, payload)
```

without a branch around every call.  The inactive receiver owns no service,
rule, target or event state and returns immediately.

## Runtime principle

Expensive decisions belong at rule activation time, not in a hot method.

When rules or targets change, `LogService` rebuilds:

- a method-plan table keyed by `CLASS|METHOD|SOURCE_SCOPE`;
- a class/scope activation index used by lightweight-object proxy creation;
- direct instrumentation on registered participating objects.

No active plan means a registered method is physically unwrapped.  A
lightweight object is returned unchanged by `proxyIfRequired`; no proxy is
allocated.

An active selective plan evaluates only its preselected condition objects.  A
condition miss creates no `LogInvocation`, no active logger and no `LogEvent`.
The matched-rule array itself is allocated only after the first predicate
succeeds.

## Three ooRexx logging paths

### 1. Explicit emitter

Code that naturally has a logger variable sends `LOG` to it.  The variable may
refer to the singleton null receiver or an active invocation emitter.

This is also the route for crypto-locked methods.  A locked transient method
need not resolve package-local `.Log`; level accessors are available on both
logger implementations:

```rexx
log~log(log~WARN, payload)
```

### 2. Direct method instrumentation

A substantial object may inherit `LogInstrumentationParticipant`.  Registration
is explicit.  The object itself performs its `SETMETHOD` / `UNSETMETHOD`
operations because ooRexx correctly prohibits an unrelated service object from
changing another object's method dictionary.

The original method is copied to a private per-object alias.  The installed
wrapper asks the logging runtime for the already-compiled plan.  On a condition
miss it calls the private original immediately.  On a match it records selected
entry/exit/error points around the private call.

When the final applicable rule or target is disabled, the original method is
restored; subsequent calls pay no logging-plan cost.

### 3. Conditional lightweight proxy

Disposable/light objects do not need to inherit framework instrumentation.
`service~proxyIfRequired(object, scope)` checks the precomputed class/scope
activation index.

- no active plan: returns the exact original object;
- active plan: allocates `LogSelectiveProxy`.

The proxy handles `UNKNOWN` and delegates with `SENDWITH`.  Messages for which
there is no method plan are immediately forwarded.  This mechanism observes
messages crossing the proxy boundary; internal interesting points still use an
explicit emitter or direct instrumentation.

## Selective conditions

v0.2 includes composable condition objects:

- `LogConditionAlways`
- `LogConditionArgNil(index)`
- `LogConditionArgOmitted(index)`
- `LogConditionArgPathContains(index, path, needle, caseless)`
- `LogConditionAny(array)`
- `LogConditionAll(array)`
- `LogConditionNot(condition)`

For the acceptance case:

```rexx
condition = .LogConditionAny~new(.array~of( -
  .LogConditionArgNil~new(1), -
  .LogConditionArgPathContains~new(1, -
    .array~of("CUSTOMER", "CUSTOMERNAME"), "%';DROP", .false)))
```

A rule for `WebsiteUI~generateCustomerPanel` using that condition is evaluated
for the selected method only.  One thousand ordinary sessions produce zero
matches, zero invocation contexts, zero active loggers and zero events.  A
`.nil` session or a customer name containing the trigger activates logging for
that invocation alone.

## Levels and points

`.Log` provides numeric constants:

`TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`, `OFF`.

Rules have a minimum level and an optional point set.  They may also name a
start point and stop point.  An active emitter can therefore remain closed until
an application-defined point and close again at another point without changing
the payload model.

## Targets and target switching

Targets are named objects with `NAME` and `ACCEPT`.  v0.2 provides:

- `LogMemoryTarget`
- `LogQueueDirectTarget`
- `LogQueueTopicTarget`

`LogService~disableTarget(name)` and `enableTarget(name)` participate in plan
compilation.  If a rule has no enabled target, it is not in an active plan.  A
registered method whose only target is disabled is therefore physically
unwrapped rather than continuing to create events which are later discarded.

A held active logger also checks current rule/service/target state before event
construction, so disabling a control is effective immediately.

## Dormant incident rules and the runtime control plane (v0.7)

Runtime diagnosis often needs a rule to exist before it is needed, but merely
registering that rule must not impose the cost which the rule is intended to
avoid. `addDormantRule()` therefore validates and stores a rule with
`enabled=.false` before rebuilding any indexes. No method plan, class/scope
proxy eligibility, invocation object or wrapper is created until a later
control operation arms the rule.

This preserves the lightweight-object model:

```text
dormant rule -> ordinary object -> no proxy
armed rule   -> proxyIfRequired -> proxy only while class/scope has a plan
disarmed     -> new references get ordinary object again
```

An already-issued proxy is deliberately not surgically removed. Its next
message asks the service's exact plan index; once the rule is disarmed there is
no plan, so it forwards directly and performs no logging predicate work. This
prevents stale wrapper identity from becoming stale logging authority.

Operational inspection is also configuration-time work. `LogRuntimeSnapshot`
constructs structured row objects from copies of the service's rule/target/
registration/plan collections. `LogRuntimeNoSQLAdapter~query()` creates a fresh
NoSQL snapshot for each query rather than maintaining SQL projection state from
every logging mutation. Consequently the application hot path contains no
NoSQL callbacks, status-row updates or observer notifications.

The runtime SQL views are read-only. Deliberately omitting setters prevents a
SQL UPDATE from toggling an `enabled` field without also recompiling plans,
installing/removing the cooperative method wrapper and writing the control
journal. Operational mutation goes through `.LogRuntimeControl`, which is a
narrow facade over those coherent service operations and does not expose rule
definition/publication APIs.

Control changes are kept in a separate bounded array of `LogControlEvent`
objects. This avoids recursive "logging the logger" and means a SERVICE DISABLE
operation can still leave a structured record after normal emission has been
turned off. The bounded journal is operational evidence, not the long-term
audit store; durable retention can be routed explicitly rather than turning the
control plane into an accidental ever-growing logfile. `actorId` is descriptive
provenance and must not be confused with the cryptographically verified
`authorisationId` attached to scope-crossing `LogEvent`s.

## Deployment topology and progressive policy routing (v0.6)

Institutional Policy v0.6 allows exact reviewed policy versions to coexist for
a bounded progressive rollout and routes them through immutable deployment
topology. Logging resolves that topology only at configuration boundaries.
`LogMethodPlan~begin` never calls the institutional catalogue.

A `LogPolicyBinding` represents one service-side deployment point. Activation
uses `executionContextForContext()` when a point is supplied, materialises the
selected logging policy, and copies the result into `LogDeploymentContext`.
Hosts serving many dynamic tenants/cohorts should select or cache the appropriate
binding outside the instrumented business method rather than performing
institutional topology resolution from each invocation.

Two deployment identities are retained for different purposes:

- exact `deploymentIdentity`: historical Institutional topology evidence at the
  activation timestamp;
- stable `routeIdentity`: policy + point + selected immutable binding + global
  lifecycle evidence + progressive authority, excluding the observation time.

This prevents a false refresh on every clock tick while preserving exact audit
evidence. `rolloutIdentity` separately records the bounded progressive authority
that made overlapping versions lawful. A failed refresh (including expired
progressive authority or failed logging scope crypto) occurs before
`LogService~replaceRules()`, so the previously active compiled plan remains
intact.

The event remains structured across boundaries. `LogDeploymentContext` is a
core value object and Queue Fabric persistent type rather than an Institutional
Policy object reference. NoSQL projects bounded deployment fields but preserves
the context object in the raw row.

Alchemy v0.8 closes the reverse ordering case for cooperative instrumentation:
when Logging already owns the one physical coordinator wrapper, Alchemy joins
as provider `ALCHEMY.EXECUTION_PROVENANCE` instead of replacing the wrapper.

## Governed rule-set lifecycle (v0.5)

Logging rules are executable runtime objects; reviewed logging policy is a
separate class of object. `LoggingPolicy.cls` introduces `LogRuleSpec` and
`LogRuleSetPolicy`, with `LogPolicyCatalog` reusing Institutional Policy v0.3
for publication, effective dating, supersession, authority evidence and replay
identity.

The separation is intentional:

```text
reviewed LogRuleSetPolicy
        |
        | Institutional Policy publication / effective-date resolution
        v
LogPolicyBinding (configuration boundary)
        |
        | materialise fresh LogRule objects + verify scope capabilities
        v
LogService~replaceRules()
        |
        v
compiled class | method | exact-scope plans
```

The catalogue and clock are not consulted inside an application invocation. A
binding exposes `nextTransition` and `needsRefresh(atTime)` for Runtime Registry
or a scheduler to arrange a configuration-time refresh at the policy boundary.
This avoids turning effective-date governance into a clock lookup on every hot
method call.

A policy containing zero rule specifications is valid. When such a policy
becomes operative, `replaceRules([])` removes the compiled plans and the method
interposition participant restores original methods. Thus a reviewed OFF policy
returns the application to the same physically unwrapped state as no rule.

Policy handover is transactional at the logging boundary. A newly resolved
policy is materialised and the complete replacement is validated before the
binding changes its active-policy identity. If capability verification or any
other `replaceRules()` validation fails, the old service rule table, compiled
plans, object interposition and binding identity remain operative. This avoids a
policy effective-date boundary accidentally producing a partially changed or
unlogged application state.

Institutional publication authority is not logging-scope authority. The
Institutional Policy evaluator may require separated author/approver/publisher
roles, independently verified evidence, multi-party approval, delegation,
revocation, succession or bounded emergency publication. Those facts decide
which rule set may become operative. Any materialised rule crossing an exact
`LogScope` boundary is still rejected unless `LogService` verifies the existing
Alchemy `LOG_SCOPE_ESCALATE` capability for that exact rule and exact source /
delivery scopes. A governance record therefore cannot be misused as a bearer
credential for customer-data movement.

### Policy identity and mutation defence

`LogRuleSpec` has a canonical semantic representation covering the rule id,
component, class, method, exact scope ids, minimum level, condition identity,
targets, points, start/stop points and registration kind. Set-like target/point
collections are sorted for identity; `ANY`/`ALL` condition children are likewise
canonicalized so insertion order is not policy meaning. Whole-policy identity
is independent of rule insertion order.

A sealed `LogRuleSetPolicy` caches the exact reviewed canonical text. Before
materialising executable rules it recomputes the canonical text and compares it
with that sealed value. If a referenced mutable ooRexx condition was altered
after seal/publication, activation fails closed rather than executing behaviour
which was not the behaviour reviewed. Custom conditions need a stable
`SEMANTICIDENTITY`/`CANONICALTEXT` or an explicit reviewed condition identity.

### Policy provenance on events

Runtime rules materialised from a policy carry the policy id, version and exact
semantic identity. `LogEvent` captures those values beside the rule id and the
separate cryptographic authorisation id. NoSQL projections can therefore answer
which policy version caused an event, while the original policy publication
record remains available in the Institutional Policy catalogue for governance
evidence.

## Structured event and scope model (v0.4)

`LogEvent` records metadata separately from its payload. In v0.4 its security
context is also structured rather than flattened:

- event id and sequence;
- timestamp;
- numeric level and level name;
- source `LogScope`, exact source scope id and domain id;
- delivery `LogScope`, exact delivery scope id and domain id;
- compatibility source/delivery disclosure strings;
- component;
- receiver class and identity hash;
- semantic method name;
- point;
- rule id;
- original payload object and payload class;
- cryptographic authorisation id where applicable;
- institutional logging policy id, version and exact semantic identity where applicable;
- thread identity field reserved for runtime integration.

`LogScope` is a first-class ooRexx value carrying disclosure, optional exact
domain id, optional live domain subject, and bounded subject class/identity
metadata. An unqualified scope id is simply `CUSTOMER`; a domain-bearing one is
for example `CUSTOMER:CUSTOMER-ALPHA`. The live subject can be the actual
customer/security-domain object while the event is live.

`metadata` is an explicit projection. It intentionally does not flatten the
payload or substitute strings for the live scope/payload objects. NoSQLServer's
raw row values retain those objects.

## Scope security (v0.4)

The disclosure order remains:

`PUBLIC < CUSTOMER < INTERNAL < SECRET`.

Rank is not the complete security decision. Two scope objects are equivalent
only when their complete scope ids are equal. Consequently both of these are
authority boundaries:

- `CUSTOMER:CUSTOMER-ALPHA -> INTERNAL`;
- `CUSTOMER:CUSTOMER-ALPHA -> CUSTOMER:CUSTOMER-BETA`.

A rule crossing an exact scope boundary is rejected unless `LogService` has an
Alchemy-compatible capability authority and receives a verified capability for:

- operation `LOG_SCOPE_ESCALATE`;
- purpose `LOGGING`;
- exact claims `rule_id`, `source_scope`, `delivery_scope`;
- and, for domain-bearing scope transitions, exact `source_scope_id` and
  `delivery_scope_id` claims.

This means a broad `CUSTOMER -> CUSTOMER` capability cannot be reused to move
records between two customers. The capability id is captured on emitted events.
Logging that remains in the exact same scope requires no capability.

Compiled rule plans are keyed by exact scope id. A method call in
`CUSTOMER:CUSTOMER-BETA` therefore does not even evaluate predicates belonging
to a `CUSTOMER:CUSTOMER-ALPHA` plan. Domain separation is consequently both a
security property and a hot-path indexing property.

## NoSQLServer object table

`LoggingNoSQL.cls` exposes a `LogMemoryTarget` through an
`ObjectDatabaseEngine` mapping.  SQL-visible values are explicit metadata
columns.  NoSQLServer's `DatabaseRow~rawAt()` retains the original getter value,
so `rawAt("event_object")` is the original `LogEvent` and
`rawAt("payload")` is the original payload object.

SQL coercion is therefore a query boundary, not the internal storage model.

## Queue delivery and persistence (v0.4)

Direct queue and topic/subscriber targets submit the `LogEvent` itself as the
Queue Fabric payload. Queue Fabric v0.9-dev4 treats `securityDomain` as a routing
boundary. If a logging target has a domain-bearing `LogScope`, the target checks
that the real queue/topic has that exact domain and supplies the same domain in
its send options. A mismatch fails closed before delivery. Logging policy and
Queue Fabric therefore enforce the destination independently.

`LogScope` and `LogEvent` implement Queue Fabric's domain-object graph protocol:

- `queuePersistentType`;
- `queuePersistentState`;
- `queueRestoreState`.

The current event persistent type is `oorexx.logging.event/0.4`; the scope type
is `oorexx.logging.scope/0.1`. `LogQueueSupport~registerPersistentTypes()` also
registers legacy `oorexx.logging.event/0.2` and `oorexx.logging.event/0.1`
decoders. A recovered v0.1 event is promoted into the current model with string
scopes converted to `LogScope` objects. v0.2 events restore with empty policy
provenance fields; new writes use event/0.4 and persist policy id/version/identity
plus structured deployment context/route/rollout provenance
when present.

Persistence intentionally excludes the live receiver object and the live
`LogScope~subject`. Their bounded class/identity metadata are retained. The
event payload remains an object-graph member, so nested application payloads
can survive restart when their classes implement the Queue Fabric persistence
contract. This avoids accidentally serializing an entire customer/security
object graph merely because that object supplied the log domain.

## External JMS boundary in the current roll-up

`oorexx_jms_queue_bridge_v0.1-dev1` is intentionally not imported into the core
logging package. Queue targets continue to submit the structured `LogEvent` to
Queue Fabric. The current live JMS provider converts an unknown outbound payload
through `payload~string` before creating a JMS `TextMessage`; doing that
implicitly to logging events would discard the object-first model. If JMS text
export is required, the correct extension is an explicit LogEvent-to-
`JMSBridgeMessage` boundary codec/renderer whose loss of structure is a declared
target property.

## Crypto-locked code

The logging service does not inspect decrypted method source, stack frames or
Alchemy's transient private alias.  A crypto-locked method receives a logger
object as an ordinary argument.  Inactive logging passes the null receiver;
active logging passes an emitter.  The real Alchemy locked-method test executes
both paths.

## Cooperative method interposition (v0.2)

`LogInstrumentationParticipant` now inherits the framework-neutral
`MethodInterpositionParticipant`.  The participant is owned by the application
object and performs the actual `SETMETHOD`/`UNSETMETHOD` operations.  Each
semantic method has at most one physical wrapper.  Logging services and future
cooperating framework components register interceptors behind that wrapper.

Provider lists are copy-on-replace Arrays.  Invocation is unguarded and takes a
snapshot reference before iteration.  Configuration changes therefore publish a
complete old or new provider list rather than mutating a list underneath a live
invocation.  A condition miss returns `.nil` from the logging interceptor and no
`MethodInterpositionInvocation` is allocated unless some provider actually
activates.

This also removes the v0.1 `.local["OOREXX.LOG.RUNTIME"]` singleton routing
assumption.  Multiple `LogService` instances can share the same object/method
slot safely because each provider object holds its own service reference.
Removing one service leaves the physical wrapper in place while another
provider remains; removing the final provider restores the prior method layer.

If an object-specific method existed before the coordinator installed its
wrapper, that Method is retained and restored.  The Alchemy regression installs
Alchemy telemetry first, adds logging over it, and verifies that disabling
logging restores the Alchemy object-specific wrapper intact.

## Deferred payload production (v0.2)

Normal ooRexx message arguments are evaluated before the receiving method runs.
Therefore a null logger cannot prevent work already performed in an expression
passed as `payload`.  `LOGFROM` is provided for expensive diagnostics:

```rexx
log~logFrom(.Log~DEBUG, self, "BUILDDIAGNOSTIC", args)
```

The logger first checks current service, rule, target, level, point and start/stop
state.  Only then does it send the producer message.  This remains an ooRexx
message model rather than importing a closure/callback abstraction from another
language.

## ooRexx argument semantics (v0.2)

Rules use `Array~hasIndex()` for argument presence.  `Array~items` is not a
valid positional test because `arg(1,"A")` may contain sparse omitted positions.
`LogConditionArgNil` matches an explicitly present `.nil`;
`LogConditionArgOmitted` matches absence.  `LogInvocation~argument` follows the
same rule.

## Remaining coordination boundary

The coordinator can host any framework which deliberately registers an
interceptor through `MethodInterpositionParticipant`, and it can safely wrap and
restore an object-specific method which already existed before logging arrived.
It cannot stop a non-cooperating framework from later calling `SETMETHOD` on the
same method and replacing the coordinator wrapper.  `methodInterpositionStatus`
reports wrapper-integrity loss; the long-term answer is adoption of the shared
coordinator by those framework components, not increasingly elaborate wrapper
ordering.  Crypto-locked methods continue to use explicit logger injection.

## Hot-path guarding and concurrency (v0.3)

ooRexx methods are guarded unless declared otherwise. That default is useful
for configuration mutation but is the wrong default for shared immutable rule
plans: it can serialize otherwise independent application calls on the plan or
condition object. v0.3 therefore makes the read-only runtime path explicitly
`UNGUARDED`: exact plan lookup, proxy dispatch, condition `MATCHES`, and
`LogMethodPlan~begin`. Configuration methods remain guarded and publish
replacement Tables/Arrays after construction.

Conditions used in production should consequently be immutable/read-only, or
provide their own synchronization if they intentionally maintain state. The
framework's counting conditions exist only in tests.

Diagnostic metrics are also opt-in. A plan captures the metrics-enabled flag at
compile time. With metrics disabled, condition misses do not send counter
messages to the service. Enabling/disabling metrics recompiles plans at
configuration time.

## Whole rule-set replacement and indexing (v0.3)

Rules are indexed by the exact key:

```text
CLASS | METHOD | NATIVE_SCOPE
```

The class/scope index used by disposable-object proxy selection is separate and
contains only active class/scope pairs. `replaceRules()` validates a complete
replacement set first, publishes the new rule Table, compiles the exact plan
Table once, and refreshes registered methods. Runtime messages do not scan the
complete rule collection.

An active logger retains the rule objects that matched its invocation, but every
emission verifies that the retained rule is still the currently published rule
object for that id. Therefore replacing/removing a rule prevents stale loggers
from writing under superseded policy.

## Generic provider ordering (v0.3)

`MethodInterpositionParticipant` is intentionally usable without logging.
Providers can specify numeric priority when registering. Lower priorities enter
first; completions/failures unwind in reverse order, matching nested around-
method semantics while retaining one physical `SETMETHOD` wrapper. Provider
priority is configuration-time state and is exposed structurally by status
introspection.
## Current platform integration (v0.7)

The 2026-08-24 `oorexxapis(20260824-191406).zip` roll-up retains Queue Fabric
v0.9-dev4, NoSQLServer v0.77 and ooRexx Crypto v0.1, advances Alchemy Objects to
v0.8, and advances Institutional Policy to v0.6 for deployment topology and
progressive rollout.
Queue Fabric has a real runtime dependency on `AlchemyObject.cls`; queue-facing
logging packages/tests therefore load Queue Fabric, Alchemy Objects, and ooRexx
Crypto together. `LoggingPolicy.cls` additionally loads Institutional Policy.

SecurityEffect v0.8 is deliberately not a logging-core dependency. Security
effects may themselves need observability, while exact logging-scope crossing
is already enforced by the lower Alchemy capability layer. Keeping those
authorities separate avoids a circular security/logging dependency.

Alchemy v0.7 execution-provenance instrumentation was tested under the shared
method interposition model: Alchemy is installed first, logging layers over the
same semantic method, both record one invocation correctly, and removing
logging leaves Alchemy provenance active.

