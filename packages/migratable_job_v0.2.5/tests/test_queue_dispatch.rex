call mj_test_install_native_crypto
/* Queue Fabric seam qualification: migration resume is wrapped in the
 * Job-to-Node authority-bearing dispatch envelope before transport dispatch. */
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
pr=.JobPlacementRequest~new("JOB-Q",req,"OWNER",1000,1000)
def=.MigratableJobDefinition~new("JOB-Q",pr,"definition:q","PART-Q","OWNER","OOREXX","5.3-r13196","rev-q")
source=.JobNodePlacementLease~new("PLACE-S","JOB-Q","NODE-A","OWNER",1,1,1000,10000,"req","cap-a","obs-a","1","","","",1,0,"")
dest=.JobNodePlacementLease~new("PLACE-D","JOB-Q","NODE-B","OWNER",1,1,2000,10000,"req","cap-b","obs-b","1","","","",3,0,"")
m=.MigratableJobMigration~new("MIG-Q",def,source,1000)
cp=.MigratableJobCheckpointManifest~new("CKPT-Q","JOB-Q","MIG-Q","PART-Q","NODE-A","PLACE-S",1,"OOREXX","5.3-r13196","rev-q","state:q","digest:q","inputs:q","outputs:q",1100,900,1100,1)
m~setCheckpoint(cp,"checkpoint://source",1100)
m~markSourceFenced(1110); m~markSourceAdmissionReleased(1111)
m~setDestinationLease(dest,1200)
m~setTransferEvidence("sha256:q","storage://NODE-B/CKPT-Q",1300)
m~setCommitEvidence("commit:q",1400)

fake=.CaptureDispatcher~new
bridge=.MigratableJobQueueFabricDispatcher~new(fake)
r=bridge~dispatchResume(m,"principal:q",.nil)
if \r~ok then call fail "dispatch result"
if fake~count<>1 then call fail "dispatch count"
e=fake~envelope
if e~executionNodeId<>"NODE-B" | e~placementId<>"PLACE-D" then call fail "placement envelope binding"
cmd=e~payload
if cmd~operation<>"RESUME" | cmd~migrationId<>"MIG-Q" | cmd~jobId<>"JOB-Q" then call fail "resume command identity"
if cmd~checkpointId<>"CKPT-Q" | cmd~checkpointRef<>"storage://NODE-B/CKPT-Q" then call fail "checkpoint command binding"
if cmd~verificationRef<>"sha256:q" | cmd~commitEvidenceRef<>"commit:q" then call fail "resume evidence binding"

say "PASS Queue Fabric resume command is bound to destination placement and migration evidence"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class CaptureDispatcher
::attribute count get
::attribute envelope get
::method init
  expose count envelope
  count=0; envelope=.nil
::method dispatch
  expose count envelope
  use strict arg envelopeArg, principal="", options=.nil
  count+=1; envelope=envelopeArg
  return .QueueOperationResult~success(envelopeArg~placementId)

::requires "MigratableJobQueueFabricAdapter.cls"
::requires "TestForeignCryptoBootstrap.cls"
