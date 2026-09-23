call mj_test_install_native_crypto
parse source . . testFile
testRoot=filespec("LOCATION",testFile)||"/"
root=testRoot||"tmp-file-handoff"
address system "rm -rf "||root
call SysMkDir root
checkpoint=root||"/checkpoint.bin"
call charout checkpoint,"portable-checkpoint-v2"||"0a"x,1
call stream checkpoint,"c","close"
tmp=root||"/sha.txt"
address system "/usr/bin/sha256sum -- "||checkpoint||" > "||tmp
digest=word(linein(tmp),1); call stream tmp,"c","close"

uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
pr=.JobPlacementRequest~new("JOB-FILE",req,"OWNER",1000,1000)
def=.MigratableJobDefinition~new("JOB-FILE",pr,"definition:file","PART-F","OWNER","OOREXX","5.3-r13196","rev-file")
source=.JobNodePlacementLease~new("PLACE-S","JOB-FILE","NODE-A","OWNER",1,1,1000,10000,"req","cap","obs","1","","","",1,0,"")
runtime=.SourceRuntime~new
transfer=.FileTransfer~new(checkpoint,"sha256:"||digest)
commit=.Commit~new
handoff=.FakeHandoff~new
fileTransport=.MigratableJobFileHandoffTransport~new(root)
coord=.MigratableJobCoordinator~new(runtime,transfer,commit,handoff,.nil,.nil,.nil,fileTransport)
m=coord~begin("MIG-FILE",def,source,1100)
if coord~step(m,1200,5000,0) then call fail "file handoff should await destination acknowledgement"
if m~state<>.MigratableJobMigrationState~AWAITING_DESTINATION then call fail "not awaiting destination"
if m~handoffMode<>.MigratableJobHandoffMode~FILE then call fail "wrong handoff mode"
if stream(m~handoffRef,"c","query exists")="" then call fail "handoff file missing"

runner=.MigratableJobDestinationRunner~new(.DestinationExecutor~new)
starter=.MigratableJobFileManualStarter~new(fileTransport,runner)
ackPath=root||"/MIG-FILE.ack"
ack=starter~start(m~handoffRef,1300,checkpoint,ackPath)
if ack==.nil | \ack~ok then call fail "manual destination start failed"
if stream(ackPath,"c","query exists")="" then call fail "ack file missing"
ack2=fileTransport~readAcknowledgement(ackPath)
if ack2==.nil | \ack2~ok then call fail "ack file did not round-trip"
if \coord~acknowledge(m,ack2,1400) then call fail "source did not accept destination ack"
if m~state<>.MigratableJobMigrationState~RUNNING then call fail "final state not RUNNING"
if runtime~retired<>1 then call fail "source retirement missing"

say "PASS portable file handoff -> manual verified start -> acknowledgement -> RUNNING"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class SourceRuntime subclass MigratableJobExecutionAdapter
::attribute retired get
::method init
  expose retired
  retired=0
::method pauseAndCheckpoint
  use strict arg definition, sourceLease, migrationId, now
  c=.MigratableJobCheckpointManifest~new("CKPT-F",definition~jobId,migrationId,definition~partitionId,sourceLease~nodeId,sourceLease~placementId,sourceLease~ownershipEpoch,definition~runtimeId,definition~runtimeGeneration,definition~executableRevision,"file:source","state-digest","","",now,now-10,now,1)
  return .MigratableJobCheckpointResult~success(c,"file:source")
::method resumeFromCheckpoint
  return .MigratableJobResumeResult~failure("DIRECT_RESUME_FORBIDDEN")
::method retireSource
  expose retired
  retired+=1
  return .true

::class FileTransfer subclass MigratableJobTransferAdapter
::method init
  expose path verification
  use strict arg p,v
  path=p; verification=v
::method transfer
  expose path verification
  use strict arg m,maxChunks=0
  return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~COMPLETED,verification,path,stream(path,"c","query size"),"")

::class Commit subclass MigratableJobCommitAuthority
::method authorise
  return .MigratableJobCommitDecision~allow("commit:file")

::class FakeHandoff
::method fenceSource
  use strict arg m,now
  m~markSourceFenced(now); m~markSourceAdmissionReleased(now)
  return .JobNodePlacementDecision~new(.true,"FENCED",m~sourceLease)
::method allocateDestination
  use strict arg m,now,leaseMs=30000
  lease=.JobNodePlacementLease~new("PLACE-D",m~definition~jobId,"NODE-B","OWNER",1,1,now,now+leaseMs,"req","cap","obs","1","","","",3,0,"")
  m~setDestinationLease(lease,now)
  return .JobNodePlacementDecision~new(.true,"PLACED",lease)
::method verifyDestination
  return .true
::method releaseDestination
  return .true

::class DestinationExecutor subclass MigratableJobDestinationExecutor
::method start
  use strict arg instruction,checkpointRef,now
  if instruction~destinationNodeId<>"NODE-B" then return .MigratableJobResumeResult~failure("WRONG_NODE")
  if stream(checkpointRef,"c","query exists")="" then return .MigratableJobResumeResult~failure("CHECKPOINT_MISSING")
  return .MigratableJobResumeResult~success("execution:file:"||instruction~handoffId)

::requires "MigratableJobHandoff.cls"
::requires "TestForeignCryptoBootstrap.cls"
