columns = .array~of("table_schema", "table_name", "table_type")
rows = .array~new

r1 = .DatabaseRow~new
r1~put("table_schema", "public")
r1~put("table_name", "customer")
r1~put("table_type", "BASE TABLE")
rows~append(r1)

r2 = .DatabaseRow~new
r2~put("table_schema", "reporting")
r2~put("table_name", "customer_totals")
r2~put("table_type", "VIEW")
rows~append(r2)

queryResult = .DatabaseQueryResult~new(.Error~SUCCESS, .Error~SUCCESS, columns, rows)

pgTables = .PostgreSQLEngine~new~parseTableDiscoveryRows(queryResult)
myTables = .MySQLEngine~new~parseTableDiscoveryRows(queryResult)

call assert pgTables~items = 2, "postgres descriptor count"
call assert myTables~items = 2, "mysql descriptor count"
call assert pgTables[1]~schemaName = "public", "descriptor schema"
call assert pgTables[1]~name = "customer", "descriptor name"
call assert pgTables[1]~relationType = "BASE TABLE", "descriptor type"
call assert pgTables[2]~qualifiedName = "reporting.customer_totals", "qualified name"

say "DATABASE TABLE DISCOVERY PARSE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
