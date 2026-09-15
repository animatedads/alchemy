pg = .PostgreSQLResultParser~new

r = .DatabaseCommandResult~new(2, "", "psql: error: database ""missing_db"" does not exist", .nil, "PROCESS")
call assert pg~classifyError(r) = .Error~DATABASENOTFOUND, "postgres missing database"

r = .DatabaseCommandResult~new(3, "", "ERROR: syntax error at or near ""SELEC""", .nil, "PROCESS")
call assert pg~classifyError(r) = .Error~SYNTAXERROR, "postgres syntax"

r = .DatabaseCommandResult~new(3, "", "ERROR: duplicate key value violates unique constraint ""t_pkey""", .nil, "PROCESS")
call assert pg~classifyError(r) = .Error~DUPLICATEKEY, "postgres duplicate key"

r = .DatabaseCommandResult~new(3, "", "ERROR: insert or update on table ""child"" violates foreign key constraint ""fk_parent""", .nil, "PROCESS")
call assert pg~classifyError(r) = .Error~CONSTRAINTVIOLATION, "postgres foreign key"

r = .DatabaseCommandResult~new(124, "", "", .nil, "TIMEOUT")
call assert pg~classifyError(r) = .Error~TIMEOUT, "postgres timeout"

my = .MySQLResultParser~new

r = .DatabaseCommandResult~new(1, "", "ERROR 1049 (42000): Unknown database 'missing_db'", .nil, "PROCESS")
call assert my~classifyError(r) = .Error~DATABASENOTFOUND, "mysql missing database"

r = .DatabaseCommandResult~new(1, "", "ERROR 1064 (42000): You have an error in your SQL syntax; check the manual", .nil, "PROCESS")
call assert my~classifyError(r) = .Error~SYNTAXERROR, "mysql syntax"

r = .DatabaseCommandResult~new(1, "", "ERROR 1062 (23000): Duplicate entry '1' for key 'PRIMARY'", .nil, "PROCESS")
call assert my~classifyError(r) = .Error~DUPLICATEKEY, "mysql duplicate key"

r = .DatabaseCommandResult~new(1, "", "ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails", .nil, "PROCESS")
call assert my~classifyError(r) = .Error~CONSTRAINTVIOLATION, "mysql foreign key"

r = .DatabaseCommandResult~new(124, "", "", .nil, "TIMEOUT")
call assert my~classifyError(r) = .Error~TIMEOUT, "mysql timeout"

say "DATABASE EXTENDED ERROR CLASSIFICATION SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
