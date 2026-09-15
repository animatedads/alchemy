# database_core backend contract v1

A backend implementation is conceptually a `.DatabaseBackendContract`.

Required methods:
- `name`
- `capabilities`
- `supports(capability)`
- `compile(plan)`
- `parser`

The common capability vocabulary is:
TRANSACTIONS, SAVEPOINTS, PREPAREDSTATEMENTS, PREPAREDBATCH, TYPEDRESULTS,
RESULTMETADATA, RESULTSCHEMA, MUTATIONRESULTS, PREPAREDMUTATIONRESULTS,
GENERATEDKEYS, TRANSACTIONRETRY, TRANSACTIONREADONLY, TRANSACTIONISOLATION,
TRANSACTIONTIMEOUT.

A backend must not advertise a capability it cannot implement with real
semantics. External/native backends should normally integrate through a
namespaced adapter rather than importing colliding public class namespaces.


## Behavioral conformance provider

A backend adapter should be testable through a provider exposing `name`,
`supports(capability)`, `reset(scenario)`, and `database`.

`DatabaseBackendConformanceSuite` exercises commit, rollback-before-commit,
prepared execution, prepared batches, deferred results, mutation results,
generated keys, and whole-transaction retry. Optional behavior is capability
gated: omitting an unsupported capability is acceptable; advertising a
capability and then failing its behavioral scenario is not.


## Stateful conformance

As of v0.26, conformance scenarios verify observable state as well as return
codes. Providers expose `readFixtureValue()` and may expose `fixtureRowCount()`.

The suite verifies that committed writes become visible, rollback-before-commit
does not mutate the fixture, prepared execution and batches produce the expected
final state, deferred query values are correct, mutation counts match the
operation, generated-key inserts become visible, and retry commits the intended
state after a retryable failure.

A separate negative smoke uses a deliberately broken backend which advertises
transactions and returns success without changing state. The conformance suite
must and does reject it.


## Endpoint capability negotiation

Backend capability and endpoint capability are separate concepts.

A MySQL command backend may know how to perform generated-key capture while a
particular MySQL-compatible server does not implement the required server
semantics. Transport/dialect identity is therefore not proof of full reference
server capability.

`DatabaseEndpointCapabilities` wraps the backend capability set and may disable
or explicitly enable endpoint-specific features. `Database~supports()` consults
this endpoint view.

`mysql_wire_live_probe.rex` is a read-only end-to-end probe through
`.DatabaseProcessCommandExecutor` and a real mysql/mariadb client. It accepts an
optional comma-separated disabled-capability list.


## Endpoint identity

`Database~endpointIdentity` executes an engine-specific, read-only identity query.

For MySQL-compatible endpoints this is `SELECT VERSION()`. The returned
`DatabaseEndpointIdentity` records protocol, product, version and the raw version
string.

Identity is descriptive only. It does not automatically enable capabilities.
In particular, seeing `NoSQLServer` in a MySQL version string must not be used as
proof that every MySQL feature exists.

Two live probes are included:

- `mysql_wire_identity_probe.rex` — read-only endpoint identity.
- `mysql_wire_transaction_probe.rex` — opt-in stateful transaction probe against
  a caller-supplied dedicated table. It owns only row id `900001` in that table.


## Live MySQL-wire behavioral conformance

`mysql_wire_conformance.rex` runs a capability-gated behavioral subset through a
real mysql/mariadb client against any MySQL-compatible endpoint.

It does not infer capabilities from the endpoint identity string. The caller may
mask unsupported endpoint capabilities explicitly. The runner owns only one row
(`id = 900001`) in a caller-supplied dedicated table.

This gives a second independent path for native backends that also expose a
MySQL-compatible listener: their native adapter and the wire protocol can be
checked against the same database semantics.
