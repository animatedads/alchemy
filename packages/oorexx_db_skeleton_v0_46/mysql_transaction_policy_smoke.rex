conn = .DatabaseConnection~new("localhost", 3306, "test", "tester", .nil, "mysql")
db = .Database~new(conn)
tx = db~transaction

call assert (tx~isolation(.DatabaseIsolation~REPEATABLEREAD) = .Error~SUCCESS), "set isolation"
call assert (tx~readWrite = .Error~SUCCESS), "set rw"

cmd = db~engine~compile(tx~prepare)
call assert (cmd~stdinText~pos("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;") > 0), "mysql isolation"
call assert (cmd~stdinText~pos("START TRANSACTION READ WRITE;") > 0), "mysql access"

say "DATABASE MYSQL TRANSACTION POLICY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
