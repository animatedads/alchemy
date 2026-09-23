call mj_test_install_native_crypto
parse source . . testFile
path=filespec("LOCATION",testFile)||"/tmp-starter-bridge.receipts"
call SysFileDelete path
uk=.array~of("GB")
rq=.JobNodeRequirement~new(uk)
pr=.JobPlacementRequest~new("JOB-BRIDGE",rq,"OWNER",1000,1000)
def=.MigratableJobDefinition~new("JOB-BRIDGE",pr,"definition:bridge","P","OWNER")
app=.BridgeApp~new(def)
exec=.BridgeExec~new
localRunner=.MigratableJobDestinationRunner~new(exec)
starter=.MigratableJobStarter~new(app,.MigratableJobStartReceiptStore~new(path),.nil,localRunner)
bridge=.MigratableJobStarterDestinationRunner~new(starter)
i=.MigratableJobHandoffInstruction~new("HB-1","FILE","MIG-B","JOB-BRIDGE","definition:bridge","P","CK","A","PA",1,"B","PB",2,"dest:checkpoint","state:digest","provider:verified","commit:1","","","",1000,"")
a1=bridge~start(i,1100)
if a1==.nil | \a1~ok | a1~executionRef<>"bridge-exec:HB-1" then call fail "bridge first start"
a2=bridge~start(i,1200)
if a2==.nil | \a2~ok | a2~executionRef<>a1~executionRef then call fail "bridge replay acknowledgement"
if exec~starts<>1 then call fail "bridge bypassed starter replay"
say "PASS queue/file destination runner bridge routes handoffs through the standard starter"
exit 0
fail: procedure
 parse arg m
 say "FAIL" m
 exit 1
::class BridgeApp subclass MigratableJobStarterApplication
::method init
 expose d
 use strict arg x
 d=x
::method definition
 expose d
 return d
::method startNew
 return .MigratableJobResumeResult~failure("NOT_USED")
::class BridgeExec subclass MigratableJobDestinationExecutor
::attribute starts
::method init
 expose starts
 starts=0
::method start
 expose starts
 use strict arg instruction, checkpoint, now
 starts+=1
 return .MigratableJobResumeResult~success("bridge-exec:"||instruction~handoffId)
::requires "MigratableJobStarter.cls"
::requires "TestForeignCryptoBootstrap.cls"
