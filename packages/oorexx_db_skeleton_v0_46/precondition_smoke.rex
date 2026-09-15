pg = .PostgreSQLResultParser~new
pgRs = .DatabaseCommandResult~new(2, "", "psql: error: connection to server at ""localhost"" failed: Connection refused", .nil, "PROCESS")
call assert pg~classifyError(pgRs) = .Error~CONNECTIONFAILED, "postgres precondition connection"

my = .MySQLResultParser~new
myRs = .DatabaseCommandResult~new(1, "", "ERROR 1044 (42000): Access denied for user ''@'localhost' to database 'mysql'", .nil, "PROCESS")
call assert my~classifyError(myRs) = .Error~PERMISSIONDENIED, "mysql precondition permission"

say "DATABASE ERROR PROBE PRECONDITION SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
