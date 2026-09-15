/* Claude-review hardening regression. */

conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn)

tx = db~transaction
ps = tx~prepareStatement("bad_int", "INSERT INTO t(v) VALUES (?)")
tx~executePrepared(ps, .array~of(.DatabaseParameter~new("1; DROP TABLE x", "integer")))
vr = tx~prepare~validate
call assert vr~status = .Error~FAILED, "bad integer rejected"
call assert vr~error = .Error~INVALIDPARAMETER, "bad integer error"

tx2 = db~transaction
ps2 = tx2~prepareStatement("good_num", "INSERT INTO t(v) VALUES (?)")
tx2~executePrepared(ps2, .array~of(.DatabaseParameter~new(12.5, "decimal")))
call assert tx2~prepare~validate~status = .Error~SUCCESS, "good decimal accepted"

executor = .DatabaseProcessCommandExecutor~new
cmd = .DatabaseCommand~new("test", "/bin/true", .array~new, "")
cmd~environment~put("BAD-NAME", "x")
rs = executor~execute(cmd)
call assert rs~status = .Error~FAILED, "bad env status"
call assert rs~error = .Error~INVALIDENVIRONMENT, "bad env explicit error"

say "DATABASE HARDENING SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
