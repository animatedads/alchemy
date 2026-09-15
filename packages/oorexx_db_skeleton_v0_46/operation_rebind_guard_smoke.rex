op = .DatabaseStatement~new("SELECT 1")
s1 = op~bindTransaction("tx-A", 1)
call assert s1 = .Error~SUCCESS, "first bind succeeds"
s2 = op~bindTransaction("tx-A", 1)
call assert s2 = .Error~SUCCESS, "idempotent same bind succeeds"
s3 = op~bindTransaction("tx-B", 1)
call assert s3 = .Error~INVALIDSTATE, "cross transaction rebind refused"
s4 = op~bindTransaction("tx-A", 2)
call assert s4 = .Error~INVALIDSTATE, "sequence rebind refused"
call assert op~operationId = "tx-A:op:1", "identity unchanged"

say "DATABASE OPERATION REBIND GUARD SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
