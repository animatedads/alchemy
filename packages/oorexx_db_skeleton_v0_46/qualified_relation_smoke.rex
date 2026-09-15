pg = .PostgreSQLEngine~new
my = .MySQLEngine~new

call assert pg~qualifiedRelationName("reporting", "customer totals") = '"reporting"."customer totals"', "postgres qualified quoting"
call assert my~qualifiedRelationName("sales", "order") = '`sales`.`order`', "mysql qualified quoting"

pgSql = pg~metadataQueryForRelation("reporting", "customer")
call assert pgSql~pos("table_schema = 'reporting'") > 0, "postgres explicit schema metadata"
mySql = my~metadataQueryForRelation("warehouse", "customer")
call assert mySql~pos("table_schema = 'warehouse'") > 0, "mysql explicit schema metadata"

say "DATABASE QUALIFIED RELATION SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
