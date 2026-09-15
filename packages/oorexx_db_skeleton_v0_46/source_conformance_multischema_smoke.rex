db = .ConformantMultiSchemaDatabase~new
report = .DatabaseSourceConformanceSuite~new~run(db~relationalSource)

do detail over report~details
  say detail
end

call assert report~ok, "multi-schema source conforms"
call assert report~failed = 0, "multi-schema no conformance failures"

say "DATABASE SOURCE CONFORMANCE MULTISCHEMA SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class ConformantMultiSchemaDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .PostgreSQLEngine~new)
::method endpointIdentity
  return .DatabaseEndpointIdentity~new("postgresql", "postgresql", "18.4", "PostgreSQL 18.4")
::method tables
  relations = .array~new
  relations~append(.DatabaseRelationDescriptor~new("public", "customer", "BASE TABLE"))
  relations~append(.DatabaseRelationDescriptor~new("archive", "customer", "VIEW"))
  return relations
::method relationMetadata
  use arg schemaName, tableName
  md = .DatabaseResultMetadata~new
  md~add(.DatabaseColumnMetadata~new("id", "integer", .DatabaseType~INTEGER, .false, 1))
  return md
::method queryRelation
  use arg schemaName, tableName
  columns = .array~of("id")
  types = .array~of(.DatabaseType~INTEGER)
  rows = .array~new
  row = .DatabaseRow~new
  row~put("id", .DatabaseValue~fromText("1", .DatabaseType~INTEGER))
  rows~append(row)
  return .DatabaseQueryResult~new(.Error~SUCCESS, .Error~SUCCESS, columns, rows, types)

::requires "database_core.cls"
