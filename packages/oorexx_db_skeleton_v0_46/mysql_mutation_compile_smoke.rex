conn = .DatabaseConnection~new("localhost", 3306, "test", "tester", .nil, "mysql")
db = .Database~new(conn)
tx = db~transaction
tx~execute("UPDATE people SET active = 1")
cmd = db~engine~compile(tx~prepare)
call assert (cmd~stdinText~pos("UPDATE people SET active = 1;") > 0), "update"
call assert (cmd~stdinText~pos("__OOREXX_MUTATION_COUNT__") > 0), "marker"
call assert (cmd~stdinText~pos("ROW_COUNT()") > 0), "row count"
say "DATABASE MYSQL MUTATION COMPILE SMOKE: OK"
exit 0
assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return
::requires "database_core.cls"
