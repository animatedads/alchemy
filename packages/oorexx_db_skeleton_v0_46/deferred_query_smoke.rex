conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn, .nil, .QueryExecutor~new)
tx = db~transaction
a = tx~query("SELECT 1 AS id, 'Alice' AS name")
b = tx~query("SELECT 42 AS value")
rs = tx~commit
call assert rs~status = .Error~SUCCESS, "commit"
call assert a~resolved, "first resolved"
call assert b~resolved, "second resolved"
call assert a~result~rows[1]~rawAt("name") = "Alice", "first"
call assert b~result~rows[1]~rawAt("value") = "42", "second"
say "DATABASE DEFERRED QUERY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class QueryExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  out = "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
        "id" || "09"x || "name" || .endOfLine || -
        "1" || "09"x || "Alice" || .endOfLine || -
        "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_END_1__" || .endOfLine || -
        "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_BEGIN_2__" || .endOfLine || -
        "value" || .endOfLine || -
        "42" || .endOfLine || -
        "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_END_2__" || .endOfLine
  return .DatabaseCommandResult~new(0, out, "", command, "PROCESS")

::requires "database_core.cls"
