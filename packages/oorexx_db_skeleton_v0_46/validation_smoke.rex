conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn)

tx = db~transaction
ps = tx~prepareStatement("ins", "INSERT INTO t(a,b) VALUES (?, ?)")
tx~executePrepared(ps, .array~of(1, 2))
vr = tx~prepare~validate
call assert vr~status = .Error~SUCCESS, "valid plan"

tx2 = db~transaction
ps2 = tx2~prepareStatement("ins", "INSERT INTO t(a,b) VALUES (?, ?)")
tx2~executePrepared(ps2, .array~of(1))
vr2 = tx2~prepare~validate
call assert vr2~status = .Error~FAILED, "parameter mismatch failed"
call assert vr2~error = .Error~PARAMETERCOUNT, "parameter mismatch constant"

tx3 = db~transaction
tx3~prepareStatement("same", "SELECT ?")
tx3~prepareStatement("same", "SELECT ?")
vr3 = tx3~prepare~validate
call assert vr3~error = .Error~DUPLICATEPREPARED, "duplicate prepared name"

tx4 = db~transaction
fakeSp = .DatabaseSavepoint~new("missing", 1)
tx4~rollbackTo(fakeSp)
vr4 = tx4~prepare~validate
call assert vr4~error = .Error~INVALIDSAVEPOINT, "unknown savepoint"

tx5 = db~transaction
foreign = .DatabasePreparedStatement~new("foreign", "SELECT ?")
tx5~executePrepared(foreign, .array~of(1))
vr5 = tx5~prepare~validate
call assert vr5~error = .Error~PREPAREFAILED, "execute before prepare"

rs = tx2~commit
call assert rs~status = .Error~NOTEXECUTED, "invalid plan not executed"
call assert rs~error = .Error~PARAMETERCOUNT, "invalid plan error propagated"
call assert tx2~state = "not-executed", "invalid plan transaction state"

say "DATABASE VALIDATION SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
