conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn, .nil, .MutationExecutor~new)
tx = db~transaction
tx~execute("INSERT INTO t(id) VALUES (1)")
tx~execute("UPDATE t SET id = 2 WHERE id = 1")
rs = tx~commit
call assert (rs~status = .Error~SUCCESS), "commit"
call assert (rs~mutationResults~items = 2), "two results"
call assert (rs~mutationResults[1]~affectedRows = 1), "insert affected"
call assert (rs~mutationResults[2]~affectedRows = 1), "update affected"
say "DATABASE TRANSACTION MUTATION RESULT SMOKE: OK"
exit 0
assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return
::class MutationExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  return .DatabaseCommandResult~new(0, "INSERT 0 1" || .endOfLine || "UPDATE 1" || .endOfLine, "", command, "PROCESS")
::requires "database_core.cls"
