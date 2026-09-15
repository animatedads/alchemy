parser = .PostgreSQLResultParser~new
lines = .array~of( -
  "id" || "09"x || "amount" || "09"x || "active", -
  "7" || "09"x || "12.50" || "09"x || "true")
types = .array~of(.DatabaseType~INTEGER, .DatabaseType~DECIMAL, .DatabaseType~BOOLEAN)
qr = parser~parseTabularLines(lines, types)

call assert (qr~rowCount = 1), "row count"
call assert (qr~rows[1]~valueAt("id") = "7"), "typed id"
call assert (qr~rows[1]~at("id")~typeName = .DatabaseType~INTEGER), "id type"
call assert (qr~rows[1]~valueAt("amount") = "12.50"), "typed amount"
call assert (qr~rows[1]~at("amount")~typeName = .DatabaseType~DECIMAL), "amount type"
call assert (qr~rows[1]~valueAt("active") == .true), "typed boolean"
call assert (qr~rows[1]~rawAt("amount") = "12.50"), "raw amount preserved"

say "DATABASE TYPED QUERY PARSE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
