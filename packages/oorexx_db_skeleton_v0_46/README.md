# ooRexx Database Virtualization Skeleton v0.46

Structure-first, deliberately NOP-backed object model for PostgreSQL/MySQL command virtualization.

The operational backend is intentionally inert at this stage. The purpose of v0.23 is to establish and execute the class graph under real ooRexx 5.3.0 before SQL/client implementation begins.

## Included object families

- Database, DatabaseConnection, DatabaseCredential
- DatabaseEngine, PostgreSQLEngine, MySQLEngine
- DatabaseOperation, DatabaseStatement
- DatabaseTransaction, DatabaseTransactionPlan, DatabaseTransactionResult
- DatabasePreparedStatement, DatabasePreparedExecution, DatabasePreparedBatch
- DatabaseParameter, DatabaseParameterSet, DatabaseResultReference
- DatabaseSavepoint, DatabaseDeferredResult
- DatabaseCommand, DatabaseCommandExecutor, DatabaseCommandResult
- DatabaseResult, DatabaseStatementResult
- DatabaseResultParser, PostgreSQLResultParser, MySQLResultParser

## Current invariant

One transaction object builds one transaction plan. The engine compiles that plan into one DatabaseCommand object. The current executor returns a NOP success result; it does not issue operating-system commands yet.

## Runtime used for acceptance

Open Object Rexx 5.3.0 r13196, 64-bit, build date 2026-08-03.

## Tests

`smoke.rex` exercises the main object graph, prepared statements, deferred results, savepoints and both engine selectors.

`state_smoke.rex` exercises rollback-before-execution, repeat commit prevention, parameter normalization/nulls and prepared batches.


## v0.23 error/status constants

A single public `.Error` class is the framework-wide symbolic status/error namespace.
Result objects expose `status` and `error` values using `.Error` constants; transaction
results additionally retain the transaction `outcome`.

Example:

    if rs~status = .Error~NOTEXECUTED then ...
    if rs~error = .Error~INVALIDSTATE then ...

No numeric or free-form string status values should be introduced outside `.Error`.


## v0.23 database operation constants

`.DatabaseOperationType` is the single symbolic namespace for operation kinds used
by operation objects and `SELECT`/`WHEN` dispatch. New operation kinds should be
added here rather than introduced as free-form strings.


## v0.23 engine command compilation

PostgreSQL and MySQL engines now compile transaction plans into deterministic
client command objects. PostgreSQL targets `psql` with startup files disabled and
`ON_ERROR_STOP=1`; MySQL targets `mysql` in batch/raw mode. The executor remains
NOP'd, so this pass proves command construction and SQL grouping without touching
a live database.

Ordinary statements, savepoints and rollback-to-savepoint are compiled into the
single transaction stdin stream. Prepared statement execution remains explicitly
NOP-marked for the next implementation pass rather than being faked.


## v0.23 prepared statement compilation

Transaction-scoped prepared statements now compile into the same single client
invocation as the rest of the transaction.

PostgreSQL uses server-side `PREPARE` plus repeated `EXECUTE`, converting `?`
placeholders to `$1`, `$2`, ... during compilation.

MySQL uses `PREPARE ... FROM`, deterministic user variables populated with `SET`,
and `EXECUTE ... USING`.

Parameters stay as `.DatabaseParameter` objects until engine compilation.
NULL, integer, decimal, boolean and quoted text rendering are covered by runtime
tests. Prepared batches compile as repeated executions of one prepared statement.


## v0.23 transaction-plan validation

Transaction plans now validate before engine compilation. Validation rejects
parameter-count mismatches, duplicate prepared statement names, prepared
executions before declaration, unknown savepoints, and unsupported operation
types. Validation failures are represented by `.DatabaseValidationResult` and
`.Error` constants.

Invalid plans compile to a `.DatabaseCommand` with status
`.Error~NOTEXECUTED`; the NOP executor propagates that status without pretending
a database rollback occurred. Transaction results therefore distinguish
NOTEXECUTED from ROLLEDBACK.


## v0.23 credentials, environment and executable resolution

Connection credentials are kept out of client argv construction. Password
credentials are applied to a command environment object (`PGPASSWORD` for
PostgreSQL and `MYSQL_PWD` for MySQL), while command arguments remain free of
credential values.

`.DatabaseExecutableResolver` provides the engine-to-client lookup boundary and
supports explicit path overrides for tests and non-standard installations.

The executor remains deliberately NOP'd; this pass prepares safe command objects
for the later real-process execution layer without enabling live database access.


## v0.23 real process executor

A real `.DatabaseProcessCommandExecutor` now exists alongside the NOP executor.
It writes command stdin to a temporary file, launches the client through
`ADDRESS SYSTEM`, captures stdout, stderr and rc separately, and returns a
`.DatabaseCommandResult`.

Environment variables from `.DatabaseCommandEnvironment` are applied to the
process invocation. Runtime tests verify stdin round-trip, stdout, stderr,
non-zero rc handling and environment propagation without requiring a database
server.

The default `.Database` executor remains NOP-like for safety; callers explicitly
inject `.DatabaseProcessCommandExecutor` for live command execution.


## v0.23 live integration probes

The real process executor now preflights the executable before creating a
database transaction process. A missing client is reported as
`.Error~NOTEXECUTED` / `.Error~EXECUTABLENOTFOUND`; it is not falsely described
as a rolled-back database transaction.

`postgres_live_probe.rex` and `mysql_live_probe.rex` exercise a disposable table,
prepared inserts, update, delete, commit, verification query and cleanup through
the real process executor. Connection/client settings can be supplied with
environment variables. The MySQL probe also works with MariaDB's client by
setting `DB_MY_CLIENT=mariadb`.

These probes require running database servers and suitable local authentication.


## v0.23 engine-specific error classification

PostgreSQL and MySQL/MariaDB result parsers now classify real client failures
into database-domain `.Error` constants. Transaction commit asks the selected
engine parser to classify failed command results before constructing the final
`.DatabaseTransactionResult`.

Current mappings include connection failure, authentication failure,
database-level permission denial and generic database errors. Regression tests
include the exact PostgreSQL connection-refused and MariaDB ERROR 1044 signatures
observed during the first live host run.


## v0.23 richer database error classification

Error classification now distinguishes missing databases, SQL syntax failures,
duplicate keys, general constraint violations and timeout outcomes in addition
to connection, authentication and permission failures.

Synthetic regression tests cover PostgreSQL and MySQL/MariaDB signatures for
each category. `postgres_error_probe.rex` and `mysql_error_probe.rex` are also
included for live syntax and duplicate-key verification once the local servers
are reachable and authenticated.


## v0.23 executor and parameter hardening

Review-driven hardening closes four gaps:

- invalid environment variable names now produce `.Error~INVALIDENVIRONMENT`
  instead of silently executing `/bin/false`;
- stdin file opening is checked and returns `.Error~INPUTFAILED` on failure;
- temporary files are atomically reserved with shell noclobber and retries rather
  than relying only on timestamp + random naming;
- declared numeric/boolean prepared parameters are validated before compilation,
  preventing a caller from smuggling arbitrary SQL text through a falsely claimed
  numeric type.

The stderr classifiers are now explicitly documented as compatibility layers
rather than a final structured-error authority.


## v0.23 live error-probe preconditions

The live syntax/constraint probes now perform a harmless `SELECT 1` preflight
before attempting error-specific assertions. If connection, authentication, or
database permission prevents the SQL from reaching the server, the probe reports
`PRECONDITION BLOCKED` with the actual mapped `.Error` value and exits without
claiming the syntax classifier failed.

This keeps environmental readiness separate from classification correctness.


## v0.23 timeout execution and large-DML atomicity scaffold

`.DatabaseProcessCommandExecutor` now honours a positive `DatabaseCommand~timeout`
through the host `timeout` utility. Exit code 124 is recorded with termination
reason `TIMEOUT`, and the engine parsers map that to `.Error~TIMEOUT`.

`large_dml_atomicity_probe.rex` is deliberately a client/database integration
test, not an ooRexx rollback implementation test. It accepts DML-only SQL and
injects a bad final statement. Schema/DDL is kept outside the measured
transaction so PostgreSQL and MySQL/MariaDB are not compared across incompatible
DDL transaction semantics.


## v0.23 framed query results

Result-producing operations are wrapped with deterministic begin/end marker
queries inside the same transaction stream. Combined client stdout is split into
ordered result frames and each deferred query is resolved against its own
`.DatabaseQueryResult`.

`.DatabaseQueryResult` exposes columns, rows and row count. `.DatabaseRow`
provides named-column access. PostgreSQL requests unaligned tab-delimited output;
MySQL batch/raw output uses the same frame parser.

NOP execution emits no result frames, so NOP-mode deferred queries remain
unresolved instead of receiving fabricated data.


## v0.23 typed database values

`.DatabaseType` defines the common result-value type vocabulary. `.DatabaseValue`
carries raw client text, typed value representation, type name, and NULL state.

`.DatabaseRow~at()` returns a `.DatabaseValue`; `rawAt()` returns unchanged client
text and `valueAt()` returns the typed representation.

ooRexx represents numeric literals and numeric text as String objects, so INTEGER
and DECIMAL values deliberately retain validated numeric text rather than using
coercion tricks such as `+ 0`. BOOLEAN maps to `.true`/`.false`; NULL maps to
`.nil`.

Fields default to `UNKNOWN` unless column metadata is supplied. Malformed text
for a declared numeric/boolean type degrades to `UNKNOWN` while preserving raw
text.


## v0.23 automatic table metadata

PostgreSQL and MySQL/MariaDB engines now provide engine-specific
`information_schema.columns` metadata queries and map native column type names
into the common `.DatabaseType` vocabulary.

`.DatabaseColumnMetadata` and `.DatabaseResultMetadata` represent discovered
schema. `Database~tableMetadata(tableName)` retrieves and parses it.
`Database~queryTable(tableName)` performs metadata lookup followed by `SELECT *`
and reapplies the discovered type vector to the returned rows.

This starts deliberately with table queries, where column metadata is
unambiguous. Arbitrary expressions, aliases, joins and computed columns still
remain `UNKNOWN` unless a later result-description layer can identify them
reliably.


## v0.23 explicit result schemas for arbitrary SQL

`.DatabaseResultSchema` lets callers describe the expected output types of
arbitrary SQL when engine metadata cannot be inferred safely.

Immediate queries use `db~queryWithSchema(sql, schema)`. Transactional queries
use `tx~queryWithSchema(sql, schema)`, with the schema retained by the deferred
result and applied only after its framed output has been parsed successfully.

Ordinary `query()` remains conservative: joins, aliases, aggregates, and computed
columns stay `UNKNOWN` unless the caller supplies a schema or a later engine
description mechanism can prove their types.


## v0.23 transaction policy

Transactions now carry backend-neutral isolation level, access mode, and timeout
policy.

Isolation constants:
`DEFAULT`, `READUNCOMMITTED`, `READCOMMITTED`, `REPEATABLEREAD`,
`SERIALIZABLE`.

Access constants:
`DEFAULT`, `READONLY`, `READWRITE`.

PostgreSQL compiles these into `BEGIN ... ISOLATION LEVEL ... READ ONLY|WRITE`.
MySQL/MariaDB compiles isolation through `SET TRANSACTION ISOLATION LEVEL ...`
followed by `START TRANSACTION READ ONLY|WRITE`.

Transaction timeout is propagated to the command executor's existing real timeout
mechanism. Policy is mutable only while the transaction is in the building state.


## v0.23 explicit whole-transaction retry policy

Concurrency failures now have common error constants `DEADLOCK`,
`SERIALIZATIONFAILURE`, and `LOCKTIMEOUT`.

Transactions still default to exactly one attempt. Retry is opt-in with
`tx~setRetryAttempts(n)`. Only retryable concurrency errors replay, and replay is
always the complete compiled transaction rather than an individual statement.
Non-retryable errors stop after one attempt.

`.DatabaseTransactionResult~attemptCount` reports whole-transaction attempts and
`~retried` reports whether replay occurred. Deferred query results are resolved
only from the final successful attempt.


## v0.23 mutation results

Successful transactions now expose ordered `.DatabaseMutationResult` objects
through `DatabaseTransactionResult~mutationResults`.

PostgreSQL affected-row counts are parsed from native command tags such as
`INSERT 0 1`, `UPDATE 3`, and `DELETE 2`.

For ordinary MySQL/MariaDB INSERT/UPDATE/DELETE statements, the compiler emits a
post-statement `ROW_COUNT()` probe with a deterministic marker. This keeps
affected-row collection inside the same client invocation and transaction.

Each mutation result currently exposes `affectedRows`. Generated-key capture is
deliberately not claimed yet.


## v0.23 prepared mutation counts

Prepared INSERT/UPDATE/DELETE executions now participate in the same affected-row
contract as ordinary statements. PostgreSQL naturally emits command tags for
prepared `EXECUTE` operations, which the existing parser consumes.

MySQL/MariaDB prepared executions receive an immediate marked `ROW_COUNT()`
probe. Prepared batches emit one probe after each individual execution, so a
batch preserves per-execution counts such as `1, 0, 7` rather than collapsing
them into one total or only reporting the final statement.

Generated-key capture remains deliberately separate and requires an explicit
request surface; v0.23 does not guess identity columns.


## v0.23 explicit generated-key capture

`tx~insertReturningKey(sql, columnName)` explicitly requests a generated key for
an INSERT. PostgreSQL uses `RETURNING`; MySQL/MariaDB captures `ROW_COUNT()` and
`LAST_INSERT_ID()` together immediately after the INSERT. The key appears on the
ordered `.DatabaseMutationResult~generatedKey`. Ordinary INSERT behavior is
unchanged and identity columns are never guessed.


## v0.29 behavioral backend conformance

Capability declarations are now backed by executable behavioral scenarios.
`.DatabaseConformanceProvider` defines the fixture/provider boundary and
`.DatabaseBackendConformanceSuite` runs common scenarios for commit, rollback,
prepared statements, prepared batches, deferred queries, mutation results,
generated keys, and transaction retry.

Optional scenarios are capability-gated. A backend can honestly skip an
unsupported feature; advertising a capability and then failing the behavior is a
conformance failure.


## v0.29 stateful backend conformance

Behavioral conformance now verifies observable state, not merely successful
method returns. Commit, rollback, prepared execution, prepared batches, deferred
queries, mutation results, generated keys, and retry all have state assertions.

Providers expose `readFixtureValue()` and optionally `fixtureRowCount()`. A
negative conformance smoke intentionally supplies a backend which advertises
transactions and returns success without changing state; the suite rejects it.


## v0.29 endpoint capabilities and MySQL-wire live probe

Backend capabilities are now separated from endpoint capabilities.
`.DatabaseEndpointCapabilities` inherits the backend capability set and can mask
or explicitly enable features for a particular server.

`Database~supports()` consults the endpoint view. A MySQL-compatible endpoint no
longer has to claim every feature of reference MySQL/MariaDB merely because it
speaks the protocol.

`mysql_wire_live_probe.rex` is a read-only end-to-end probe through the actual
process executor and mysql/mariadb client.


## v0.29 endpoint identity and live transaction probe

`Database~endpointIdentity` now performs an engine-specific read-only identity
query and returns `.DatabaseEndpointIdentity`.

For MySQL-compatible endpoints, `SELECT VERSION()` is classified descriptively
as mysql, mariadb, nosqlserver, or mysql-compatible. Identity does not
automatically alter endpoint capabilities.

`mysql_wire_identity_probe.rex` performs read-only identity discovery.
`mysql_wire_transaction_probe.rex` is an opt-in commit/rollback/visibility probe
against a caller-supplied dedicated table and owns only row id 900001.


## v0.29 live MySQL-wire conformance

`mysql_wire_conformance.rex` provides a capability-gated live behavioral runner
through `.DatabaseProcessCommandExecutor` and an actual mysql/mariadb client.

The runner probes endpoint identity, performs a basic query, and conditionally
tests transaction commit/visibility, rollback-before-commit, prepared statement
mutation, and affected-row mutation results. Unsupported endpoint capabilities
are skipped rather than treated as failures.

The runner mutates only row id 900001 in a caller-supplied dedicated table.


## v0.33 spatial value/metadata interoperability

Database Core remains a database abstraction rather than a spatial query planner.
It now has a neutral `.DatabaseType~GEOMETRY`, `.DatabaseGeometryValue`, spatial
encoding vocabulary, and optional geometry subtype/SRID fields on column metadata.

PostgreSQL metadata discovery preserves `USER-DEFINED` type names via `udt_name`,
allowing PostGIS `geometry`/`geography` columns to map to the neutral geometry
carrier. MySQL geometry family names map to the same neutral type.

`.DatabaseCapability~SPATIALTYPES` and `SPATIALFUNCTIONS` are vocabulary only;
neither is advertised by default. Endpoint/backend detection must enable what is
actually supported. Database Core transports geometry and metadata; NoSQLServer
owns SQL spatial functions, planning, federation and pushdown decisions.

`spatial_interop_smoke.rex` uses a real POINT GeoPackage blob sampled from the
supplied Inverness NGD address dataset (EPSG:27700) to prove that a foreign source
can hand Database Core an opaque geometry value without losing subtype, SRID or
raw bytes.


## v0.33 relational source facade

`.Database` now exposes a neutral relational-source facade through
`.DatabaseRelationalSource` and `.DatabaseTableSource`.

The facade passes through source identity, endpoint/backend capabilities, table
metadata and typed row retrieval using the existing `.DatabaseResultMetadata`,
`.DatabaseQueryResult`, `.DatabaseRow` and `.DatabaseValue` classes. It does not
introduce federation, query planning or pushdown policy into database-core.

This is the intended boundary for NoSQLServer to consume a database as one
relational source among files, objects and other providers.


## v0.33 relational-source boundary hardening

The relational-source facade now carries endpoint identity as well as backend
identity and effective capabilities. `.DatabaseRelationalSource` caches endpoint
identity and `.DatabaseTableSource` inherits it.

Consumers can distinguish engine, protocol and endpoint product without
database-core learning federation semantics; for example an engine may be
`mysql`, protocol `mysql`, and endpoint product `nosqlserver`.

`.DatabaseTableSource~describe` supplies name, engine, protocol, product,
version, effective capability enumeration and table metadata.

This pass also fixed a latent ooRexx capability-enumeration bug. The previous
`all` methods accumulated values through a local named `result`; enumeration is
now based on `.Set~makeArray` and explicit `capabilityList` variables, avoiding
the special `RESULT` variable trap and making the full advertised capability set
observable to consumers.


## v0.33 table/relation discovery

Database-core now exposes backend-neutral relation discovery.

- `.DatabaseCapability~TABLEDISCOVERY`
- `.DatabaseRelationDescriptor`
- `.Database~tables`
- `.DatabaseRelationalSource~tables`

PostgreSQL and MySQL provide engine-specific `information_schema.tables`
queries and normalize their results to descriptors carrying schema name,
relation name, relation type and a stable qualified name.

The discovery layer does not perform planning, pushdown or federation. It simply
allows a consumer such as NoSQLServer to ask a database source what relations it
exposes before binding one of them as an external relational source.


## v0.46 relational-source conformance

A new `.DatabaseSourceConformanceSuite` verifies the neutral relational-source
boundary independently from backend conformance.

It checks identity shape, effective capability enumeration, capability-gated
relation discovery, relation descriptors, table binding identity, table metadata
and typed row/result shape.

Providers that do not advertise `TABLEDISCOVERY` are skipped for discovery
rather than failed. Providers that advertise it but return malformed catalogue
or table objects fail conformance.

The suite deliberately does not test federation, planner pushdown, joins, or
MySQL-wire behavior.


## v0.46 schema-qualified relation binding

Relation discovery already returned schema-qualified descriptors, but the v0.34
binding path discarded `schemaName` and rebound only `relation~name`. That is
ambiguous for PostgreSQL databases containing the same relation name in more
than one schema.

v0.46 preserves the descriptor through binding:

- `.DatabaseRelationalSource~relation(descriptor)`
- `.DatabaseTableSource~schemaName`
- `.DatabaseTableSource~qualifiedName`
- `.Database~relationMetadata(schemaName, tableName)`
- `.Database~queryRelation(schemaName, tableName)`
- engine `metadataQueryForRelation` / `qualifiedRelationName`

Relation identifiers are quoted by the backend engine rather than concatenated raw; embedded quote delimiters are escaped per backend.
The old `table(name)`, `tableMetadata(name)` and `queryTable(name)` surfaces
remain as current/default-schema compatibility wrappers.

This is still a database-core concern: preserving the identity of a relation
that the database itself exposes. It adds no federation or planner behavior.


## v0.46 relation identity preservation

Schema-qualified discovery is now carried through the complete relational-source
contract rather than being merely available on the discovery descriptor.

`.DatabaseTableSource` retains:

- `tableName`
- `schemaName`
- `relationType`
- backend-quoted `qualifiedName`

`.DatabaseSourceIdentity` retains compatibility `name` while adding `schemaName`
and `qualifiedName`. This keeps old consumers working while allowing two
relations with the same bare name in different schemas to remain unambiguous.

Source conformance now verifies that a discovered descriptor's name, schema and
relation type survive binding. New multi-schema tests prove that
`public.customer` and `archive.customer` route independently to metadata and row
access.

This is identity preservation, not federation or planning.


## v0.46 observational vs row-demand conformance

Relational-source conformance now has an explicit execution boundary:

- `.DatabaseSourceConformanceMode~OBSERVATIONAL`
- `.DatabaseSourceConformanceMode~READ`
- `suite~runObservational(source)`
- `suite~runRead(source)`

The historical `suite~run(source)` behavior remains READ for compatibility.

OBSERVATIONAL conformance checks identity, capabilities, relation discovery,
binding, metadata and `describe()` but deliberately skips `table~rows`.
READ conformance performs the same checks and then crosses the row-demand
boundary exactly once per discovered relation.

This keeps Database Core honest for external/lazy relation consumers:
catalogue/metadata/describe inspection must not be mistaken for permission to
materialize or re-enter a provider. Database Core still does not define provider
materialization, freshness, cursor or federation semantics.


## v0.46 Runtime Registry generation integration

Database Core can now be staged as a generation-private Runtime Registry v0.3
module by bundling `database_core.cls` with the small lifecycle entry class under
`runtime/`.

The integration proves:

- `runtimePrepare`, `runtimeSelfTest`, `runtimeStart`, `runtimeQuiesce` and
  `runtimeStop` lifecycle hooks;
- full Database Core classes are private to each registry generation;
- a transaction created under generation A remains valid while A is DRAINING;
- generation B can be activated concurrently for new work;
- new work after publication uses B;
- A and B expose distinct `.Database` class objects;
- the held A transaction commits after B publication;
- A retires only after its last lease is released, then its package objects can
  be released.

Generation-private constants/classes are accessed through the leased module
(`module~errorClass`, etc.) rather than relying on global `.environment`
visibility. This preserves Runtime Registry package isolation.

Runtime Registry remains an external lifecycle dependency; its source is not
copied into Database Core.


## v0.46 Runtime Registry v0.4 authority compatibility

Database Core's Runtime Registry integration is now validated against
Runtime Registry v0.4.

No lifecycle wrapper API change was required. Database Core already interacted
through `RuntimeKernel`, which is the correct authority-owning boundary.

The new integration test proves:

- a lease may inspect its generation;
- direct `beginDrain()` and `releaseObjects()` attempts are denied with
  `LIFECYCLE_AUTHORITY_REQUIRED`;
- denied lifecycle escape leaves the held generation ACTIVE and usable;
- a Database Core transaction begun on that lease still validates;
- registry-owned activation legitimately moves the old generation to DRAINING;
- the held old-generation transaction commits after publication of the new
  generation;
- new work sees the new generation;
- generation-private Database classes remain isolated;
- retirement/release occurs only through registry-owned lifecycle operations.

This composes Database Core transaction lifetime with Runtime Registry v0.4's
authority-bound code-generation lifetime without coupling database semantics to
registry internals.


## v0.46 Runtime execution evidence bridge

Database Core remains independent of Runtime Registry classes, but transactions
can now carry an optional opaque `.DatabaseExecutionContext`. The context holds
an evidence object, locator and caller-owned attributes without interpreting the
evidence type. If the evidence object offers `provenance()`, the context may
project that provenance without flattening or replacing the original object.

`Database~transaction(context)` and `DatabaseTransaction~setExecutionContext`
accept the neutral carrier while a transaction is BUILDING.
`.DatabaseTransactionResult` retains the exact context/evidence object by
identity. Once execution has begun/completed the transaction context cannot be
changed.

The Runtime Registry wrapper adds `beginTransactionWithEvidence(evidence,
locator)` as a convenience only. The current v0.11 integration proves that:

- `lease~generation` is a read-only `RuntimeGenerationView`;
- detached `lease~executionEvidence` can be attached to a Database Core
  transaction without importing Runtime Registry into database_core.cls;
- a transaction begun on generation A retains A evidence after generation B is
  activated;
- a transaction begun on B retains distinct B evidence;
- detached A evidence remains usable after the A lease is released.

This is provenance transport, not lifecycle authority. Database Core neither
creates nor validates Runtime Registry execution evidence.


## v0.46 execution context propagation

Transaction execution context is now retained by detached results, not only by
`.DatabaseTransactionResult`.

All `.DatabaseResult` objects can carry an opaque `executionContext`, expose
`evidence` when the context provides it, and expose `provenance` without
interpreting the evidence type.

During a transaction the same context object is propagated to:

- final `.DatabaseCommandResult`;
- parsed `.DatabaseMutationResult` objects;
- `.DatabaseDeferredResult` references;
- resolved `.DatabaseQueryResult` objects;
- `.DatabaseTransactionResult`.

A transaction may replace its context only while still in `building` state.
Already-created deferred query references are updated to that replacement.
After execution begins, context replacement remains `INVALIDSTATE`.

This keeps Runtime Registry evidence, legal/evidence objects, or other rich
provenance attached when individual results leave the transaction object while
Database Core remains unaware of the producing framework.


## v0.46 retry-attempt evidence

Retried transactions now preserve every physical execution attempt instead of
only the final command result.

`.DatabaseExecutionAttempt` records:

- attempt number;
- attempt status/error;
- the exact command result for that attempt;
- whether the classified failure was retryable;
- the transaction execution context/evidence.

`.DatabaseTransactionResult~attempts` exposes the ordered attempt trail and
`lastAttempt` returns the final entry. Existing `attemptCount` and
`commandResult` semantics remain unchanged for compatibility.

The attempt trail is populated for successful first attempts, successful retries,
non-retryable failures and `NOTEXECUTED` validation/compilation failures. This
makes retry behavior auditable without teaching Database Core what the attached
provenance/evidence object means.


## v0.46 logical transaction identity

Database Core now distinguishes a logical transaction from its physical retry
attempts.

`.DatabaseTransactionIdentity` supplies a stable transaction ID. A transaction
creates one automatically, or callers may provide an explicit identity.

Every `.DatabaseExecutionAttempt` carries `transactionId`, `attemptNumber` and a
deterministic `attemptId` of `<transactionId>:attempt:<n>`.
`.DatabaseTransactionResult` retains the same logical identity.

This lets higher-level provenance distinguish one logical transaction retried
several times from several independent transactions without coupling Database
Core to any provenance framework.


## v0.46 stable operation identity

Every operation added to a logical transaction now receives a stable,
transaction-scoped identity:

- `transactionId`
- `operationSequence`
- `operationId` = `<transactionId>:op:<n>`

The identity is assigned once by the owning transaction and cannot be rebound to
a different transaction or sequence. Physical transaction retries reuse the
same operation objects and therefore the same operation IDs.

`.DatabaseDeferredResult` exposes its producing `operationId` / `transactionId`.
`.DatabaseTransactionResult~operationIds` exposes the logical operation IDs in
transaction order.

This allows grouped SQL, prepared declarations/executions, savepoints, deferred
query results and retry evidence to be correlated without using SQL text or
array position as identity. It remains a Database Core execution identity, not
a federation/planner concept.


## v0.46 result-to-operation correlation

Concrete query and mutation results now retain the stable logical operation
identity introduced in v0.44.

Every `.DatabaseResult` can expose producing `transactionId`, `operationId` and
`operationSequence`. Deferred query resolution assigns the identity of its
producer operation directly to the resulting `.DatabaseQueryResult`.

Mutation results are correlated to mutation-producing operations in logical
transaction order. Prepared batches intentionally map all member mutation
results to the single logical batch `operationId`.

Commit also normalizes operation identity across the complete public
`tx~operations` collection before planning. This preserves historical callers
that directly appended a `DatabasePreparedBatch`, while ensuring those
operations receive stable identities rather than silently bypassing v0.44's
append helper.


## v0.46 pre-execution transaction manifest

Transactions now expose a stable descriptive manifest before execution.

`.DatabaseTransactionManifest` carries transaction identity, isolation/access
mode, timeout, retry count, execution context and an ordered collection of
`.DatabaseOperationDescriptor` objects.

Descriptors expose stable transaction/operation IDs, operation type/tag and
only the execution metadata appropriate to that operation:

- SQL text for direct statements and prepared declarations;
- prepared statement name plus parameter count for prepared executions;
- prepared statement name plus batch count for prepared batches;
- savepoint name for savepoint operations;
- expected-result intent for query-producing operations.

Prepared parameter values are deliberately not copied into the manifest.

The manifest is descriptive only: Database Core does not authorize, reject,
rewrite or plan based on it. Higher layers may inspect it before `commit()`.
Committed and locally rolled-back transaction results retain the manifest that
describes the logical operation set involved.
