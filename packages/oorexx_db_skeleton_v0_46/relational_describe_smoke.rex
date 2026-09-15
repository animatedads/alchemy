fake = .FakeDescribeDatabase~new
table = fake~tableSource("customer")
description = table~describe
metadata = description["metadata"]
capabilityList = description["capabilities"]

call assert description["name"] = "customer", "describe name"
call assert description["engine"] = "postgresql", "describe engine"
call assert description["protocol"] = "postgresql", "describe protocol"
call assert description["product"] = "postgresql", "describe product"
call assert metadata~columns~items = 2, "describe metadata"
call assert capabilityList~items > 0, "describe capabilities"

say "DATABASE RELATIONAL DESCRIBE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class FakeDescribeDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .PostgreSQLEngine~new)
::method endpointIdentity
  return .DatabaseEndpointIdentity~new("postgresql", "postgresql", "18.4", "PostgreSQL 18.4")
::method tableMetadata
  use arg tableName
  md = .DatabaseResultMetadata~new
  md~add(.DatabaseColumnMetadata~new("id", "integer", .DatabaseType~INTEGER, .false, 1))
  md~add(.DatabaseColumnMetadata~new("name", "varchar", .DatabaseType~VARCHAR, .true, 2))
  return md

::requires "database_core.cls"
