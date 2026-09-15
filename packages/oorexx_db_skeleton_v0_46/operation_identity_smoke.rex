identity = .DatabaseTransactionIdentity~new("logical-op-test")
conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
db = .Database~new(conn)
tx = db~transaction(.nil, identity)

op1 = tx~execute("UPDATE t SET x = 1")
ref = tx~query("SELECT x FROM t")
ps = tx~prepareStatement("p1", "UPDATE t SET x = ?")
op4 = tx~executePrepared(ps, .array~of(2))
sp = tx~savepoint("after_update")

call assert op1~transactionId = "logical-op-test", "execute transaction id"
call assert op1~operationSequence = 1, "execute sequence"
call assert op1~operationId = "logical-op-test:op:1", "execute operation id"

call assert ref~transactionId = "logical-op-test", "query ref transaction id"
call assert ref~operationId = "logical-op-test:op:2", "query ref operation id"
call assert ref~operation~operationSequence = 2, "query operation sequence"

call assert ps~operationId = "logical-op-test:op:3", "prepared declaration id"
call assert op4~operationId = "logical-op-test:op:4", "prepared execution id"
call assert sp~operationId = "logical-op-test:op:5", "savepoint id"

say "DATABASE OPERATION IDENTITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
