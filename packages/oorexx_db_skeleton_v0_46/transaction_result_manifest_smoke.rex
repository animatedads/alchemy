identity = .DatabaseTransactionIdentity~new("manifest-result")
db = .ManifestResultDatabase~new
tx = db~transaction(.nil, identity)
op = tx~execute("UPDATE t SET x = 1")
pre = tx~manifest
rs = tx~commit

call assert rs~status = .Error~SUCCESS, "commit success"
call assert rs~manifest~isA(.DatabaseTransactionManifest), "result manifest class"
call assert rs~manifest~transactionId = "manifest-result", "result manifest id"
call assert rs~manifest~operationIds[1] = op~operationId, "result manifest operation id"
call assert rs~manifest~operations[1]~sqlText = "UPDATE t SET x = 1", "result manifest sql"
call assert rs~manifest~operationCount = rs~operationCount, "result/manifest count"

say "DATABASE TRANSACTION RESULT MANIFEST SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class ManifestResultDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .PostgreSQLEngine~new, .ManifestExecutor~new)

::class ManifestExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  return .DatabaseCommandResult~new(0, "UPDATE 1" || .endOfLine, "", command, "PROCESS")

::requires "database_core.cls"
