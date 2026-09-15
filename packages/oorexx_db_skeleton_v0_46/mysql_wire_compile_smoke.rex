conn = .DatabaseConnection~new("127.0.0.1", 3333, "nosqlserver", "", .nil, "mysql")
resolver = .DatabaseExecutableResolver~new
ignore = resolver~setOverride("mysql", "/usr/bin/mariadb")
db = .Database~new(conn, .nil, .DatabaseNopCommandExecutor~new, resolver)
tx = db~transaction
ref = tx~query("SELECT 1 AS probe_value")
cmd = db~engine~compile(tx~prepare)

call assert (cmd~arguments~items = 7), "argument count"
call assert (cmd~arguments[1] = "--batch"), "batch"
call assert (cmd~arguments[2] = "--raw"), "raw"
call assert (cmd~arguments[3] = "--host"), "host flag"
call assert (cmd~arguments[4] = "127.0.0.1"), "host"
call assert (cmd~arguments[5] = "--port"), "port flag"
call assert (cmd~arguments[6] = 3333), "port"
call assert (cmd~arguments[7] = "nosqlserver"), "database"
call assert (cmd~stdinText~pos("SELECT 1 AS probe_value;") > 0), "query"

say "DATABASE MYSQL WIRE COMPILE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
