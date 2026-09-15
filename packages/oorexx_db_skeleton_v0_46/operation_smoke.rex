call assert .DatabaseOperationType~QUERY = "QUERY", "query constant"
call assert .DatabaseOperationType~EXECUTE = "EXECUTE", "execute constant"
call assert .DatabaseOperationType~BACKUP = "BACKUP", "backup constant"
call assert .DatabaseOperationType~RESTORE = "RESTORE", "restore constant"

op = .DatabaseOperation~new(.DatabaseOperationType~BACKUP)
select
  when op~operationType = .DatabaseOperationType~QUERY then selected = "query"
  when op~operationType = .DatabaseOperationType~BACKUP then selected = "backup"
  otherwise selected = "other"
end
call assert selected = "backup", "select using operation constant"

stmt = .DatabaseStatement~new("SELECT 1", .DatabaseOperationType~QUERY)
call assert stmt~operationType = .DatabaseOperationType~STATEMENT, "statement family constant"
call assert stmt~statementType = .DatabaseOperationType~QUERY, "statement operation constant"

say "DATABASE OPERATION CONSTANT SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
