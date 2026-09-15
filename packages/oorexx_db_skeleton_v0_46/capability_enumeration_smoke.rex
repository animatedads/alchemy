conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
db = .Database~new(conn, .PostgreSQLEngine~new)
effectiveCapabilities = db~capabilities
capabilityList = effectiveCapabilities~all

call assert capabilityList~items > 0, "effective capability enumeration"
call assert db~supports(.DatabaseCapability~TYPEDRESULTS), "typed results support"

foundTyped = .false
do capability over capabilityList
  if capability = .DatabaseCapability~TYPEDRESULTS then foundTyped = .true
end
call assert foundTyped, "typed results enumerated"

say "DATABASE CAPABILITY ENUMERATION SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
