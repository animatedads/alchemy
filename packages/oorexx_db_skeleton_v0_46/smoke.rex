call assert .DatabaseConnection <> .nil, "DatabaseConnection class available"
call assert .PostgreSQLEngine <> .nil, "PostgreSQLEngine class available"
call assert .MySQLEngine <> .nil, "MySQLEngine class available"

cred = .DatabaseCredential~new("environment", "DB_PASSWORD")
conn = .DatabaseConnection~new("db.local", 5432, "accounts", "app", cred, "postgresql")
db = .Database~new(conn)
call assert db~engine~name = "postgresql", "engine resolution"

tx = db~transaction
call assert tx~state = "building", "transaction begins building"

tx~execute("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
lookup = tx~query("SELECT id, balance FROM accounts WHERE id = 1")

ps = tx~prepareStatement("insert_audit", "INSERT INTO audit(account_id, note) VALUES (?, ?)")
tx~executePrepared(ps, .array~of(1, "debit"))
qref = tx~queryPrepared(ps, .array~of(2, "credit"))
sp = tx~savepoint("before_optional")
tx~rollbackTo(sp)

plan = tx~prepare
call assert plan~statementCount = 7, "plan operation count"
call assert plan~engine~name = "postgresql", "plan engine"

transactionResult = tx~commit
call assert transactionResult~outcome = .Error~COMMITTED, "NOP commit outcome"
call assert transactionResult~status = .Error~SUCCESS, "commit status constant"
call assert transactionResult~error = .Error~SUCCESS, "commit error constant"
call assert transactionResult~operationCount = 7, "result operation count"
call assert \lookup~resolved, "NOP query result remains unresolved without output"
call assert \qref~resolved, "NOP prepared query remains unresolved without output"
call assert tx~state = "committed", "transaction final state"

conn2 = .DatabaseConnection~new("db.local", 3306, "accounts", "app", .nil, "mysql")
db2 = .Database~new(conn2)
call assert db2~engine~name = "mysql", "mysql engine resolution"

say "DATABASE SKELETON SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
