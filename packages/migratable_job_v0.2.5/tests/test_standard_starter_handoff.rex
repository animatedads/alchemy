call mj_test_install_native_crypto
parse source . . testFile
path=filespec("LOCATION",testFile)||"/tmp-starter-handoff.receipts"
call SysFileDelete path

uk=.array~of("GB")
rq=.JobNodeRequirement~new(uk)
pr=.JobPlacementRequest~new("JOB-HAND",rq,"OWNER",1000,1000)
def=.MigratableJobDefinition~new("JOB-HAND",pr,"definition:hand","PART-H","OWNER","OOREXX","5.3","rev-h")
app=.HandoffApp~new(def)
exec=.DestinationExec~new
runner=.MigratableJobDestinationRunner~new(exec)
store=.MigratableJobStartReceiptStore~new(path)
starter=.MigratableJobStarter~new(app,store,.nil,runner)
inst=.MigratableJobHandoffInstruction~new("H-1","QUEUE","MIG-H","JOB-HAND","definition:hand","PART-H","CK-H","NODE-A","P-A",1,"NODE-B","P-B",2,"storage:dest:ck","digest-state","storage:verified","commit:evidence","OOREXX","5.3","rev-h",1000,"ACK-Q")
/* blank startId intentionally adopts the handoff id */
req=.MigratableJobStartRequest~new("","HANDOFF","","","","",1200,inst)
r1=starter~start(req)
if \r1~ok | r1~executionRef<>"exec:H-1" then call fail "handoff start"
if exec~starts<>1 then call fail "handoff executor count"
r2=starter~start(req)
if \r2~ok | \r2~replayed | exec~starts<>1 then call fail "handoff replay"

/* Same start/handoff id but changed destination evidence is a receipt conflict. */
inst2=.MigratableJobHandoffInstruction~new("H-1","QUEUE","MIG-H","JOB-HAND","definition:hand","PART-H","CK-H","NODE-A","P-A",1,"NODE-C","P-C",3,"storage:dest:ck2","digest-state","storage:verified2","commit:evidence","OOREXX","5.3","rev-h",1300,"ACK-Q")
req2=.MigratableJobStartRequest~new("","HANDOFF","","","","",1300,inst2)
r3=starter~start(req2)
if r3~ok | r3~code<>"START_ID_CONFLICT" then call fail "handoff conflict"
if exec~starts<>1 then call fail "conflicting handoff reached executor"

say "PASS standard starter HANDOFF binding, handoff-id default and duplicate suppression"
exit 0

fail: procedure
 parse arg m
 say "FAIL" m
 exit 1

::class HandoffApp subclass MigratableJobStarterApplication
::method init
  expose d
  use strict arg definitionArg
  d=definitionArg
::method definition
  expose d
  return d
::method startNew
  return .MigratableJobResumeResult~failure("NOT_USED")

::class DestinationExec subclass MigratableJobDestinationExecutor
::attribute starts
::method init
  expose starts
  starts=0
::method start
  expose starts
  use strict arg instruction, checkpointRef, nowEpochMs
  starts+=1
  return .MigratableJobResumeResult~success("exec:"||instruction~handoffId)

::requires "MigratableJobStarter.cls"
::requires "TestForeignCryptoBootstrap.cls"
