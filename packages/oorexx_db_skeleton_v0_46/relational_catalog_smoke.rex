fake = .FakeCatalogDatabase~new
source = fake~relationalSource
tables = source~tables

call assert tables~items = 2, "source table count"
call assert tables[1]~qualifiedName = "public.customer", "first qualified relation"
call assert tables[2]~relationType = "VIEW", "second relation type"
call assert source~supports(.DatabaseCapability~TABLEDISCOVERY), "source discovery capability"

say "DATABASE RELATIONAL CATALOG SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class FakeCatalogDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .PostgreSQLEngine~new)
::method tables
  relations = .array~new
  relations~append(.DatabaseRelationDescriptor~new("public", "customer", "BASE TABLE"))
  relations~append(.DatabaseRelationDescriptor~new("public", "customer_view", "VIEW"))
  return relations
::method endpointIdentity
  return .DatabaseEndpointIdentity~new("postgresql", "postgresql", "18.4", "PostgreSQL 18.4")

::requires "database_core.cls"
