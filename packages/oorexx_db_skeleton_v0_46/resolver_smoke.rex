resolver = .DatabaseExecutableResolver~new
call assert resolver~resolve("postgresql") = "psql", "postgres default"
call assert resolver~resolve("mysql") = "mysql", "mysql default"
call assert resolver~resolve("unknown") = "", "unknown unresolved"
resolver~setOverride("postgresql", "/x/psql")
call assert resolver~resolve("postgresql") = "/x/psql", "override"
say "DATABASE RESOLVER SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
