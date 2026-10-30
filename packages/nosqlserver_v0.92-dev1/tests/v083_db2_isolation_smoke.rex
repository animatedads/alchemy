root=.NoSQLServerTestSupport~createBlankDatabase("v083_db2")
engine=.FileDatabaseEngine~new(root)
db2=.NoSQLServerDB2Personality~new(engine, "APPUSER", "APP")

call ok db2~execute("CREATE TABLE APP.account (id INTEGER PRIMARY KEY, balance INTEGER)")
call ok db2~execute("INSERT INTO APP.account VALUES (1,100),(2,200)")

r=db2~execute("VALUES CURRENT ISOLATION")
call assert r~status=.Error~SUCCESS, "current isolation special register query"
call assert r~rows[1]["CURRENT ISOLATION"]="", "current isolation initially reset/package default"

call ok db2~execute("SET CURRENT ISOLATION = REPEATABLE READ")
call assert db2~currentIsolation="RR", "repeatable read alias maps to RR"
r=db2~execute("VALUES CURRENT ISOLATION")
call assert r~rows[1]["CURRENT ISOLATION"]="RR", "current isolation reports RR"

r=db2~execute("SET CURRENT ISOLATION CS")
call assert r~error=.Error~SQLUNSUPPORTED, "CS rejected rather than silently strengthened"
r=db2~execute("SET CURRENT ISOLATION UR")
call assert r~error=.Error~SQLUNSUPPORTED, "UR rejected rather than pretending dirty reads"
r=db2~execute("SET CURRENT ISOLATION RS")
call assert r~error=.Error~SQLUNSUPPORTED, "RS rejected rather than silently strengthened"

r=db2~execute("SELECT * FROM APP.account WITH RR")
call assert r~error=.Error~SQLUNSUPPORTED, "statement isolation requires explicit personality transaction"

tx=db2~transaction
call assert tx~isolationLevel="RR", "transaction inherits current RR session isolation"
q=tx~query("SELECT id,balance FROM APP.account WHERE id=1 WITH RR")
c=tx~commit
call assert c~status=.Error~COMMITTED, "RR read transaction committed"
call assert q~status=.Error~SUCCESS, "deferred RR query resolved"
call assert q~rows~items=1, "RR query row count"
call assert q~rows[1]~valueAt("balance")~value=100, "RR read observes transaction snapshot"

-- A concurrent publication after BEGIN invalidates the snapshot rather than
-- silently weakening RR semantics.
tx=db2~transaction
call assert tx~execute("UPDATE APP.account SET balance=125 WHERE id=1")~error=.Error~SUCCESS, "RR mutation queued"
call ok db2~execute("UPDATE APP.account SET balance=110 WHERE id=2")
c=tx~commit
call assert c~status=.Error~NOTEXECUTED, "RR concurrent publication is not executed"
call assert c~error=.Error~TRANSACTIONFAILED, "RR conflict reported as transaction failure"

-- A fresh RR transaction can then commit normally.
tx=db2~transaction
call assert tx~execute("UPDATE APP.account SET balance=125 WHERE id=1")~error=.Error~SUCCESS, "fresh RR mutation queued"
c=tx~commit
call assert c~status=.Error~COMMITTED, "fresh RR mutation committed"
r=db2~execute("SELECT balance FROM APP.account WHERE id=1")
call assert r~rows[1]~valueAt("balance")~value=125, "committed update visible"

call ok db2~execute("SET CURRENT ISOLATION RESET")
call assert db2~currentIsolation="", "RESET clears current isolation"

info=db2~version
call assert info~personalityLevel="0.4", "personality level"
call assert info~supports("DB2_CURRENT_ISOLATION"), "current isolation capability"
call assert info~supports("DB2_RR_TRANSACTION"), "RR transaction capability"
call assert engine~version~supports("TRANSACTION_ISOLATION"), "backend retains transaction isolation capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.83 DB2 ISOLATION SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "setup/statement: " || rs~message
  return

assert: procedure
  use arg condition,message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServerDB2Personality.cls"
::requires "TestSupport.cls"
