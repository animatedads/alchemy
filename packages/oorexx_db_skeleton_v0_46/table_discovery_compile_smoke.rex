pg = .PostgreSQLEngine~new
my = .MySQLEngine~new

call assert pg~capabilities~supports(.DatabaseCapability~TABLEDISCOVERY), "postgres table discovery capability"
call assert my~capabilities~supports(.DatabaseCapability~TABLEDISCOVERY), "mysql table discovery capability"
call assert pg~tableDiscoveryQuery~pos("information_schema.tables") > 0, "postgres discovery query"
call assert pg~tableDiscoveryQuery~pos("pg_catalog") > 0, "postgres excludes system catalog"
call assert my~tableDiscoveryQuery~pos("information_schema.tables") > 0, "mysql discovery query"
call assert my~tableDiscoveryQuery~pos("DATABASE()") > 0, "mysql current database only"

say "DATABASE TABLE DISCOVERY COMPILE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
