conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn)
tx = db~transaction
tx~execute("SELECT 1")
rs = tx~commit
call assert (rs~status = .Error~SUCCESS), "commit"
call assert (tx~readOnly = .Error~INVALIDSTATE), "readonly after commit"
call assert (tx~setTimeout(5) = .Error~INVALIDSTATE), "timeout after commit"
call assert (tx~isolation(.DatabaseIsolation~SERIALIZABLE) = .Error~INVALIDSTATE), "isolation after commit"

say "DATABASE TRANSACTION POLICY STATE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
