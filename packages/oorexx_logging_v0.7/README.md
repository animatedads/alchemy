# ooRexx Logging Framework v0.7

An ooRexx-first logging application framework. Logging is structured object
behaviour, not production of formatted text lines.

The ordinary application call remains:

```rexx
log~log(.Log~WARN, "SOME WARNING")
```

When logging is inactive, `log` can be the singleton
`.LogNullLogger~instance`. Its `LOG`, `LOGFROM`, `POINT`, `ENABLEDFOR` and level
messages do not consult a service, scan rules, allocate events or touch a
target.

## Selective runtime activation

Rules are compiled by class + method + native scope. They can additionally
select by level, named point, delivery target and condition. The supplied
acceptance test instruments only `WebsiteUI~generateCustomerPanel` and activates
logging only when:

- the first argument is explicitly `.nil`, or
- `session~customer~customerName` contains `%';DROP`.

For 1,000 benign calls with that rule active, the test observes 1,000 required
predicate checks but **0 rule matches, 0 `LogInvocation` objects, 0 active
loggers and 0 `LogEvent` objects**. With no applicable rule, the registered
method is physically unwrapped and records **0 plan evaluations**.

The rule language follows ooRexx argument semantics: an omitted argument is not
the same thing as an explicitly supplied `.nil`, and sparse argument arrays are
addressed with `HASINDEX` rather than inferred from `Array~items`.

## Cheap expensive diagnostics

Because ooRexx evaluates message arguments before the receiver gets them,

```rexx
log~log(.Log~DEBUG, self~buildLargeDiagnostic)
```

necessarily builds the diagnostic even if `log` is the null logger. For costly
payloads the framework provides a message-native deferred form:

```rexx
log~logFrom(.Log~DEBUG, self, "BUILDLARGEDIAGNOSTIC", args)
```

The producer message is not sent unless the level/point/rule/service/target
state says the event can actually fire. The tests prove that the producer is
not invoked through the null logger, below the rule threshold, or after the
only target has been disabled.

## Cooperative method instrumentation

Substantial objects may inherit `LogInstrumentationParticipant`. It is now a
specialization of the generic `MethodInterpositionParticipant` supplied with the
package.

The target object owns its own `SETMETHOD` / `UNSETMETHOD` operations. There is
one physical wrapper per semantic method, and cooperating providers register
behind that wrapper. Provider lists are replaced as complete Arrays at
configuration time so an invocation sees a complete old or new provider list,
not a half-edited list.

This removes the v0.1 process-global runtime pointer and allows two independent
`LogService` instances to instrument the same object/method simultaneously:

- one physical ooRexx wrapper;
- two service-specific logging interceptors;
- either service may withdraw independently;
- the original method is restored only when the final provider leaves.

The coordinator also preserves a pre-existing object-specific method layer. The executable
Alchemy interop test installs Alchemy method telemetry first, then logging;
logging runs over it, and removing logging restores the Alchemy wrapper rather
than erasing it.

## v0.7 runtime control and dormant incident instrumentation

v0.7 adds an explicit cold-path control surface without moving operational
inspection into application logging calls. `.LogRuntimeControl` exposes only
service/rule/target enable and disable operations plus structured snapshots; it
does not expose `addRule()` or `replaceRules()`, so operational control cannot
quietly redefine reviewed logging semantics.

A rule may now be registered atomically in a dormant state:

```rexx
service~addDormantRule(rule)
...
control~enableRule(rule~ruleId, "incident investigation", "ops-console")
```

While dormant, the rule is retained as an ooRexx object but is absent from the
compiled plan/class indexes. Long-lived registered methods therefore remain
unwrapped, and lightweight objects returned by `proxyIfRequired()` remain the
exact original objects. Arming the rule rebuilds the relevant plan/index; only
then can a lightweight object acquire a `LogSelectiveProxy`. Disarming the rule
removes the plan again. A proxy that was handed out while the rule was active
cannot preserve stale logging authority: after disarm it becomes a forwarding
shell and performs zero plan evaluations.

`LoggingControl.cls` also provides `.LogRuntimeNoSQLAdapter`. Each query takes a
fresh structured snapshot and exposes read-only object tables for:

- `log_runtime`;
- `log_rules`;
- `log_targets`;
- `log_registrations`;
- `log_plans`;
- `log_control_events`.

The SQL columns are bounded projections. `rule_object`, `target_object`,
`registration_object`, `plan_object`, `service_object`, and `control_object`
remain the actual ooRexx objects in `DatabaseRow~rawAt()`. The tables have no
setters: SQL `UPDATE` cannot bypass `LogRuntimeControl`, plan recompilation or
method unwrapping.

Enable/disable operations append a separate structured `LogControlEvent`. This
is intentionally not a normal `LogEvent`, so disabling logging cannot suppress
the record that logging was disabled or recursively invoke the logging service.
The journal is bounded (default 1024 entries, configurable in the third
`LogService~new()` argument) and reports how many older control events were
dropped. `actorId` is provenance supplied by the caller, **not** a claim that a
cryptographic authorization check occurred; cross-scope logging authority
continues to use the separate verified Alchemy capability path.

## v0.6 deployment-aware governed logging

v0.6 rebases on `oorexxapis(20260824-191406).zip`, including Institutional
Policy v0.6 and Alchemy Objects v0.8. Institutional Policy now has explicit
deployment topology and bounded progressive overlap; Logging consumes those
features without moving catalogue resolution into the application hot path.

A binding may be tied to an Institutional deployment point:

```rexx
point = .InstitutionalPolicyDeploymentPoint~new( -
    "WEB", "GB", "PUBLIC", "RETAIL", "PILOT")
binding = .LogPolicyBinding~new(service, catalog, "WEBSITE-LOGGING", point)
ignore = binding~activate(.DateTime~new, capabilities)
```

`activate()` resolves the exact policy and deployment topology once, then copies
the bounded result into a neutral `LogDeploymentContext`. The core logging
package therefore does not require Institutional Policy merely to carry an
event. `LogDeploymentContext` retains service, region, channel, tenant, cohort,
the exact evaluated deployment identity, a stable route identity, and any
active bounded progressive-rollout authority identity.

The distinction between `deploymentIdentity` and `routeIdentity` is deliberate.
Institutional historical deployment identities contain the evaluation time; they
are excellent audit evidence but unsuitable as cache keys. The logging route
identity excludes the observation clock and is built from the exact immutable
topology binding, global lifecycle evidence, point, policy identity and active
progressive authority. `needsRefresh()` therefore remains false merely because
time advanced while becoming true when routing/governance actually changed.

The progressive rollout acceptance test publishes overlapping reviewed logging
policies v1/v2 under a bounded DEPLOY authority. Ordinary traffic remains on v1
while a PILOT cohort receives v2, then a global cutover moves ordinary traffic
to v2. After the single activation-time topology resolution, 1,000 business
method calls perform **zero additional Institutional Policy resolutions**. If the
bounded progressive authority later expires before catalogue cleanup, refresh
fails closed and leaves the previously compiled logging rules installed
atomically.

`LogEvent` persistence advances to `oorexx.logging.event/0.4`. The event retains
the structured `LogDeploymentContext`; NoSQLServer exposes deployment service,
region, channel, tenant, cohort, route and rollout identities as query columns
while `rawAt("deployment_context")` retains the actual object. Queue Fabric can
recover event/0.3, event/0.2 and event/0.1 records into the current object model.

Alchemy Objects v0.8 now cooperates structurally with the generic interposition
protocol in both installation orders. The v0.6 suite proves Logging-first /
Alchemy-second uses one physical wrapper with independent provider withdrawal,
in addition to the existing Alchemy-first regression.

## v0.5 governed logging policy lifecycle

v0.5 integrates the logging framework with `institutional_policy_v0.3` without
putting policy evaluation onto the application hot path. A reviewed logging
configuration is represented by `LogRuleSetPolicy`, containing fixed
`LogRuleSpec` objects. The generic `LogPolicyCatalog` publishes and resolves
these policies with Institutional Policy's effective-date, supersession and
publication-authority semantics.

A host binds a policy family to a service once:

```rexx
binding = .LogPolicyBinding~new(service, catalog, "WEBSITE-LOGGING")
ignore = binding~activate(.DateTime~new, capabilityTable)
```

Activation resolves the operative policy, materialises fresh runtime `LogRule`
objects, validates any cryptographic scope-transition capabilities, and calls
`LogService~replaceRules()` once. Nothing in a normal logged invocation queries
the policy catalogue or clock. `binding~nextTransition` and
`binding~needsRefresh(atTime)` let Runtime Registry/a scheduler arrange the next
configuration refresh outside the method hot path.

An empty published rule set is valid and means **logging off for that policy
family**. The acceptance test hands over from a suspicious-name policy, to a
`.nil`-only policy, to an empty policy. At the empty policy boundary the
registered method is physically unwrapped and subsequent calls perform zero
logging-plan evaluations.

Institutional publication authority and logging-scope authority are intentionally
different controls. Institutional Policy can require author/approver/publisher
authority, independent approval evidence, multi-party governance, delegation or
bounded emergency publication. None of those grants permission to move a log
event across a logging security scope. `LogService` still requires the exact
Alchemy cryptographic capability for every source/delivery scope transition.
The tests prove that a fully published policy cannot activate a cross-customer
logging rule without that separate cryptographic bearer. Policy handover is
also atomic: if the next effective policy fails scope-capability validation,
`LogPolicyBinding` leaves the prior active policy and its compiled rules intact;
the replacement becomes active only after all rule validation succeeds.

`LogEvent` now carries `policyId`, `policyVersion`, and `policyIdentity` alongside
`ruleId` and `authorisationId`. NoSQLServer exposes those as query columns while
retaining the original structured event/payload objects. Queue persistence uses
`oorexx.logging.event/0.3` and remains backward compatible with both event/0.2
and event/0.1 records.

Policy semantic identity is canonical across rule insertion order and set-like
target/point ordering. A sealed policy caches its reviewed canonical identity
and revalidates it before materialisation; post-seal mutation of a referenced
condition therefore fails closed. Custom condition implementations must expose a
stable `SEMANTICIDENTITY`/`CANONICALTEXT`, or the `LogRuleSpec` must be given an
explicit reviewed condition identity.

The new JMS Queue Bridge in the roll-up is deliberately **not** made a hidden
core logging target. Logging continues to place structured `LogEvent` objects
onto Queue Fabric. The current live JMS adapter renders unknown payloads through
`payload~string`, so exporting logging to a text-only JMS destination should use
an explicit LogEvent-to-JMS codec at that boundary rather than silently
flattening events inside the logging framework.

## v0.4 structured security scopes and platform integration

v0.4 makes logging scope a first-class ooRexx object rather than reducing it to
a disclosure label. `LogScope` carries:

- disclosure class (`PUBLIC`, `CUSTOMER`, `INTERNAL`, `SECRET`);
- an optional exact security-domain id;
- an optional live domain subject object;
- bounded subject class/identity metadata for durable persistence.

Compatibility constants remain valid, so existing code may still use
`.Log~CUSTOMER`. Domain-bearing code can use, for example:

```rexx
scope = .Log~customerScope("CUSTOMER-ALPHA", customer)
```

Compiled plans are keyed by the exact scope id. A rule for
`CUSTOMER:CUSTOMER-ALPHA` is therefore not evaluated for
`CUSTOMER:CUSTOMER-BETA`. Moving between two different exact scopes requires
cryptographic authority even when their disclosure rank is identical. The
capability is bound to the exact source and delivery scope ids.

Queue targets also bind domain-bearing scopes to Queue Fabric's real
`securityDomain`. A target claiming `CUSTOMER-ALPHA` fails closed if it points
at a queue/topic in `CUSTOMER-BETA`. Thus logging policy and queue routing each
enforce the destination boundary independently.

v0.4 introduced structured-scope persistence at `oorexx.logging.event/0.2`.
v0.5 advanced policy provenance to event/0.3 and v0.6 advances deployment
provenance to the current event/0.4 schema. All remain executable recovery
inputs. Durable scopes retain bounded subject identity but deliberately do not
serialize the live customer/security subject object graph.

## v0.3 hot-path and rule-set hardening

v0.3 removes implicit ooRexx `GUARDED` serialization from the read-only
selection path: compiled plan lookup, condition evaluation, proxy dispatch and
method-plan evaluation are unguarded. Configuration mutation remains guarded.
This matters because one compiled rule object can be shared by many concurrent
application invocations; logging must not accidentally turn that shared rule
into an application-wide monitor.

Diagnostic counters are now explicitly opt-in with `service~enableMetrics`.
When counters are disabled (the default), compiled method plans contain a false
tracking flag and do not send metric messages on condition-miss paths. Tests
turn the counters on only when they need acceptance evidence.

`service~replaceRules(array [, capabilities])` validates a complete replacement
rule set before publishing it, then rebuilds the exact class/method/scope plan
index once. A 1,001-rule acceptance test proves that an unrelated proxy message
evaluates zero plans/rules and the selected method evaluates exactly one
predicate. Rejected replacement sets leave the currently published rules
untouched; a successful replacement also makes already-issued loggers from the
old rule set non-deliverable.

The generic method interposition layer now accepts an optional numeric provider
priority. Lower priorities run `BEFORE` first; `AFTER`/`FAILURE` unwind in the
reverse order. Reprioritising a provider replaces its registration without
creating another physical wrapper. This is framework-neutral machinery intended
for coordinated use by logging, Alchemy and other ooRexx infrastructure.

## Lightweight/disposable objects

Disposable objects do not need logging ancestry or permanent instrumentation.
`service~proxyIfRequired(object, scope)` uses the compiled class/scope activation
index:

- no active rule: returns the exact original object and allocates no proxy;
- active rule: returns a `LogSelectiveProxy` which observes selected messages
  through `UNKNOWN`/`SENDWITH`.

A message without an active method plan is forwarded without predicate
evaluation. A condition miss creates no invocation context or event.

## Object-first delivery

`LogEvent~payload` remains the original ooRexx object. Included targets/adapters
support:

- memory/live object access;
- NoSQLServer object-table queries while retaining raw event/payload objects;
- Queue Fabric direct queues;
- Queue Fabric topic/subscriber delivery;
- Queue Fabric durable object-graph persistence and recovery.

There is no implicit log-line rendering target.

## Security scopes

The built-in disclosure order remains `PUBLIC < CUSTOMER < INTERNAL < SECRET`,
but v0.4 security decisions use the full `LogScope`, not rank alone. An exact
scope is the disclosure class plus, where present, its domain id. Any transition
from one exact scope to another requires a cryptographically verified
Alchemy capability bound to the rule and exact source/delivery scope ids. This
includes same-rank cross-domain moves such as
`CUSTOMER:CUSTOMER-ALPHA -> CUSTOMER:CUSTOMER-BETA`.

Crypto-locked methods can receive the no-op or active logger as an ordinary
object. They may use:

```rexx
log~log(log~WARN, payload)
```

without relying on package visibility of `.Log` or exposing transient decrypted
source to the logging service.

See `DESIGN.md` for rationale and boundaries, `API.md` for the API map, and
`VALIDATION.txt` for executable acceptance evidence.
