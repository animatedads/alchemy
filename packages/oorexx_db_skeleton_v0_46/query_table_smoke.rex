conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn, .nil, .MetadataExecutor~new)

qr = db~queryTable("people")
call assert qr~isA(.DatabaseQueryResult), "query result"
call assert (qr~rowCount = 1), "row count"
call assert (qr~rows[1]~at("id")~typeName = .DatabaseType~INTEGER), "id typed"
call assert (qr~rows[1]~valueAt("id") = "7"), "id value"
call assert (qr~rows[1]~at("active")~typeName = .DatabaseType~BOOLEAN), "active typed"
call assert (qr~rows[1]~valueAt("active") == .true), "active value"

say "DATABASE QUERY TABLE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class MetadataExecutor public subclass DatabaseCommandExecutor
::method init
  expose callCount
  callCount = 0
::method execute
  expose callCount
  use arg command
  callCount += 1
  if callCount = 1 then do
    out = "__oorexx_frame" || .endOfLine || -
          "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
          "column_name" || "09"x || "data_type" || "09"x || "is_nullable" || "09"x || "ordinal_position" || .endOfLine || -
          "id" || "09"x || "integer" || "09"x || "NO" || "09"x || "1" || .endOfLine || -
          "active" || "09"x || "boolean" || "09"x || "NO" || "09"x || "2" || .endOfLine || -
          "__oorexx_frame" || .endOfLine || -
          "__OOREXX_RESULT_END_1__" || .endOfLine
  end
  else do
    out = "__oorexx_frame" || .endOfLine || -
          "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
          "id" || "09"x || "active" || .endOfLine || -
          "7" || "09"x || "true" || .endOfLine || -
          "__oorexx_frame" || .endOfLine || -
          "__OOREXX_RESULT_END_1__" || .endOfLine
  end
  return .DatabaseCommandResult~new(0, out, "", command, "PROCESS")

::requires "database_core.cls"
