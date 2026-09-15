identity = .DatabaseTransactionIdentity~new("manifest-42")
context = .DatabaseExecutionContext~new(.EvidenceStub~new("GEN-A"), "manifest:test")
conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
db = .Database~new(conn)

tx = db~transaction(context, identity)
call assert tx~isolation(.DatabaseIsolation~SERIALIZABLE) = .Error~SUCCESS, "isolation"
call assert tx~readOnly = .Error~SUCCESS, "read only"
call assert tx~setTimeout(12) = .Error~SUCCESS, "timeout"
call assert tx~setRetryAttempts(3) = .Error~SUCCESS, "retry"

op1 = tx~execute("UPDATE account SET balance = balance + 1 WHERE id = 7")
ref = tx~query("SELECT balance FROM account WHERE id = 7")
ps = tx~prepareStatement("p1", "UPDATE account SET note = ? WHERE id = ?")
exec = tx~executePrepared(ps, .array~of("SECRET-NOTE", 7))
sp = tx~savepoint("after_note")

manifest = tx~manifest

call assert manifest~isA(.DatabaseTransactionManifest), "manifest class"
call assert manifest~transactionIdentity == identity, "identity object retained"
call assert manifest~transactionId = "manifest-42", "transaction id"
call assert manifest~operationCount = 5, "operation count"
call assert manifest~isolationLevel = .DatabaseIsolation~SERIALIZABLE, "isolation retained"
call assert manifest~accessMode = .DatabaseAccessMode~READONLY, "access retained"
call assert manifest~timeout = 12, "timeout retained"
call assert manifest~retryMaxAttempts = 3, "retry retained"
call assert manifest~executionContext == context, "context retained"

d1 = manifest~operations[1]
call assert d1~operationId = op1~operationId, "statement operation id"
call assert d1~statementType = .DatabaseOperationType~EXECUTE, "statement type"
call assert d1~sqlText~pos("UPDATE account") = 1, "statement sql retained"

d2 = manifest~operations[2]
call assert d2~expectedResult, "query expected result"
call assert d2~operationId = ref~operationId, "query id"

d3 = manifest~operations[3]
call assert d3~preparedName = "p1", "prepared declaration name"
call assert d3~sqlText~pos("UPDATE account") = 1, "prepared sql retained"

d4 = manifest~operations[4]
call assert d4~preparedName = "p1", "prepared execution name"
call assert d4~parameterCount = 2, "parameter count"
call assert d4~sqlText = "", "prepared execution does not copy sql"
do descriptor over manifest~operations
  call assert descriptor~sqlText~pos("SECRET-NOTE") = 0, "parameter value absent from manifest"
end

d5 = manifest~operations[5]
call assert d5~savepointName = "after_note", "savepoint name"

say "DATABASE TRANSACTION MANIFEST SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class EvidenceStub public
::method init
  expose label
  use arg label
::attribute label get

::requires "database_core.cls"
