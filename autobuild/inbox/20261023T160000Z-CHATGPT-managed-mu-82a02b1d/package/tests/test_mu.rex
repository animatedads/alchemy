numeric digits 20
root=value('MU_UPSTREAM_ROOT',,'ENVIRONMENT')
if root='' then do; say 'FAIL MU_UPSTREAM_ROOT required'; exit 90;end
p='/tmp/rexxos-mu-test-' || random(111111,999999) || '.ledger'
call SysFileDelete p
registry=.NodeCapabilityRegistry~new
now=1000000
cap=.NodeCapabilityStatement~new('HF-EXEC',1,'proof',.array~of('UK'),.array~of('GPU'),.array~of('TRUSTED'),.nil,.nil,.array~of('OOREXX'),.array~of('ZEROGPU'), 'X86_64',16384,100000,8,'r1')
call check registry~advertiseCapability(cap),'capability'
call check registry~observeCapacity(.NodeCapacityObservation~new('HF-EXEC',1,1,now,now+600000,14000,90000,4,1000,0,0,'obs')),'capacity'
allocator=.JobNodeAllocator~new(registry,.nil,.nil,.nil,.nil,'1')
req=.JobNodeRequirement~new(.array~of('UK'),.array~of('GPU'),.array~of('TRUSTED'),.nil,.nil,.array~of('OOREXX'),.array~of('ZEROGPU'),'X86_64',1024,1000,1,1024,1000,1,0,.nil,'r1')
placement=.JobPlacementRequest~new('JOB-1',req,'MU-CONTROL',0,0,0,.nil)
d=allocator~allocate(placement,now,30000)
call check d~placed,'real upstream allocation'
lease=d~lease
ledger=.MULocalRunLedger~new(p)
mu=.ManagedComputeMU~new('MU-CONTROL',.MUJobNodeDirectAuthority~new(allocator),ledger)
runner=.TestRunner~new
z=.MUComputeTarget~new('zero','ZEROGPU','HF-EXEC',1,'HF_SPACE','SERVERLESS',runner)
call good mu~bindTarget(z),'bind ZG'
win=.MUComputeTarget~new('badwindows','WINDOWS','HF-EXEC',1,'LINUX','PROCESS',runner)
call bad mu~bindTarget(win),'WINDOWS_HOST_REQUIRED','windows on linux'
win2=.MUComputeTarget~new('win','WINDOWS','WIN-NODE',1,'WINDOWS','HYPERV',runner)
call good mu~bindTarget(win2),'windows bind'
call bad mu~submit('R-WIN','win',lease,placement,'sha256:ff','payload',now),'PLACEMENT_TARGET_MISMATCH','windows lease mismatch'
call bad mu~submit('R-A','zero',lease,placement,'sha256:aa',.nil,now),'SPEC_REQUIRED','nil spec'
call good mu~submit('R-A','zero',lease,placement,'sha256:aa','payload',now),'run once'
call check runner~calls=1,'run count 1'
call bad mu~submit('R-A','zero',lease,placement,'sha256:aa','payload',now),'REPLAY_HELD','replay blocked'
call bad mu~submit('R-A','zero',lease,placement,'sha256:bb','changed',now),'REQUEST_ID_CONFLICT','changed digest'
call check runner~calls=1,'no replay'
mu2=.ManagedComputeMU~new('MU-CONTROL',.MUJobNodeDirectAuthority~new(allocator),.MULocalRunLedger~new(p))
call good mu2~bindTarget(z),'restart bind'
call bad mu2~submit('R-A','zero',lease,placement,'sha256:aa','payload',now),'REPLAY_HELD','restart replay'
call check runner~calls=1,'restart no rerun'
call bad mu2~submit('R-EXPIRED','zero',lease,placement,'sha256:ee','payload',now+999999),'PLACEMENT_NOT_AUTHORISED','expired'
z2=.MUComputeTarget~new('zero','ZEROGPU','HF-EXEC',2,'HF_SPACE','SERVERLESS',runner)
call good mu2~bindTarget(z2),'new target generation'
call bad mu2~submit('R-STALE','zero',lease,placement,'sha256:cc','payload',now),'TARGET_GENERATION_STALE','stale gen'
call SysFileDelete p
say 'PASS managed MU real allocator, replay, restart, Windows guard, expiry, generation'
exit 0
check: procedure
 use arg ok,label
 if \ok then do;say 'FAIL' label; exit 10;end
 return
good: procedure
 use arg result,label
 if \result~ok then do;say 'FAIL' label result~code result~detail; exit 11;end
 return
bad: procedure
 use arg result,code,label
 if result~ok | result~code<>code then do;say 'FAIL' label result~code 'expected' code; exit 12;end
 return
::class TestRunner public
::attribute calls get
::method init
 expose calls
 calls=0
::method invoke
 expose calls
 use arg spec
 calls+=1
 return .MUResult~new(.true,'COMPLETED','fake-receipt')
::requires 'ManagedComputeMU.cls'
::requires 'JobNodeAllocator.cls'
