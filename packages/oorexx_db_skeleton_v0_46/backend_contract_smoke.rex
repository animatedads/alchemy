pg = .PostgreSQLEngine~new
my = .MySQLEngine~new

call assert pg~isA(.DatabaseBackendContract), "pg backend contract"
call assert my~isA(.DatabaseBackendContract), "mysql backend contract"
call assert pg~supports(.DatabaseCapability~TRANSACTIONS), "pg transactions"
call assert pg~supports(.DatabaseCapability~GENERATEDKEYS), "pg generated keys"
call assert my~supports(.DatabaseCapability~PREPAREDBATCH), "mysql prepared batch"
call assert my~supports(.DatabaseCapability~GENERATEDKEYS), "mysql generated keys"

conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn)
call assert db~supports(.DatabaseCapability~TRANSACTIONRETRY), "db retry"
call assert db~supports(.DatabaseCapability~RESULTSCHEMA), "db result schema"

say "DATABASE BACKEND CONTRACT SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
