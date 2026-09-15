root=value("NATIVE_DB_ROOT",,"ENVIRONMENT")
backend=.PostgreSQLNativeBackend~new(root || "/postgres/libpq.bridge.json")
call assert backend~available, "libpq load"
ev=backend~availabilityEvidence
call assert ev["libpq_version_number"]>0, "libpq version"
call assert ev["foreign_runtime_version"]<>"", "foreign runtime version"
call assert backend~supports("TRANSACTIONS"), "transactions published"
call assert \backend~supports("COPY_STREAMING"), "COPY unsupported is explicit"
conn=.DatabaseConnection~new("127.0.0.1",1,"definitely_missing","nobody",.nil,"postgresql")
s=.PostgreSQLNativeSession~new(backend,backend~library,conn)
call assert \s~connected, "connection failure remains failure"
call assert s~lastError<>"", "connection failure evidence"
s~close
say "POSTGRESQL NATIVE OFFLINE: PASS libpq=" ev["libpq_version_number"] "foreign=" ev["foreign_runtime_version"]
exit 0
assert: procedure
 use arg condition,label
 if \condition then do; say "FAIL" label; exit 1; end
 return
::requires "PostgreSQLNativeBackend.cls"
