# NoSQLServer v0.32 — database_core v0.22 compatibility adapter

NoSQLServer does **not** load `database_core.cls` into the same ooRexx package.
Both projects publish classes such as `.Error`, `.DatabaseRow`, `.DatabaseValue`,
`.DatabaseTransaction`, and prepared-statement classes with differing observable
semantics. v0.32 therefore adds a namespaced compatibility facade over the native
file engine.

## Entry point

```rexx
db = .FileDatabaseEngine~new(root)
core = db~databaseCore
```

`core` is a `.NoSQLDatabaseCoreAdapter`. The native `db` API is unchanged.

## Result semantics

Compatibility transaction results separate status and outcome:

- successful commit: `status=SUCCESS`, `outcome=COMMITTED`, `error=SUCCESS`;
- staged failure: `status=ROLLEDBACK`, `outcome=ROLLEDBACK`;
- rejection before staged execution: `status=NOTEXECUTED`, `outcome=NOTEXECUTED`.

They expose `operationCount`, `attemptCount`, `mutationResults`, `committed`,
`rolledBack`, and `retried`.

## Rows and values

Native NoSQLServer rows retain their existing API:

```rexx
row~at("id")       -- scalar
row~valueAt("id")  -- native DatabaseValue
```

Compatibility rows intentionally invert this to the database_core v0.22
contract:

```rexx
row~at("id")       -- NoSQLDatabaseCoreValue
row~rawAt("id")    -- raw/native representation
row~valueAt("id")  -- typed scalar
```

Compatibility values expose both `raw`/`rawValue` and `isNull`/`null` aliases.
The native row/value classes are not changed.

## Metadata and explicit result schemas

`core~tableMetadata(name)` returns compatibility column metadata with:

- `name`
- `engineType`
- `databaseType`
- `nullable`
- `ordinal`

`metadata~types` returns common database types in ordinal order.

Use:

```rexx
schema = core~resultSchema
schema~add("id", .DatabaseType~INTEGER)
schema~add("total", .DatabaseType~DECIMAL)
qr = core~queryWithSchema(sql, schema)
```

The query's own output column names are preserved. The schema type vector is
applied by output ordinal. Contradictory provable metadata or failed typed
conversion returns `INVALIDPARAMETER`; values are not blindly coerced.

## Ordered mutation results

Native transactions now retain successful per-mutation results internally so the
adapter can expose ordered `.NoSQLDatabaseCoreMutationResult` objects. Prepared
batches preserve one result per batch member rather than only the summed count.
`generatedKey` is reserved and remains `.nil` unless genuine generated-key
semantics are later added.

## Retry and concurrency mapping

The adapter maps NoSQLServer generation/signature publication conflicts to
`SERIALIZATIONFAILURE`. `tx~setRetryAttempts(n)` replays the **whole transaction**
from a fresh native snapshot only for retryable concurrency errors. Deferred
query references resolve only from the final successful replay.

## Transaction policy

The adapter supports:

- `DEFAULT` isolation;
- `SERIALIZABLE`, mapped to NoSQLServer's stable transaction clone plus final
  live-signature conflict check / optimistic publication rule;
- `READONLY`, rejecting mutation SQL before it is queued;
- `READWRITE`.

`READUNCOMMITTED`, `READCOMMITTED`, and `REPEATABLEREAD` return `UNSUPPORTED`
rather than pretending to map to distinct native implementations.

`setTimeout(seconds)` currently returns `UNSUPPORTED`; NoSQLServer does not
advertise `TRANSACTION_TIMEOUT` because v0.32 has no enforceable transaction
execution deadline.

## Capabilities

v0.32 advertises:

- `DATABASE_CORE_ADAPTER`
- `RESULT_SCHEMA`
- `MUTATION_RESULTS`
- `PREPARED_MUTATION_RESULTS`
- `TRANSACTION_RETRY`
- `TRANSACTION_ISOLATION`
- `TRANSACTION_READ_ONLY`

It deliberately does not advertise `TRANSACTION_TIMEOUT` or `GENERATED_KEYS`.
