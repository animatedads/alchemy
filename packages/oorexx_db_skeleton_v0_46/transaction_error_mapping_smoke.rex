pgConn = .DatabaseConnection~new("localhost", 5432, "postgres", "", .nil, "postgresql")
pgExec = .PostgresFailureExecutor~new
pgDb = .Database~new(pgConn, .nil, pgExec)
pgTx = pgDb~transaction
pgTx~execute("SELECT 1")
pgResult = pgTx~commit
call assert pgResult~status = .Error~ROLLEDBACK, "postgres rollback status"
call assert pgResult~error = .Error~CONNECTIONFAILED, "postgres mapped connection error"

myConn = .DatabaseConnection~new("localhost", 3306, "mysql", "", .nil, "mysql")
myExec = .MySQLFailureExecutor~new
myDb = .Database~new(myConn, .nil, myExec)
myTx = myDb~transaction
myTx~execute("SELECT 1")
myResult = myTx~commit
call assert myResult~status = .Error~ROLLEDBACK, "mysql rollback status"
call assert myResult~error = .Error~PERMISSIONDENIED, "mysql mapped permission error"

say "DATABASE TRANSACTION ERROR MAPPING SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class PostgresFailureExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  return .DatabaseCommandResult~new(2, "", "psql: error: connection to server at ""localhost"" failed: Connection refused", command, "PROCESS")

::class MySQLFailureExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  return .DatabaseCommandResult~new(1, "", "ERROR 1044 (42000): Access denied for user ''@'localhost' to database 'mysql'", command, "PROCESS")

::requires "database_core.cls"
