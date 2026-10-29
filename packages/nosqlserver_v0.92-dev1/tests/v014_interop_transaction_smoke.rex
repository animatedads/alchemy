parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v014_interop")
db = .FileDatabaseEngine~new(root)

call assert .Error~SYNTAXERROR = .Error~SQLPARSEERROR, "shared syntax alias"
call assert .Error~UNSUPPORTED = .Error~SQLUNSUPPORTED, "shared unsupported alias"
call assert .Error~CONSTRAINTVIOLATION = .Error~CONSTRAINT, "shared constraint alias"
call assert .Error~DUPLICATEKEY = .Error~CONSTRAINT, "shared duplicate-key alias"
call assert .DatabaseOperationType~QUERY = .DatabaseOperationType~SELECT, "query/select operation alias"
call assert .DatabaseOperationType~CREATE = .DatabaseOperationType~CREATE_TABLE, "create operation alias"

v = db~version
call assert v~release = .NoSQLServerBuild~RELEASE, "version release"
call assert v~supports("TRANSACTIONS"), "transactions capability"
call assert v~supports("SAVEPOINTS"), "savepoints capability"
call assert v~supports("PREPARED_STATEMENTS"), "prepared capability"
call assert v~supports("PREPARED_BATCH"), "prepared batch capability"
call assert v~supports("TYPED_RESULTS"), "typed results capability"
call assert v~supports("RESULT_METADATA"), "metadata capability"

rs = db~execute("CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR NOT NULL)")
call assertSuccess rs, "create people"

/* Atomic commit + deferred query. */
tx = db~transaction
queued = tx~execute("INSERT INTO people (id,name) VALUES (1,'Ada')")
call assert queued~status = .Error~NOTEXECUTED, "queued execute not executed"
q = tx~query("SELECT * FROM people ORDER BY id")
call assert q~status = .Error~NOTEXECUTED, "query deferred before commit"
call assert q~rows~items = 0, "deferred query has no invented rows"
commitRs = tx~commit
call assert commitRs~status = .Error~COMMITTED, "commit status"
call assert commitRs~error = .Error~SUCCESS, "commit success error"
call assert q~status = .Error~SUCCESS, "deferred query completed"
call assert q~rows~items = 1, "deferred query row count"
call assert q~rows[1]["id"] = 1, "deferred query row value"
call assert db~query("SELECT * FROM people")~rows~items = 1, "commit visible"
again = tx~commit
call assert again~status = .Error~NOTEXECUTED, "double commit not executed"
call assert again~error = .Error~INVALIDSTATE, "double commit invalid state"

/* Rollback before commit must discard, not report an applied rollback. */
tx2 = db~transaction
ignore = tx2~execute("INSERT INTO people (id,name) VALUES (2,'Grace')")
q2 = tx2~query("SELECT * FROM people WHERE id = 2")
rb = tx2~rollback
call assert rb~status = .Error~NOTEXECUTED, "precommit rollback is not executed"
call assert rb~error = .Error~SUCCESS, "precommit rollback success reason"
call assert q2~status = .Error~NOTEXECUTED, "discarded deferred query remains not executed"
call assert q2~rows~items = 0, "discarded deferred query has no rows"
call assert db~query("SELECT * FROM people WHERE id = 2")~rows~items = 0, "rollback invisible"

/* Commit failure must leave earlier transaction mutations invisible. */
tx3 = db~transaction
ignore = tx3~execute("INSERT INTO people (id,name) VALUES (3,'Linus')")
q3 = tx3~query("SELECT * FROM people WHERE id = 3")
ignore = tx3~execute("INSERT INTO people (id,name) VALUES (1,'Duplicate')")
failed = tx3~commit
call assert failed~status = .Error~ROLLEDBACK, "failed commit rolled back"
call assert failed~error = .Error~TRANSACTIONFAILED, "failed commit reason"
call assert q3~status = .Error~ROLLEDBACK, "deferred query failed with transaction"
call assert q3~rows~items = 0, "failed deferred query has no invented rows"
call assert db~query("SELECT * FROM people WHERE id = 3")~rows~items = 0, "earlier failed tx mutation invisible"

/* Savepoint rewinds queued staged state. */
tx4 = db~transaction
ignore = tx4~execute("INSERT INTO people (id,name) VALUES (4,'Four')")
sp = tx4~savepoint("before_five")
call assert sp~isA(.DatabaseSavepoint), "savepoint object"
ignore = tx4~execute("INSERT INTO people (id,name) VALUES (5,'Five')")
rewind = tx4~rollbackTo(sp)
call assert rewind~status = .Error~NOTEXECUTED, "rollback-to-savepoint remains staged"
call assert rewind~error = .Error~SUCCESS, "rollback-to-savepoint success"
unknown = .DatabaseSavepoint~new("missing", 0, tx4~token)
badSp = tx4~rollbackTo(unknown)
call assert badSp~error = .Error~INVALIDSAVEPOINT, "unknown savepoint error"
commit4 = tx4~commit
call assert commit4~status = .Error~COMMITTED, "savepoint transaction commit"
call assert db~query("SELECT * FROM people WHERE id = 4")~rows~items = 1, "before-savepoint operation retained"
call assert db~query("SELECT * FROM people WHERE id = 5")~rows~items = 0, "after-savepoint operation removed"

/* Prepared statements retain typed parameter objects until commit. */
tx5 = db~transaction
ps = tx5~prepareStatement("insert_person", "INSERT INTO people (id,name) VALUES (?, ?)")
call assert ps~status = .Error~SUCCESS, "prepared declaration success"
duplicatePs = tx5~prepareStatement("insert_person", "INSERT INTO people (id,name) VALUES (?, ?)")
call assert duplicatePs~error = .Error~DUPLICATEPREPARED, "duplicate prepared name"
params = .array~new
params~append(.DatabaseValue~integer(6))
params~append(.DatabaseValue~varchar("O'Brien"))
prepQueued = tx5~executePrepared(ps, params)
call assert prepQueued~status = .Error~NOTEXECUTED, "prepared execution queued"
wrong = .array~new
wrong~append(.DatabaseValue~integer(7))
wrongRs = tx5~executePrepared(ps, wrong)
call assert wrongRs~error = .Error~PARAMETERCOUNT, "prepared parameter count"
invalid = .array~new
invalid~append(.DatabaseValue~integer("not-an-int"))
invalid~append(.DatabaseValue~varchar("bad"))
invalidRs = tx5~executePrepared(ps, invalid)
call assert invalidRs~error = .Error~INVALIDPARAMETER, "invalid prepared numeric"
q5 = tx5~query("SELECT * FROM people WHERE id = 6")
commit5 = tx5~commit
call assert commit5~status = .Error~COMMITTED, "prepared transaction commit"
call assert q5~rows~items = 1, "prepared insert visible to deferred query"
call assert q5~rows[1]["name"] = "O'Brien", "prepared quote preserved"

/* Prepared batch. */
tx6 = db~transaction
psb = tx6~prepareStatement("batch_person", "INSERT INTO people (id,name) VALUES (?, ?)")
batch = tx6~prepareBatch(psb)
p8 = .array~new; p8~append(.DatabaseValue~integer(8)); p8~append(.DatabaseValue~varchar("Eight")); batch~add(p8)
p9 = .array~new; p9~append(.DatabaseValue~integer(9)); p9~append(.DatabaseValue~varchar("Nine")); batch~add(p9)
bq = tx6~executePreparedBatch(batch)
call assert bq~status = .Error~NOTEXECUTED, "prepared batch queued"
commit6 = tx6~commit
call assert commit6~status = .Error~COMMITTED, "prepared batch commit"
call assert db~query("SELECT * FROM people WHERE id >= 8")~rows~items = 2, "prepared batch rows"


/* Compatibility facade alias. */
compatSql = .SQLDatabase~new(db)
call assert compatSql~version~release = .NoSQLServerBuild~RELEASE, "SQLDatabase facade alias"

/* A direct concurrent mutation after transaction start must not be overwritten. */
txConflict = db~transaction
ignore = txConflict~execute("INSERT INTO people (id,name) VALUES (10,'Ten')")
directRs = db~execute("INSERT INTO people (id,name) VALUES (11,'Eleven')")
call assertSuccess directRs, "direct mutation during open transaction"
conflictRs = txConflict~commit
call assert conflictRs~status = .Error~NOTEXECUTED, "precommit conflict not executed"
call assert conflictRs~error = .Error~TRANSACTIONFAILED, "precommit conflict classified"
call assert db~query("SELECT * FROM people WHERE id = 10")~rows~items = 0, "conflicting transaction did not overwrite live database"
call assert db~query("SELECT * FROM people WHERE id = 11")~rows~items = 1, "concurrent direct mutation preserved"

/* Metadata and typed value adapters. */
meta = db~tableMetadata("people")
call assert meta~name = "people", "metadata table name"
call assert meta~columns~items = 2, "metadata column count"
call assert meta~columns[1]~name = "id", "metadata column name"
call assert meta~columns[1]~commonType = .DatabaseType~INTEGER, "metadata common type"
call assert meta~columns[1]~ordinalPosition = 1, "metadata ordinal"
qt = db~queryTable("people")
call assert qt~metadata~name = "people", "queryTable metadata"
row = qt~rows[1]
call assert row~at("id") = row["id"], "row at alias"
value = row~valueAt("id")
call assert value~typeName = .DatabaseType~INTEGER, "typed row value type"
call assert value~value = row["id"], "typed row value"
call assert value~rawValue \== .nil, "typed row raw value"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.14 INTEROP/TRANSACTION SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" label rs~status rs~error rs~message
    exit 1
  end
  return

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
