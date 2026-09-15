db = .DescribeBoundaryDatabase~new
table = db~relationalSource~relation(.DatabaseRelationDescriptor~new("public", "customer", "BASE TABLE"))

description = table~describe

call assert description["name"] = "customer", "describe name"
call assert description["schema"] = "public", "describe schema"
call assert db~rowDemandCount = 0, "describe must not demand rows"
call assert db~metadataCount = 1, "describe reads metadata once"

say "DATABASE TABLE DESCRIBE OBSERVATIONAL SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class DescribeBoundaryDatabase public subclass Database
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
  return .DatabaseQueryResult~new

::requires "database_core.cls"
