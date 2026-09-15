db = .FakeQualifiedDatabase~new
source = db~relationalSource
descriptor = .DatabaseRelationDescriptor~new("reporting", "customer", "VIEW")
table = source~relation(descriptor)

call assert table~schemaName = "reporting", "schema retained"
call assert table~tableName = "customer", "table retained"
call assert table~qualifiedName = '"reporting"."customer"', "qualified name"
description = table~describe
call assert description["schema"] = "reporting", "describe schema"
call assert description["qualifiedName"] = '"reporting"."customer"', "describe qualified name"

say "DATABASE RELATION DESCRIPTOR BINDING SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class FakeQualifiedDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .PostgreSQLEngine~new)
::method endpointIdentity
  return .DatabaseEndpointIdentity~new("postgresql", "postgresql", "18.4", "PostgreSQL 18.4")
::method relationMetadata
  use arg schemaName, tableName
  md = .DatabaseResultMetadata~new
  md~add(.DatabaseColumnMetadata~new("id", "integer", .DatabaseType~INTEGER, .false, 1))
  return md

::requires "database_core.cls"
