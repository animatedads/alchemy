/* A native ooRexx regression: selected SQLite must not enter either
 * persistence path if the provider exposes BEGIN but lacks COMMIT/ROLLBACK.
 * No SQL driver or database connection is needed for this fail-closed test.
 */
/* Add an injection method to the BASE class for this test process only.
 * A subclass's EXPOSE db would access its own separate scope in ooRexx. */
probeSource = .Array~of('expose db', 'use strict arg selected', 'db = selected')
.MiniNotesPersistence~define('injectDatabaseForTest', .Method~new('injectDatabaseForTest', probeSource))
checks = 0
fakeFull = .BeginOnlySqlBackend~new
full = .TransactionGuardPersistence~new
full~injectDatabaseForTest(fakeFull)
signal on syntax name fullRejected
ignore = full~saveFrom(.nil)
say "FAIL: SQLite full snapshot accepted incomplete transaction API"
exit 1
fullRejected:
fullError = condition("O")
if pos("Indexed SQLite requires begin, commit and rollback", fullError["MESSAGE"]) = 0 then do
  say "FAIL: wrong full-save rejection:" fullError["MESSAGE"]
  exit 1
end
signal off syntax
if fakeFull~beginCalls <> 0 | fakeFull~ddlCalls <> 0 then do
  say "FAIL: SQLite full snapshot executed SQL before transaction capability check"
  exit 1
end
checks = checks + 1

fakeDelta = .BeginOnlySqlBackend~new
delta = .TransactionGuardPersistence~new
delta~injectDatabaseForTest(fakeDelta)
if \delta~hasMethod("saveDocumentOnly") then do
  say "FAIL: production delta method not loaded"; exit 1
end
signal on syntax name deltaRejected
ignore = delta~saveDocumentOnly(.nil, .Table~new)
say "FAIL: SQLite document delta accepted incomplete transaction API"
exit 1
deltaRejected:
deltaError = condition("O")
if pos("Indexed SQLite single-document transaction methods unavailable", deltaError["MESSAGE"]) = 0 then do
  say "FAIL: wrong delta-save rejection:" deltaError["MESSAGE"]
  exit 1
end
signal off syntax
if fakeDelta~beginCalls <> 0 | fakeDelta~readCalls <> 0 then do
  say "FAIL: SQLite document delta executed SQL before transaction capability check"
  exit 1
end
checks = checks + 1
say "NOTNOTES_SQLITE_TRANSACTION_CAPABILITY_GUARD_PASS checks=" checks
exit 0

/* Inherited persistence methods under test; skip normal database startup. */
::class TransactionGuardPersistence subclass MiniNotesPersistence
::method init
  return

/* BEGIN exists, COMMIT and ROLLBACK do NOT: a dangerous partial adapter. */
::class BeginOnlySqlBackend
::method init
  expose began ddl reads
  began = 0; ddl = 0; reads = 0
::method backendId
  return "rexxsql-sqlite"
::method beginTransaction
  expose began
  began = began + 1
  return .Directory~new
::method dropTable
  expose ddl
  use strict arg tableName
  ddl = ddl + 1
  raise syntax 93.900 array("DDL must never be reached")
::method selectWhereEquals
  expose reads
  use strict arg tableName, column, wanted
  reads = reads + 1
  raise syntax 93.900 array("SELECT must never be reached")
::method deleteWhereEquals
  raise syntax 93.900 array("DELETE must never be reached")
::method beginCalls
  expose began
  return began
::method ddlCalls
  expose ddl
  return ddl
::method readCalls
  expose reads
  return reads

::requires 'src/MiniNotesPersistence.cls'
