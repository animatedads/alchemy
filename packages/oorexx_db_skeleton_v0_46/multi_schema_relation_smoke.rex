db = .MultiSchemaDatabase~new
source = db~relationalSource
relations = source~tables

call assert relations~items = 2, "two discovered relations"
call assert relations[1]~name = relations[2]~name, "same bare relation name"
call assert relations[1]~schemaName \= relations[2]~schemaName, "different schemas"

publicTable = source~relation(relations[1])
archiveTable = source~relation(relations[2])

call assert publicTable~qualifiedName \= archiveTable~qualifiedName, "qualified names distinct"
call assert publicTable~identity~qualifiedName \= archiveTable~identity~qualifiedName, "identity remains distinct"

publicMeta = publicTable~metadata
archiveMeta = archiveTable~metadata
call assert publicMeta~columns[1]~name = "public_id", "public metadata routed by schema"
call assert archiveMeta~columns[1]~name = "archive_id", "archive metadata routed by schema"

publicRows = publicTable~rows
archiveRows = archiveTable~rows
call assert publicRows~rows[1]~valueAt("origin") = "public", "public rows routed by schema"
call assert archiveRows~rows[1]~valueAt("origin") = "archive", "archive rows routed by schema"

say "DATABASE MULTI SCHEMA RELATION SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class MultiSchemaDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .PostgreSQLEngine~new)
::method endpointIdentity
  return .DatabaseEndpointIdentity~new("postgresql", "postgresql", "18.4", "PostgreSQL 18.4")
::method tables
  relations = .array~new
  relations~append(.DatabaseRelationDescriptor~new("public", "customer", "BASE TABLE"))
  relations~append(.DatabaseRelationDescriptor~new("archive", "customer", "BASE TABLE"))
  return relations
::method relationMetadata
  use arg schemaName, tableName
  md = .DatabaseResultMetadata~new
  if schemaName = "public" then columnName = "public_id"
  else columnName = "archive_id"
  md~add(.DatabaseColumnMetadata~new(columnName, "integer", .DatabaseType~INTEGER, .false, 1))
  return md
::method queryRelation
  use arg schemaName, tableName
  columns = .array~of("origin")
  types = .array~of(.DatabaseType~VARCHAR)
  rows = .array~new
  row = .DatabaseRow~new
  row~put("origin", .DatabaseValue~fromText(schemaName, .DatabaseType~VARCHAR))
  rows~append(row)
  return .DatabaseQueryResult~new(.Error~SUCCESS, .Error~SUCCESS, columns, rows, types)

::requires "database_core.cls"
