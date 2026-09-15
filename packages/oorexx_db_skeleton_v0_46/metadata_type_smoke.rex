call assert (.DatabaseType~fromPostgreSQL("integer") = .DatabaseType~INTEGER), "pg integer"
call assert (.DatabaseType~fromPostgreSQL("numeric") = .DatabaseType~DECIMAL), "pg numeric"
call assert (.DatabaseType~fromPostgreSQL("boolean") = .DatabaseType~BOOLEAN), "pg bool"
call assert (.DatabaseType~fromPostgreSQL("bytea") = .DatabaseType~BLOB), "pg blob"

call assert (.DatabaseType~fromMySQL("int(11)") = .DatabaseType~INTEGER), "mysql int"
call assert (.DatabaseType~fromMySQL("tinyint(1)") = .DatabaseType~BOOLEAN), "mysql bool"
call assert (.DatabaseType~fromMySQL("decimal(10,2)") = .DatabaseType~DECIMAL), "mysql decimal"
call assert (.DatabaseType~fromMySQL("longblob") = .DatabaseType~BLOB), "mysql blob"

say "DATABASE METADATA TYPE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
