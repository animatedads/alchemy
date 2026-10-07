root=value("NOSQLSERVER_ROOT",,"ENVIRONMENT")
fixture=root || "/tests/fixtures/v067_inverness_sample.gpkg"
backend=.GeoPackageOoRexxBackend~new
call assert backend~implementationKind=.NativeDatabaseImplementationKind~OOREXX_NATIVE, "implementation kind"
call assert backend~supports("READ_ONLY"), "read-only capability"
call assert \backend~supports("MUTATION"), "mutation explicitly unsupported"
call assert backend~capabilities~status("FOREIGN_ACCELERATION")="CONDITIONAL", "foreign acceleration is optional"
s=backend~acquire(fixture)
call assert s\==.nil, "portable session acquired"
names=s~tableNames
call assert names~items>0, "tables discovered"
r=s~query("SELECT * FROM sample_address LIMIT 2")
call assert r~status=.Error~SUCCESS, "portable direct query"
call assert r~rows~items=2, "portable row count"
call assert r~accessPath="GEOPACKAGE_NATIVE_SQLITE_SCAN", "direct ooRexx access path"
s~close
say "GEOPACKAGE OOREXX PORTABLE BACKEND: PASS tables=" names~items
exit 0
assert: procedure
 use arg condition,label
 if \condition then do; say "FAIL" label; exit 1; end
 return
::requires "GeoPackageOoRexxBackend.cls"
