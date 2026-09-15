executor = .DatabaseProcessCommandExecutor~new

cmd = .DatabaseCommand~new("test", "/bin/cat", .array~new, "hello executor")
rs = executor~execute(cmd)
call assert rs~rc = 0, "cat rc"
call assert rs~status = .Error~SUCCESS, "cat status"
call assert rs~stdout = "hello executor", "stdin stdout roundtrip"
call assert rs~stderr = "", "cat stderr empty"

args = .array~new
args~append("-c")
args~append("echo out; echo err 1>&2; exit 7")
cmd2 = .DatabaseCommand~new("test", "/bin/sh", args, "")
rs2 = executor~execute(cmd2)
call assert rs2~rc = 7, "shell rc"
call assert rs2~status = .Error~FAILED, "shell failed status"
call assert rs2~error = .Error~COMMANDFAILED, "shell command failed constant"
call assert rs2~stdout~pos("out") > 0, "stdout captured"
call assert rs2~stderr~pos("err") > 0, "stderr captured"

cmd3 = .DatabaseCommand~new("test", "/bin/sh", .array~of('-c', 'printf %s "$DB_TEST_SECRET"'), "")
cmd3~environment~put("DB_TEST_SECRET", "s3cr3t value")
rs3 = executor~execute(cmd3)
call assert rs3~rc = 0, "environment rc"
call assert rs3~stdout = "s3cr3t value", "environment applied"

say "DATABASE PROCESS EXECUTOR SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
