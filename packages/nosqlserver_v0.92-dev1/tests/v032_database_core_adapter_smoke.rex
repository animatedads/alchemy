parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v032_core_adapter")
db = .FileDatabaseEngine~new(root)
core = db~databaseCore

call assert core~isA(.NoSQLDatabaseCoreAdapter), "databaseCore facade"
call assert db~version~product = "NoSQLServer", "version product"
call assert db~version~supports("TRANSACTION_RETRY"), "adapter capability survives newer release"
call assert db~version~supports("DATABASE_CORE_ADAPTER"), "adapter capability"
call assert db~version~supports("RESULT_SCHEMA"), "result schema capability"
call assert db~version~supports("MUTATION_RESULTS"), "mutation result capability"
call assert db~version~supports("TRANSACTION_RETRY"), "retry capability"
call assert db~version~supports("TRANSACTION_ISOLATION"), "isolation capability"
call assert db~version~supports("TRANSACTION_READ_ONLY"), "read-only capability"
call assert .Error~SERIALIZATIONFAILURE = "SERIALIZATIONFAILURE", "serialization constant"
call assert .Error~DEADLOCK = "DEADLOCK", "deadlock constant"
call assert .Error~LOCKTIMEOUT = "LOCKTIMEOUT", "lock timeout constant"

createRs = core~execute("CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR NOT NULL, amount DECIMAL, active BOOLEAN)")
call assert createRs~status = .Error~SUCCESS, "compat create status"
call assert createRs~outcome = .Error~COMMITTED, "compat create outcome"
call assert createRs~committed, "compat create committed"
call assert createRs~attemptCount = 1, "compat create attempt count"

/* Core-compatible transaction result normalization + deferred query + ordered mutations. */
tx = core~transaction
ignore = tx~execute("INSERT INTO people (id,name,amount,active) VALUES (1,'Ada',12.50,TRUE)")
ignore = tx~execute("INSERT INTO people (id,name,amount,active) VALUES (2,'Grace',20.00,FALSE)")
ref = tx~query("SELECT id,name,amount,active FROM people ORDER BY id")
call assert \ref~resolved, "deferred unresolved before commit"
commitRs = tx~commit
call assert commitRs~status = .Error~SUCCESS, "commit normalized success status"
call assert commitRs~outcome = .Error~COMMITTED, "commit outcome"
call assert commitRs~error = .Error~SUCCESS, "commit error"
call assert commitRs~operationCount = 3, "operation count"
call assert commitRs~attemptCount = 1, "attempt count"
call assert \commitRs~retried, "not retried"
call assert commitRs~mutationResults~items = 2, "ordered mutation result count"
call assert commitRs~mutationResults[1]~affectedRows = 1, "first mutation rows"
call assert commitRs~mutationResults[2]~affectedRows = 1, "second mutation rows"
call assert commitRs~mutationResults[1]~generatedKey == .nil, "generated key reserved nil"
call assert ref~resolved, "deferred resolved after commit"
qr = ref~result
call assert qr~rowCount = 2, "deferred query rows"
call assert qr~rows[1]~at("id")~isA(.NoSQLDatabaseCoreValue), "row at returns value adapter"
call assert qr~rows[1]~valueAt("id") = 1, "row valueAt scalar"
call assert qr~rows[1]~rawAt("name") = "Ada", "row rawAt"
call assert qr~rows[1]~at("active")~value = .true, "boolean typed scalar"
call assert qr~nativeResult~accessPath \= "", "native result preserved"

/* Metadata aliases. */
meta = core~tableMetadata("people")
call assert meta~columns~items = 4, "metadata columns"
call assert meta~columns[1]~name = "id", "metadata name"
call assert meta~columns[1]~engineType = "INTEGER", "metadata engine type"
call assert meta~columns[1]~databaseType = .DatabaseType~INTEGER, "metadata common type"
call assert meta~columns[1]~ordinal = 1, "metadata ordinal"
call assert meta~types[1] = .DatabaseType~INTEGER, "metadata types vector"

/* Explicit result schema applies types by output ordinal. */
schema = core~resultSchema
ignore = schema~add("first", .DatabaseType~INTEGER)
ignore = schema~add("second", .DatabaseType~DECIMAL)
typed = core~queryWithSchema("SELECT id,amount FROM people ORDER BY id", schema)
call assert typed~status = .Error~SUCCESS, "queryWithSchema success"
call assert typed~columns[1] = "id", "query output name preserved"
call assert typed~columns[2] = "amount", "query second output name preserved"
call assert typed~columnTypes[1] = .DatabaseType~INTEGER, "explicit integer type"
call assert typed~columnTypes[2] = .DatabaseType~DECIMAL, "explicit decimal type"
call assert typed~rows[1]~at("id")~typeName = .DatabaseType~INTEGER, "typed integer value"
call assert typed~rows[1]~at("amount")~typeName = .DatabaseType~DECIMAL, "typed decimal value"

badSchema = core~resultSchema
ignore = badSchema~add("name_as_integer", .DatabaseType~INTEGER)
badTyped = core~queryWithSchema("SELECT name FROM people ORDER BY id", badSchema)
call assert badTyped~error = .Error~INVALIDPARAMETER, "bad typed result rejected"

qt = core~queryTable("people")
call assert qt~status = .Error~SUCCESS, "queryTable success"
call assert qt~columnTypes[1] = .DatabaseType~INTEGER, "queryTable integer metadata applied"
call assert qt~rows[1]~at("name")~typeName = .DatabaseType~VARCHAR, "queryTable varchar"

typedTx = core~transaction
typedRef = typedTx~queryWithSchema("SELECT id,amount FROM people WHERE id=1", schema)
typedCommit = typedTx~commit
call assert typedCommit~status = .Error~SUCCESS, "transaction queryWithSchema commit"
call assert typedRef~resolved, "transaction queryWithSchema deferred resolved"
call assert typedRef~result~columnTypes[1] = .DatabaseType~INTEGER, "transaction schema integer"
call assert typedRef~result~rows[1]~at("amount")~typeName = .DatabaseType~DECIMAL, "transaction schema decimal"

/* Read-only and isolation policy are honest. */
ro = core~transaction
call assert ro~readOnly = .Error~SUCCESS, "readOnly accepted"
roMutation = ro~execute("UPDATE people SET amount=99 WHERE id=1")
call assert roMutation~status = .Error~NOTEXECUTED, "readOnly mutation rejected before staging"
call assert roMutation~error = .Error~INVALIDOPERATION, "readOnly mutation error"
ignore = ro~rollback

iso = core~transaction
call assert iso~isolation(.NoSQLDatabaseCoreIsolation~SERIALIZABLE) = .Error~SUCCESS, "serializable accepted"
call assert iso~isolation(.NoSQLDatabaseCoreIsolation~READCOMMITTED) = .Error~UNSUPPORTED, "unsupported isolation honest"
call assert iso~setTimeout(5) = .Error~UNSUPPORTED, "timeout not silently ignored"
ignore = iso~rollback

/* Publication conflict maps to serialization failure; whole transaction retry succeeds. */
conflict = core~transaction
ignore = conflict~execute("INSERT INTO people (id,name,amount,active) VALUES (3,'Conflict',1,TRUE)")
direct = db~execute("INSERT INTO people (id,name,amount,active) VALUES (4,'Outside',2,TRUE)")
call assert direct~status = .Error~SUCCESS, "outside mutation"
conflictRs = conflict~commit
call assert conflictRs~status = .Error~NOTEXECUTED, "conflict not executed"
call assert conflictRs~outcome = .Error~NOTEXECUTED, "conflict outcome"
call assert conflictRs~error = .Error~SERIALIZATIONFAILURE, "conflict classification"

retry = core~transaction
call assert retry~setRetryAttempts(2) = .Error~SUCCESS, "retry attempts set"
ignore = retry~execute("INSERT INTO people (id,name,amount,active) VALUES (5,'Retry',3,TRUE)")
retryRef = retry~query("SELECT id FROM people WHERE id >= 5 ORDER BY id")
direct2 = db~execute("INSERT INTO people (id,name,amount,active) VALUES (6,'Outside2',4,TRUE)")
call assert direct2~status = .Error~SUCCESS, "outside mutation two"
retryRs = retry~commit
call assert retryRs~status = .Error~SUCCESS, "retry final status"
call assert retryRs~outcome = .Error~COMMITTED, "retry final outcome"
call assert retryRs~attemptCount = 2, "retry attempt count"
call assert retryRs~retried, "retried flag"
call assert retryRef~resolved, "retry deferred resolved only after success"
call assert retryRef~result~rowCount = 2, "retry deferred sees final snapshot rows"
call assert retryRef~result~rows[1]~valueAt("id") = 5, "retry deferred transaction row"
call assert retryRef~result~rows[2]~valueAt("id") = 6, "retry deferred concurrent row from fresh snapshot"
call assert db~query("SELECT * FROM people WHERE id=5")~rows~items = 1, "retry mutation committed"

/* database_core operationCount includes declarations/savepoint control operations. */
countTx = core~transaction
ignore = countTx~execute("UPDATE people SET amount=12.50 WHERE id=1")
countQ = countTx~query("SELECT id FROM people WHERE id=1")
countPs = countTx~prepareStatement("count_select", "SELECT id FROM people WHERE id = ?")
countParams = .array~new; countParams~append(.DatabaseValue~integer(1))
ignore = countTx~executePrepared(countPs, countParams)
countPreparedQ = countTx~queryPrepared(countPs, countParams)
countSp = countTx~savepoint("count_sp")
ignore = countTx~rollbackTo(countSp)
countCommit = countTx~commit
call assert countCommit~status = .Error~SUCCESS, "core-style operation count commit"
call assert countCommit~operationCount = 7, "core-style logical operation count"
call assert countQ~resolved, "core-style ordinary deferred query"
call assert countPreparedQ~resolved, "core-style prepared deferred query"

/* Prepared batch preserves one mutation result per execution. */
ptx = core~transaction
ps = ptx~prepareStatement("pinsert", "INSERT INTO people (id,name,amount,active) VALUES (?, ?, ?, ?)")
call assert ps~error = .Error~SUCCESS, "prepared declaration"
batch = ptx~prepareBatch(ps)
p7 = .array~new; p7~append(.DatabaseValue~integer(7)); p7~append(.DatabaseValue~varchar("Seven")); p7~append(.DatabaseValue~decimal(7)); p7~append(.DatabaseValue~boolean(.true)); ignore = batch~add(p7)
p8 = .array~new; p8~append(.DatabaseValue~integer(8)); p8~append(.DatabaseValue~varchar("Eight")); p8~append(.DatabaseValue~decimal(8)); p8~append(.DatabaseValue~boolean(.false)); ignore = batch~add(p8)
queuedBatch = ptx~executePreparedBatch(batch)
call assert queuedBatch~error = .Error~SUCCESS, "prepared batch queued"
pcommit = ptx~commit
call assert pcommit~status = .Error~SUCCESS, "prepared batch commit"
call assert pcommit~mutationResults~items = 2, "prepared batch per-member mutation results"
call assert pcommit~mutationResults[1]~affectedRows = 1, "prepared batch first rows"
call assert pcommit~mutationResults[2]~affectedRows = 1, "prepared batch second rows"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.32 DATABASE_CORE ADAPTER SMOKE: OK"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
