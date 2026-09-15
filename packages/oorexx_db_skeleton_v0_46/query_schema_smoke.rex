schema = .DatabaseResultSchema~new
schema~add("customer_id", .DatabaseType~INTEGER)
schema~add("total", .DatabaseType~DECIMAL)
schema~add("active", .DatabaseType~BOOLEAN)

conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn, .nil, .SchemaExecutor~new)

qr = db~queryWithSchema("SELECT customer_id, total, active FROM synthetic", schema)
call assert (qr~rowCount = 1), "row count"
call assert (qr~rows[1]~at("customer_id")~typeName = .DatabaseType~INTEGER), "id type"
call assert (qr~rows[1]~valueAt("customer_id") = "7"), "id value"
call assert (qr~rows[1]~at("total")~typeName = .DatabaseType~DECIMAL), "total type"
call assert (qr~rows[1]~valueAt("active") == .true), "active bool"

say "DATABASE QUERY SCHEMA SMOKE: OK"
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
        "customer_id" || "09"x || "total" || "09"x || "active" || .endOfLine || -
        "7" || "09"x || "12.50" || "09"x || "true" || .endOfLine || -
        "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_END_1__" || .endOfLine
  return .DatabaseCommandResult~new(0, out, "", command, "PROCESS")

::requires "database_core.cls"
