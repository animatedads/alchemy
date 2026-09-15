metadata = .DatabaseResultMetadata~new
metadata~add(.DatabaseColumnMetadata~new("id", "integer", .DatabaseType~INTEGER, .false, 1))
metadata~add(.DatabaseColumnMetadata~new("name", "varchar", .DatabaseType~VARCHAR, .true, 2))

row = .DatabaseRow~new
row~put("id", .DatabaseValue~fromText("7", .DatabaseType~INTEGER))
row~put("name", .DatabaseValue~fromText("Ada", .DatabaseType~VARCHAR))

call assert metadata~columns~items = 2, "metadata column count"
call assert metadata~types[1] = .DatabaseType~INTEGER, "metadata integer type"
call assert row~rawAt("id") = "7", "row raw id"
call assert row~valueAt("id") = 7, "row typed id"
call assert row~valueAt("name") = "Ada", "row typed name"

say "DATABASE RELATIONAL ROW SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
