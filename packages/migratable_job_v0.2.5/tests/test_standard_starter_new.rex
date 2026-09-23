call mj_test_install_native_crypto
parse source . . testFile
root=filespec("LOCATION",testFile)||"/tmp-starter-new"
call SysFileDelete root||".receipts"

uk=.array~of("GB")
reqs=.JobNodeRequirement~new(uk)
placement=.JobPlacementRequest~new("JOB-START",reqs,"OWNER",1000,1000)
def=.MigratableJobDefinition~new("JOB-START",placement,"definition:start","PART-A","OWNER","OOREXX","5.3-r13196","rev-start")
app=.StartApp~new(def)
store=.MigratableJobStartReceiptStore~new(root||".receipts")
starter=.MigratableJobStarter~new(app,store)
req=.MigratableJobStartRequest~new("START-1","NEW","JOB-START","definition:start","PART-A","",1000)

/* Simulate a process dying after durable CLAIMED but before runtime start. */
claim=store~claim(req,1000)
if \claim~valid | claim~receipt==.nil | claim~receipt~state<>.MigratableJobStartState~CLAIMED then call fail "claim"

r1=starter~start(req)
if r1==.nil | \r1~ok | r1~state<>.MigratableJobStartState~RUNNING then call fail "new start"
if r1~executionRef<>"execution:START-1" then call fail "execution ref"
if app~starts<>1 then call fail "new executor count"

/* Successful replay is answered from the durable receipt; no second start. */
r2=starter~start(req)
if \r2~ok | \r2~replayed then call fail "replay not recognised"
if r2~executionRef<>r1~executionRef | app~starts<>1 then call fail "replay duplicated execution"

/* Same start id with different binding is a hard conflict. */
placement2=.JobPlacementRequest~new("JOB-OTHER",reqs,"OWNER",1000,1000)
def2=.MigratableJobDefinition~new("JOB-OTHER",placement2,"definition:other","PART-A","OWNER")
app~setDefinition(def2)
conflict=.MigratableJobStartRequest~new("START-1","NEW","JOB-OTHER","definition:other","PART-A","",1100)
r3=starter~start(conflict)
if r3~ok | r3~code<>"START_ID_CONFLICT" then call fail "start id conflict"
if app~starts<>1 then call fail "conflict reached executor"

say "PASS standard starter NEW claim/retry, durable replay and conflicting start-id rejection"
exit 0

fail: procedure
 parse arg m
 say "FAIL" m
 exit 1

::class StartApp subclass MigratableJobStarterApplication
::attribute starts
::method init
  expose definitionObject starts
  use strict arg d
  definitionObject=d; starts=0
::method setDefinition
  expose definitionObject
  use strict arg d
  definitionObject=d
::method definition
  expose definitionObject
  return definitionObject
::method startNew
  expose starts
  use strict arg request, definition
  starts+=1
  return .MigratableJobResumeResult~success("execution:"||request~startId)

::requires "MigratableJobStarter.cls"
::requires "TestForeignCryptoBootstrap.cls"
