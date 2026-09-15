executor = .DatabaseProcessCommandExecutor~new

args = .array~of("-c", "sleep 3")
cmd = .DatabaseCommand~new("test", "/bin/sh", args, "")
cmd~timeout = 1

rs = executor~execute(cmd)
call assert rs~rc = 124, "timeout rc"
call assert rs~status = .Error~FAILED, "timeout status"
call assert rs~terminationReason = "TIMEOUT", "timeout reason"

pg = .PostgreSQLResultParser~new
call assert pg~classifyError(rs) = .Error~TIMEOUT, "postgres timeout"

my = .MySQLResultParser~new
call assert my~classifyError(rs) = .Error~TIMEOUT, "mysql timeout"

say "DATABASE PROCESS TIMEOUT SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
