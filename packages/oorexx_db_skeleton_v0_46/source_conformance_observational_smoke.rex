db = .CountingSourceDatabase~new
source = db~relationalSource
suite = .DatabaseSourceConformanceSuite~new

report = suite~runObservational(source)

call assert report~ok, "observational conformance passes"
call assert report~mode = .DatabaseSourceConformanceMode~OBSERVATIONAL, "observational mode retained"
call assert db~rowDemandCount = 0, "observational conformance must not demand rows"
call assert db~metadataCount > 0, "observational conformance may inspect metadata"
call assert report~skipped > 0, "row check is explicitly skipped"

say "DATABASE SOURCE CONFORMANCE OBSERVATIONAL SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class CountingSourceDatabase public subclass Database
::method init
  expose rowDemandCount metadataCount
  rowDemandCount = 0
  metadataCount = 0
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .PostgreSQLEngine~new)
::attribute rowDemandCount get
::attribute metadataCount get
::method endpointIdentity
  return .DatabaseEndpointIdentity~new("postgresql", "postgresql", "18.4", "PostgreSQL 18.4")
::method tables
  relations = .array~new
  relations~append(.DatabaseRelationDescriptor~new("public", "customer", "BASE TABLE"))
  return relations
::method relationMetadata
  expose metadataCount
  use arg schemaName, tableName
  metadataCount += 1
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
