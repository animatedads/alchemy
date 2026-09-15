conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn)
tx = db~transaction

call assert (tx~isolation(.DatabaseIsolation~SERIALIZABLE) = .Error~SUCCESS), "set isolation"
call assert (tx~readOnly = .Error~SUCCESS), "set read only"
call assert (tx~setTimeout(9) = .Error~SUCCESS), "set timeout"

cmd = db~engine~compile(tx~prepare)
call assert (cmd~stdinText~pos("BEGIN ISOLATION LEVEL SERIALIZABLE READ ONLY;") > 0), "postgres begin policy"
call assert (cmd~timeout = 9), "timeout propagated"

bad = db~transaction
call assert (bad~isolation("BOGUS") = .Error~INVALIDARGUMENT), "invalid isolation"
call assert (bad~setTimeout(-1) = .Error~INVALIDARGUMENT), "negative timeout"

say "DATABASE TRANSACTION POLICY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
