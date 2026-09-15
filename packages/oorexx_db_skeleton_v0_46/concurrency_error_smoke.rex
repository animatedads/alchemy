pg = .PostgreSQLResultParser~new
r = .DatabaseCommandResult~new(3, "", "ERROR: deadlock detected", .nil, "PROCESS")
call assert (pg~classifyError(r) = .Error~DEADLOCK), "pg deadlock"
r = .DatabaseCommandResult~new(3, "", "ERROR: could not serialize access due to concurrent update", .nil, "PROCESS")
call assert (pg~classifyError(r) = .Error~SERIALIZATIONFAILURE), "pg serialization"
r = .DatabaseCommandResult~new(3, "", "ERROR: canceling statement due to lock timeout", .nil, "PROCESS")
call assert (pg~classifyError(r) = .Error~LOCKTIMEOUT), "pg lock timeout"

my = .MySQLResultParser~new
r = .DatabaseCommandResult~new(1, "", "ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction", .nil, "PROCESS")
call assert (my~classifyError(r) = .Error~DEADLOCK), "mysql deadlock"
r = .DatabaseCommandResult~new(1, "", "ERROR 1205 (HY000): Lock wait timeout exceeded; try restarting transaction", .nil, "PROCESS")
call assert (my~classifyError(r) = .Error~LOCKTIMEOUT), "mysql lock timeout"

say "DATABASE CONCURRENCY ERROR SMOKE: OK"
exit 0
assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return
::requires "database_core.cls"
