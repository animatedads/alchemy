conn = .DatabaseConnection~new("localhost", 3306, "test", "tester", .nil, "mysql")
db = .Database~new(conn)
tx = db~transaction
stmt = tx~prepareStatement("upd", "UPDATE people SET active = ? WHERE id = ?")
batch = .DatabasePreparedBatch~new(stmt)
batch~add(.DatabasePreparedExecution~new(stmt, makeParams(1, 10)))
batch~add(.DatabasePreparedExecution~new(stmt, makeParams(0, 11)))
batch~add(.DatabasePreparedExecution~new(stmt, makeParams(1, 12)))
tx~operations~append(batch)
cmd = db~engine~compile(tx~prepare)
call assert (cmd~stdinText~countStr("EXECUTE upd USING") = 3), "three executes"
call assert (cmd~stdinText~countStr("__OOREXX_MUTATION_COUNT__") = 3), "three markers"
call assert (cmd~stdinText~countStr("ROW_COUNT()") = 3), "three row counts"
say "DATABASE PREPARED BATCH MUTATION SMOKE: OK"
exit 0

makeParams: procedure
  use arg active, id
  p = .DatabaseParameterSet~new
  p~add(.DatabaseParameter~new(active, "integer"))
  p~add(.DatabaseParameter~new(id, "integer"))
  return p

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return
::requires "database_core.cls"
