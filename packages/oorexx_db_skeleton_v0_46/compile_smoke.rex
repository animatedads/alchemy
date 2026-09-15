conn = .DatabaseConnection~new("db.example", 5432, "accounts", "appuser", .nil, "postgresql")
db = .Database~new(conn)
tx = db~transaction
tx~execute("UPDATE accounts SET balance = balance - 10 WHERE id = 1")
sp = tx~savepoint("before_more")
tx~rollbackTo(sp)
plan = tx~prepare
cmd = db~engine~compile(plan)

call assert cmd~engineName = "postgresql", "postgres engine name"
call assert cmd~executable = "psql", "postgres executable"
call assert cmd~arguments~items = 14, "postgres argument count"
call assert cmd~arguments[1] = "-X", "postgres no startup"
call assert cmd~arguments[2] = "--no-psqlrc", "postgres no psqlrc"
call assert cmd~arguments[3] = "-v", "postgres variable flag"
call assert cmd~arguments[4] = "ON_ERROR_STOP=1", "postgres stop on error"
call assert cmd~arguments[5] = "-A", "postgres unaligned"
call assert cmd~arguments[6] = "-F", "postgres field separator flag"
call assert cmd~arguments[7] = "09"x, "postgres tab separator"
call assert cmd~arguments[8] = "-h", "postgres host flag"
call assert cmd~arguments[9] = "db.example", "postgres host"
call assert cmd~arguments[10] = "-p", "postgres port flag"
call assert cmd~arguments[11] = 5432, "postgres port"
call assert cmd~arguments[12] = "-U", "postgres user flag"
call assert cmd~arguments[13] = "appuser", "postgres user"
call assert cmd~arguments[14] = "accounts", "postgres database"
call assert cmd~stdinText~pos("BEGIN;") > 0, "postgres begin"
call assert cmd~stdinText~pos("UPDATE accounts") > 0, "postgres statement"
call assert cmd~stdinText~pos("SAVEPOINT before_more;") > 0, "postgres savepoint"
call assert cmd~stdinText~pos("ROLLBACK TO SAVEPOINT before_more;") > 0, "postgres rollback savepoint"
call assert cmd~stdinText~pos("COMMIT;") > 0, "postgres commit"

conn2 = .DatabaseConnection~new("mysql.example", 3306, "accounts", "appuser", .nil, "mysql")
db2 = .Database~new(conn2)
tx2 = db2~transaction
tx2~query("SELECT id FROM accounts")
cmd2 = db2~engine~compile(tx2~prepare)

call assert cmd2~engineName = "mysql", "mysql engine name"
call assert cmd2~executable = "mysql", "mysql executable"
call assert cmd2~arguments~items = 9, "mysql argument count"
call assert cmd2~arguments[1] = "--batch", "mysql batch"
call assert cmd2~arguments[2] = "--raw", "mysql raw"
call assert cmd2~arguments[3] = "--host", "mysql host flag"
call assert cmd2~arguments[4] = "mysql.example", "mysql host"
call assert cmd2~arguments[5] = "--port", "mysql port flag"
call assert cmd2~arguments[6] = 3306, "mysql port"
call assert cmd2~arguments[7] = "--user", "mysql user flag"
call assert cmd2~arguments[8] = "appuser", "mysql user"
call assert cmd2~arguments[9] = "accounts", "mysql database"
call assert cmd2~stdinText~pos("SELECT id FROM accounts;") > 0, "mysql statement"

say "DATABASE COMPILE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
