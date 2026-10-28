root = value("MININOTES_DB_ROOT",, "ENVIRONMENT")
if root = "" then root = "data/test_nosql_backend"
app = .MiniNotesApp~new(root)
backend = app~persistence~database
call assert backend \== .nil, "NoSQLServer file backend exists"
call assert backend~version~supports("DISTINCT"), "NoSQLServer v0.87 DISTINCT capability is advertised"
call assert app~persistenceRoot = root, "requested durable root is authoritative"
say "PASS NoSQLServer v0.87 durable backend"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
return

::requires 'src/MiniNotesApp.cls'
