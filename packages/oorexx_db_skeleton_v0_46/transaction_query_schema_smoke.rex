schemaA = .DatabaseResultSchema~new
schemaA~add("id", .DatabaseType~INTEGER)
schemaB = .DatabaseResultSchema~new
schemaB~add("flag", .DatabaseType~BOOLEAN)

conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn, .nil, .SchemaExecutor~new)
tx = db~transaction
a = tx~queryWithSchema("SELECT 9 AS id", schemaA)
b = tx~queryWithSchema("SELECT true AS flag", schemaB)
rs = tx~commit

call assert (rs~status = .Error~SUCCESS), "commit"
call assert a~resolved, "a resolved"
call assert b~resolved, "b resolved"
call assert (a~result~rows[1]~at("id")~typeName = .DatabaseType~INTEGER), "a type"
call assert (a~result~rows[1]~valueAt("id") = "9"), "a value"
call assert (b~result~rows[1]~valueAt("flag") == .true), "b bool"

say "DATABASE TRANSACTION QUERY SCHEMA SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class SchemaExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  out = "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
        "id" || .endOfLine || -
        "9" || .endOfLine || -
        "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_END_1__" || .endOfLine || -
        "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_BEGIN_2__" || .endOfLine || -
        "flag" || .endOfLine || -
        "true" || .endOfLine || -
        "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_END_2__" || .endOfLine
  return .DatabaseCommandResult~new(0, out, "", command, "PROCESS")

::requires "database_core.cls"
