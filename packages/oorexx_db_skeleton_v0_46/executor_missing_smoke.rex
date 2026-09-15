executor = .DatabaseProcessCommandExecutor~new
cmd = .DatabaseCommand~new("test", "/definitely/not/here/oorexx-db-test", .array~new, "")
rs = executor~execute(cmd)
call assert rs~status = .Error~NOTEXECUTED, "missing executable status"
call assert rs~error = .Error~EXECUTABLENOTFOUND, "missing executable error"
say "DATABASE MISSING EXECUTABLE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
