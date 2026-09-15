b1=.NativeDatabaseBackend~new("POSTGRESQL","native", "1", .NativeDatabaseImplementationKind~FOREIGN_RUNTIME,10)
b1~addCapability("TRANSACTIONS","SUPPORTED","TESTED")
b2=.NativeDatabaseBackend~new("POSTGRESQL","fallback", "1", .NativeDatabaseImplementationKind~PROCESS_BRIDGE,100)
b2~addCapability("TRANSACTIONS","SUPPORTED","TESTED")
b2~addCapability("COPY_STREAMING","SUPPORTED","DECLARED")
a=.array~of(b2,b1)
s=.NativeDatabaseBackendSelector~new
picked=s~select(a,.array~of("TRANSACTIONS"),"POSTGRESQL")
call assert picked==b1, "priority selects native"
picked=s~select(a,.array~of("COPY_STREAMING"),"POSTGRESQL")
call assert picked==b2, "capability requirement selects fallback"
call assert b1~capabilities~status("MISSING")="UNKNOWN", "absence is UNKNOWN not unsupported"
say "NATIVE DATABASE CAPABILITY MODEL: PASS"
exit 0
assert: procedure
 use arg condition,label
 if \condition then do; say "FAIL" label; exit 1; end
 return
::requires "NativeDatabaseBackend.cls"
