db = .CountingReadDatabase~new
source = db~relationalSource
suite = .DatabaseSourceConformanceSuite~new

observed = suite~run(source, .DatabaseSourceConformanceMode~OBSERVATIONAL)
call assert observed~ok, "observational pass"
call assert db~rowDemandCount = 0, "no row demand during observation"

readReport = suite~runRead(source)
call assert readReport~ok, "read conformance pass"
call assert readReport~mode = .DatabaseSourceConformanceMode~READ, "read mode retained"
call assert db~rowDemandCount = 1, "read conformance crosses row boundary exactly once"

say "DATABASE SOURCE CONFORMANCE READ BOUNDARY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class CountingReadDatabase public subclass Database
::method init
  expose rowDemandCount
  rowDemandCount = 0
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .PostgreSQLEngine~new)
::attribute rowDemandCount get
::method endpointIdentity
  return .DatabaseEndpointIdentity~new("postgresql", "postgresql", "18.4", "PostgreSQL 18.4")
::method tables
  relations = .array~new
  relations~append(.DatabaseRelationDescriptor~new("public", "customer", "BASE TABLE"))
  return relations
::method relationMetadata
  use arg schemaName, tableName
  md = .DatabaseResultMetadata~new
  md~add(.DatabaseColumnMetadata~new("id", "integer", .DatabaseType~INTEGER, .false, 1))
  return md
::method queryRelation
  expose rowDemandCount
  use arg schemaName, tableName
  rowDemandCount += 1
  columns = .array~of("id")
  types = .array~of(.DatabaseType~INTEGER)
  rows = .array~new
  row = .DatabaseRow~new
  row~put("id", .DatabaseValue~fromText("1", .DatabaseType~INTEGER))
  rows~append(row)
  return .DatabaseQueryResult~new(.Error~SUCCESS, .Error~SUCCESS, columns, rows, types)

::requires "database_core.cls"
