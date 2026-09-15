pg = .PostgreSQLResultParser~new
pgStderr = "/usr/bin/psql: line 13: /etc/sysconfig/postgresql: No such file or directory" || .endOfLine || -
  "psql: error: connection to server at ""localhost"" (::1), port 5432 failed: Connection refused" || .endOfLine || -
  "Is the server running on that host and accepting TCP/IP connections?"
pgRs = .DatabaseCommandResult~new(2, "", pgStderr, .nil, "PROCESS")
call assert pg~classifyError(pgRs) = .Error~CONNECTIONFAILED, "postgres connection refused"

pgAuth = .DatabaseCommandResult~new(2, "", "psql: error: password authentication failed for user ""bob""", .nil, "PROCESS")
call assert pg~classifyError(pgAuth) = .Error~AUTHENTICATIONFAILED, "postgres authentication"

my = .MySQLResultParser~new
myStderr = "mysql: Deprecated program name." || .endOfLine || -
  "ERROR 1044 (42000): Access denied for user ''@'localhost' to database 'mysql'"
myRs = .DatabaseCommandResult~new(1, "", myStderr, .nil, "PROCESS")
call assert my~classifyError(myRs) = .Error~PERMISSIONDENIED, "mysql database permission"

myAuth = .DatabaseCommandResult~new(1, "", "ERROR 1045 (28000): Access denied for user 'bob'@'localhost' (using password: YES)", .nil, "PROCESS")
call assert my~classifyError(myAuth) = .Error~AUTHENTICATIONFAILED, "mysql authentication"

myConn = .DatabaseCommandResult~new(1, "", "ERROR 2002 (HY000): Can't connect to local server through socket '/run/mysql/mysql.sock' (2)", .nil, "PROCESS")
call assert my~classifyError(myConn) = .Error~CONNECTIONFAILED, "mysql connection"

say "DATABASE ERROR CLASSIFICATION SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
