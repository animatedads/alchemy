call mj_test_install_native_crypto
parse source . . testFile
path=filespec("LOCATION",testFile)||"/tmp-starter-recover.receipts"
call SysFileDelete path

uk=.array~of("GB")
rq=.JobNodeRequirement~new(uk)
pr=.JobPlacementRequest~new("JOB-REC",rq,"OWNER",1000,1000)
def=.MigratableJobDefinition~new("JOB-REC",pr,"definition:recover","PART-R","OWNER")
app=.RecoverApp~new(def)
m=.RecoverMigration~new("MIG-R")
coord=.RecoverCoordinator~new(m)
store=.MigratableJobStartReceiptStore~new(path)
starter=.MigratableJobStarter~new(app,store,coord)
req=.MigratableJobStartRequest~new("REC-START","RECOVER","JOB-REC","definition:recover","PART-R","MIG-R",2000)
r1=starter~start(req)
if \r1~ok | r1~state<>.MigratableJobStartState~RUNNING | r1~executionRef<>"exec:recovered" then call fail "recover result"
if coord~restores<>1 | coord~steps<>1 then call fail "recover calls"
r2=starter~start(req)
if \r2~replayed | coord~restores<>1 | coord~steps<>1 then call fail "recover replay duplicated"

say "PASS standard starter RECOVER restores, advances and durably suppresses duplicate recovery"
exit 0

fail: procedure
 parse arg m
 say "FAIL" m
 exit 1

::class RecoverApp subclass MigratableJobStarterApplication
::method init
 expose d
 use strict arg x
 d=x
::method definition
 expose d
 return d
::method startNew
 return .MigratableJobResumeResult~failure("NOT_USED")

::class RecoverSnapshot
::attribute valid get
::attribute code get
::attribute migration get
::method init
 expose valid code migration
 use strict arg m
 valid=.true; code="RESTORED"; migration=m

::class RecoverMigration
::attribute migrationId get
::attribute state
::attribute executionRef
::attribute failureCode
::attribute failureDetail
::method init
 expose migrationId state executionRef failureCode failureDetail
 use strict arg mid
 migrationId=mid; state=.MigratableJobMigrationState~PREPARING; executionRef=""; failureCode=""; failureDetail=""

::class RecoverCoordinator
::attribute restores
::attribute steps
::method init
 expose migration restores steps
 use strict arg m
 migration=m; restores=0; steps=0
::method restore
 expose migration restores
 restores+=1
 return .RecoverSnapshot~new(migration)
::method step
 expose migration steps
 use strict arg m, now, lease, chunks
 steps+=1; m~state=.MigratableJobMigrationState~RUNNING; m~executionRef="exec:recovered"; return .true
::method resumePaused
 forward message("STEP")

::requires "MigratableJobStarter.cls"
::requires "TestForeignCryptoBootstrap.cls"
