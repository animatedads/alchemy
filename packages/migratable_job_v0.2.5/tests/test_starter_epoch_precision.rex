numeric digits 30
path="/tmp/mj-starter-epoch-precision.receipts"
call SysFileDelete path
uk=.array~of("GB")
pReq=.JobPlacementRequest~new("JOB-EPOCH",.JobNodeRequirement~new(uk),"OWNER")
def=.MigratableJobDefinition~new("JOB-EPOCH",pReq,"definition:epoch","PART-E","OWNER")
app=.EpochApp~new(def)
store=.MigratableJobStartReceiptStore~new(path,.TestDigest~new)
starter=.MigratableJobStarter~new(app,store)
request=.MigratableJobStartRequest~new("START-EPOCH","NEW","JOB-EPOCH","definition:epoch","PART-E")
before=time('T')*1000
r=starter~start(request)
after=time('T')*1000
if r==.nil | \r~ok then call fail "starter failed"
lookup=store~load("START-EPOCH")
if \lookup~valid | lookup~receipt==.nil then call fail "receipt missing"
stamp=lookup~receipt~epochMs
if stamp<before | stamp>after then call fail "epoch millisecond stamp rounded outside exact current-second window" stamp before after
if stamp//1000<>0 then call fail "TIME(T) epoch stamp is not exact millisecond representation" stamp
say "PASS standard starter internal epoch-ms generation uses explicit high numeric precision"
exit 0
fail: procedure
 parse arg a,b,c,d
 say "FAIL" a b c d
 exit 1
::class EpochApp subclass MigratableJobStarterApplication
::method init
 expose d
 use strict arg x
 d=x
::method definition
 expose d
 use arg request=.nil
 return d
::method startNew
 use strict arg request, definition
 return .MigratableJobResumeResult~success("execution:epoch")
::class TestDigest
::method digest
 use strict arg text
 return "D:"||text
::requires "MigratableJobStarter.cls"
