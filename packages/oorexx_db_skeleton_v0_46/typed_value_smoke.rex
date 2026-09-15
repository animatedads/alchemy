v1 = .DatabaseValue~fromText("42", .DatabaseType~INTEGER)
call assert (v1~typeName = .DatabaseType~INTEGER), "integer type"
call assert (v1~value = "42"), "integer value"
call assert (v1~raw = "42"), "integer raw"

v2 = .DatabaseValue~fromText("12.50", .DatabaseType~DECIMAL)
call assert (v2~typeName = .DatabaseType~DECIMAL), "decimal type"
call assert (v2~value = "12.50"), "decimal value"

v3 = .DatabaseValue~fromText("true", .DatabaseType~BOOLEAN)
call assert (v3~value == .true), "boolean true"

v4 = .DatabaseValue~fromText(.nil, .DatabaseType~NULL)
call assert v4~isNull, "null value"
call assert (v4~value == .nil), "null object"

bad = .DatabaseValue~fromText("not-an-int", .DatabaseType~INTEGER)
call assert (bad~typeName = .DatabaseType~UNKNOWN), "bad integer degrades safely"
call assert (bad~raw = "not-an-int"), "bad integer raw preserved"

say "DATABASE TYPED VALUE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
