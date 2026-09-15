db = .ConformantFakeDatabase~new
source = db~relationalSource
suite = .DatabaseSourceConformanceSuite~new
report = suite~run(source)

call assert report~ok, "conformance should pass"
call assert report~failed = 0, "no failures"
call assert report~passed >= 6, "expected pass count"

say "DATABASE SOURCE CONFORMANCE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class ConformantFakeDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .PostgreSQLEngine~new)
::method endpointIdentity
  return .DatabaseEndpointIdentity~new("postgresql", "postgresql", "18.4", "PostgreSQL 18.4")
::method tables
  relations = .array~new
  relations~append(.DatabaseRelationDescriptor~new("public", "customer", "BASE TABLE"))
  return relations
::method tableMetadata
  use arg tableName
  md = .DatabaseResultMetadata~new
  md~add(.DatabaseColumnMetadata~new("id", "integer", .DatabaseType~INTEGER, .false, 1))
  md~add(.DatabaseColumnMetadata~new("name", "varchar", .DatabaseType~VARCHAR, .true, 2))
  return md
::method queryTable
  use arg tableName
  columns = .array~of("id", "name")
  types = .array~of(.DatabaseType~INTEGER, .DatabaseType~VARCHAR)
  rows = .array~new
  row = .DatabaseRow~new
  row~put("id", .DatabaseValue~fromText("1", .DatabaseType~INTEGER))
  row~put("name", .DatabaseValue~fromText("Ada", .DatabaseType~VARCHAR))
  rows~append(row)
  return .DatabaseQueryResult~new(.Error~SUCCESS, .Error~SUCCESS, columns, rows, types)

::requires "database_core.cls"
