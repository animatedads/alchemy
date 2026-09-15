fake = .FakeRelationalDatabase~new
source = fake~relationalSource
sourceIdentity = source~identity

call assert sourceIdentity~sourceKind = .DatabaseSourceKind~DATABASE, "database source kind"
call assert sourceIdentity~engineName = "mysql", "engine name"
call assert sourceIdentity~name = "fakedb", "database name"
call assert sourceIdentity~protocol = "mysql", "protocol passthrough"
call assert sourceIdentity~product = "nosqlserver", "product passthrough"
call assert sourceIdentity~version = "5.7.44-NoSQLServer-ooRexx", "version passthrough"

table = source~table("customer")
tableIdentity = table~identity
call assert tableIdentity~sourceKind = .DatabaseSourceKind~TABLE, "table source kind"
call assert tableIdentity~product = "nosqlserver", "table endpoint product"
call assert tableIdentity~name = "customer", "table identity name"

say "DATABASE RELATIONAL IDENTITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class FakeRelationalDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 3306, "fakedb", "", .nil, "mysql")
  self~init:super(conn, .MySQLEngine~new)
::method endpointIdentity
  return .DatabaseEndpointIdentity~new("mysql", "nosqlserver", "5.7.44-NoSQLServer-ooRexx", -
    "5.7.44-NoSQLServer-ooRexx")

::requires "database_core.cls"
