db = .DescriptorDatabase~new
source = db~relationalSource
descriptor = .DatabaseRelationDescriptor~new("archive", "customer", "VIEW")
table = source~relation(descriptor)
identity = table~identity
description = table~describe

call assert table~tableName = "customer", "table name retained"
call assert table~schemaName = "archive", "schema retained"
call assert table~relationType = "VIEW", "relation type retained"
call assert identity~name = "customer", "compat identity name retained"
call assert identity~schemaName = "archive", "identity schema retained"
call assert identity~qualifiedName = '"archive"."customer"', "identity qualified name"
call assert description["relationType"] = "VIEW", "describe relation type"
call assert description["schema"] = "archive", "describe schema"

say "DATABASE RELATION IDENTITY PRESERVATION SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class DescriptorDatabase public subclass Database
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
