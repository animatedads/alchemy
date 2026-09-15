conn = .DatabaseConnection~new("db.local", 5432, "accounts", "app", .nil, "postgresql")
db = .Database~new(conn)

source = db~relationalSource
call assert source~database == db, "source retains database"
call assert source~identity~sourceKind = .DatabaseSourceKind~DATABASE, "database source kind"
call assert source~identity~engineName = "postgresql", "source engine identity"
call assert source~identity~name = "accounts", "database source name"
call assert source~supports(.DatabaseCapability~TYPEDRESULTS), "source capability passthrough"

table = source~table("customer")
call assert table~database == db, "table retains database"
call assert table~tableName = "customer", "table name"
call assert table~identity~sourceKind = .DatabaseSourceKind~TABLE, "table source kind"
call assert table~identity~name = "customer", "table identity name"
call assert table~supports(.DatabaseCapability~RESULTMETADATA), "table capability passthrough"

say "DATABASE RELATIONAL SOURCE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
