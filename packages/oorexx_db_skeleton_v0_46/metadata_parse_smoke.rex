pg = .PostgreSQLEngine~new
pgResult = .DatabaseQueryResult~new
pgResult~columns~append("column_name")
pgResult~columns~append("data_type")
pgResult~columns~append("is_nullable")
pgResult~columns~append("ordinal_position")

r1 = .DatabaseRow~new
r1~put("column_name", "id")
r1~put("data_type", "integer")
r1~put("is_nullable", "NO")
r1~put("ordinal_position", "1")
pgResult~rows~append(r1)

r2 = .DatabaseRow~new
r2~put("column_name", "name")
r2~put("data_type", "character varying")
r2~put("is_nullable", "YES")
r2~put("ordinal_position", "2")
pgResult~rows~append(r2)

meta = pg~parseMetadataRows(pgResult)
call assert (meta~columns~items = 2), "pg metadata count"
call assert (meta~columns[1]~databaseType = .DatabaseType~INTEGER), "pg metadata integer"
call assert (\meta~columns[1]~nullable), "pg metadata not null"
call assert meta~columns[2]~nullable, "pg metadata nullable"

my = .MySQLEngine~new
myResult = .DatabaseQueryResult~new
myResult~columns~append("column_name")
myResult~columns~append("data_type")
myResult~columns~append("is_nullable")
myResult~columns~append("ordinal_position")

m1 = .DatabaseRow~new
m1~put("column_name", "active")
m1~put("data_type", "tinyint(1)")
m1~put("is_nullable", "NO")
m1~put("ordinal_position", "1")
myResult~rows~append(m1)

mmeta = my~parseMetadataRows(myResult)
call assert (mmeta~columns[1]~databaseType = .DatabaseType~BOOLEAN), "mysql metadata boolean"

say "DATABASE METADATA PARSE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
