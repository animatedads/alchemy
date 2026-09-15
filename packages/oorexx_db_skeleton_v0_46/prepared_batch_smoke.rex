conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn)
tx = db~transaction
ps = tx~prepareStatement("ins", "INSERT INTO t(v) VALUES (?)")
batch = .DatabasePreparedBatch~new(ps)

p1 = .DatabaseParameterSet~new
p1~add("a")
batch~add(.DatabasePreparedExecution~new(ps, p1))

p2 = .DatabaseParameterSet~new
p2~add("b")
batch~add(.DatabasePreparedExecution~new(ps, p2))

tx~operations~append(batch)
cmd = db~engine~compile(tx~prepare)
sql = cmd~stdinText

call assert sql~countStr("EXECUTE ins(") = 2, "batch execution count"
call assert sql~pos("EXECUTE ins('a');") > 0, "batch first"
call assert sql~pos("EXECUTE ins('b');") > 0, "batch second"

say "DATABASE PREPARED BATCH SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
