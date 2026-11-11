root=value("NATIVE_DB_ROOT",,"ENVIRONMENT")
backend=.PostgreSQLNativeBackend~new(root || "/postgres/libpq.bridge.json")
if \backend~available then do
  ev=backend~availabilityEvidence
  availabilityError=ev["availability_error"]
  if availabilityError~pos("no library candidate could be loaded")>0 & -
     availabilityError~pos("cannot open shared object file: No such file or directory")>0 then do
    say "SKIP POSTGRESQL DATABASE CORE ADAPTER: libpq shared library is absent on this qualification host"
    exit 0
  end
  say "POSTGRESQL DATABASE CORE ADAPTER AVAILABILITY ERROR:" availabilityError
  call assert .false, "libpq load"
end
conn=.DatabaseConnection~new("127.0.0.1",1,"definitely_missing","nobody",.nil,"postgresql")
executor=backend~commandExecutor(conn)
call assert executor~isA(.DatabaseCommandExecutor), "native executor satisfies Database Core executor contract"
db=.Database~new(conn,.PostgreSQLEngine~new,executor)
call assert db~engine~name="postgresql", "Database Core engine remains PostgreSQL"
dbResult=db~query("SELECT 1 AS value")
call assert dbResult~status<>.Error~SUCCESS, "offline native route returns failure not fabricated data"
call assert dbResult~error=.Error~CONNECTIONFAILED | dbResult~error=.Error~DATABASEERROR, "Database Core maps native connection failure"
say "POSTGRESQL DATABASE CORE ADAPTER: PASS"
exit 0
assert: procedure
 use arg condition,label
 if \condition then do; say "FAIL" label; exit 1; end
 return
::requires "PostgreSQLNativeBackend.cls"
