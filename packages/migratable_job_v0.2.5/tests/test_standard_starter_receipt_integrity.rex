call mj_test_install_native_crypto
parse source . . testFile
path=filespec("LOCATION",testFile)||"/tmp-starter-integrity.receipts"
call SysFileDelete path
uk=.array~of("GB")
rq=.JobNodeRequirement~new(uk)
pr=.JobPlacementRequest~new("JOB-I",rq,"OWNER",1000,1000)
def=.MigratableJobDefinition~new("JOB-I",pr,"definition:i","P","OWNER")
app=.IntegrityApp~new(def)
store=.MigratableJobStartReceiptStore~new(path)
starter=.MigratableJobStarter~new(app,store)
rq1=.MigratableJobStartRequest~new("I-1","NEW","JOB-I","definition:i","P","",1000)
r1=starter~start(rq1)
if \r1~ok then call fail "initial start"
/* Tamper with the last digest character. */
s=.stream~new(path); if s~open("read")<>"READY:" then call fail "open read"
lines=.array~new; do while s~lines>0; lines~append(s~linein); end; s~close
last=lines[lines~items]; tail=last~right(1); replacement="0"; if tail="0" then replacement="1"; lines[lines~items]=last~left(last~length-1)||replacement
s=.stream~new(path); if s~open("write replace")<>"READY:" then call fail "open write"
do line over lines; s~lineout(line); end; s~close
rq2=.MigratableJobStartRequest~new("I-2","NEW","JOB-I","definition:i","P","",1100)
r2=starter~start(rq2)
if r2~ok | r2~code<>"START_RECEIPT_INTEGRITY_FAILED" then call fail "tampered receipt not rejected"
if app~starts<>1 then call fail "execution reached after receipt corruption"
say "PASS standard starter receipt integrity fails closed before execution"
exit 0
fail: procedure
 parse arg m
 say "FAIL" m
 exit 1
::class IntegrityApp subclass MigratableJobStarterApplication
::attribute starts
::method init
 expose d starts
 use strict arg x
 d=x; starts=0
::method definition
 expose d
 return d
::method startNew
 expose starts
 use strict arg request, definition
 starts+=1
 return .MigratableJobResumeResult~success("exec:"||request~startId)
::requires "MigratableJobStarter.cls"
::requires "TestForeignCryptoBootstrap.cls"
