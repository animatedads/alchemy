pgConn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
pgDb = .Database~new(pgConn)
pgTx = pgDb~transaction
pgStmt = pgTx~prepareStatement("upd_person", "UPDATE people SET name = ? WHERE id = ?")
pgTx~executePrepared(pgStmt, .array~of("Alice", .DatabaseParameter~new(7, "integer")))
pgCmd = pgDb~engine~compile(pgTx~prepare)
call assert (pgCmd~stdinText~pos("EXECUTE upd_person('Alice', 7);") > 0), "pg prepared mutation"

myConn = .DatabaseConnection~new("localhost", 3306, "test", "tester", .nil, "mysql")
myDb = .Database~new(myConn)
myTx = myDb~transaction
myStmt = myTx~prepareStatement("upd_person", "UPDATE people SET name = ? WHERE id = ?")
myTx~executePrepared(myStmt, .array~of("Alice", .DatabaseParameter~new(7, "integer")))
myCmd = myDb~engine~compile(myTx~prepare)
call assert (myCmd~stdinText~pos("EXECUTE upd_person USING") > 0), "mysql execute"
call assert (myCmd~stdinText~pos("__OOREXX_MUTATION_COUNT__") > 0), "mysql prepared count marker"
call assert (myCmd~stdinText~pos("ROW_COUNT()") > 0), "mysql prepared row count"

say "DATABASE PREPARED MUTATION SMOKE: OK"
exit 0
assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return
::requires "database_core.cls"
