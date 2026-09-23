call mj_test_install_native_crypto
transport=.QueueInProcessTransport~new
qa=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
qb=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")

ignore=qa~createQueue("XMIT.B","TEMPORARY","WIRE",20,"admin")
ignore=qa~createQueue("ACK.IN","TEMPORARY","WIRE",20,"admin")
ignore=qb~createQueue("MIG.IN","TEMPORARY","WIRE",20,"admin")
ignore=qb~createQueue("XMIT.A","TEMPORARY","WIRE",20,"admin")
ignore=qb~grant("MIG.IN","wire-b",.QueueAccess~PUT,"admin")
ignore=qb~grant("MIG.IN","worker-b",.QueueAccess~GET,"admin")
ignore=qa~grant("ACK.IN","wire-a",.QueueAccess~PUT,"admin")

fa=.QueueChannelFabric~new("QM.A",qa,transport,"admin")
fb=.QueueChannelFabric~new("QM.B",qb,transport,"admin")
ignore=transport~registerEndpoint("QM.A",fa)
ignore=transport~registerEndpoint("QM.B",fb)
ignore=fa~defineSenderChannel("A.TO.B","XMIT.B","QM.B","A.TO.B","admin","wire-b",0,"TEMPORARY","admin")
ignore=fb~defineReceiverChannel("A.TO.B","QM.A","wire-b","TEMPORARY","admin")
ignore=fb~defineSenderChannel("B.TO.A","XMIT.A","QM.A","B.TO.A","admin","wire-a",0,"TEMPORARY","admin")
ignore=fa~defineReceiverChannel("B.TO.A","QM.B","wire-a","TEMPORARY","admin")
ignore=fa~startSenderChannel("A.TO.B","admin"); ignore=fb~startReceiverChannel("A.TO.B","admin")
ignore=fb~startSenderChannel("B.TO.A","admin"); ignore=fa~startReceiverChannel("B.TO.A","admin")
ignore=fa~defineRemoteQueue("B.MIG","MIG.IN","QM.B","XMIT.B","A.TO.B","WIRE","TEMPORARY","admin","admin")
ignore=fb~defineRemoteQueue("A.ACK","ACK.IN","QM.A","XMIT.A","B.TO.A","WIRE","TEMPORARY","admin","admin")
ignore=fa~grantRemotePut("B.MIG","migrator","admin")
ignore=fb~grantRemotePut("A.ACK","acker","admin")

uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
pr=.JobPlacementRequest~new("JOB-Q2",req,"OWNER",1000,1000)
def=.MigratableJobDefinition~new("JOB-Q2",pr,"definition:q2","PART-Q2","OWNER","OOREXX","5.3-r13196","rev-q2")
source=.JobNodePlacementLease~new("PLACE-S","JOB-Q2","NODE-A","OWNER",1,1,1000,10000,"req","cap","obs","1","","","",1,0,"")
sourceRuntime=.SourceRuntime~new
handoff=.FakeHandoff~new
queueTransport=.MigratableJobQueueChannelTransport~new(fa,"A.ACK",.false,"migrator")
queueTransport~bindNodeQueue("NODE-B","B.MIG")
coord=.MigratableJobCoordinator~new(sourceRuntime,.Transfer~new,.Commit~new,handoff,.nil,.nil,.nil,queueTransport)
m=coord~begin("MIG-Q2",def,source,1100)
if coord~step(m,1200,5000,0) then call fail "queue handoff should await ack"
if m~state<>.MigratableJobMigrationState~AWAITING_DESTINATION then call fail "not awaiting queued destination"
if m~handoffMode<>.MigratableJobHandoffMode~QUEUE then call fail "wrong mode"

r=fa~pump("A.TO.B",0,"admin")
if \r~ok then call fail "source queue pump failed"
if qb~depth("MIG.IN","admin")~value["ready"]<>1 then call fail "remote migration not delivered"
runner=.MigratableJobDestinationRunner~new(.DestinationExecutor~new)
worker=.MigratableJobQueueWorker~new(fb,"MIG.IN",runner,"acker",.false)
ack=worker~runOne(1300,"worker-b")
if ack==.nil | \ack~ok then call fail "destination worker failed"
if qb~depth("MIG.IN","admin")~value["ready"]<>0 then call fail "migration command not acknowledged"

r2=fb~pump("B.TO.A",0,"admin")
if \r2~ok then call fail "ack queue pump failed"
reader=.MigratableJobQueueAcknowledgementReader~new(qa,"ACK.IN")
ack2=reader~get("admin")
if ack2==.nil | \ack2~ok then call fail "source ack missing"
if \coord~acknowledge(m,ack2,1400) then call fail "source rejected queue ack"
if m~state<>.MigratableJobMigrationState~RUNNING then call fail "not running after queue ack"
if sourceRuntime~retired<>1 then call fail "source retirement missing"

say "PASS QueueChannelFabric store-and-forward handoff A->B, destination start, acknowledgement B->A"
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
 use strict arg d,s,mid,now
 c=.MigratableJobCheckpointManifest~new("CKPT-Q2",d~jobId,mid,d~partitionId,s~nodeId,s~placementId,s~ownershipEpoch,d~runtimeId,d~runtimeGeneration,d~executableRevision,"state:q2","digest:q2","","",now,now-10,now,1)
 return .MigratableJobCheckpointResult~success(c,"checkpoint:q2")
::method resumeFromCheckpoint
 return .MigratableJobResumeResult~failure("DIRECT_FORBIDDEN")
::method retireSource
 expose retired
 retired+=1
 return .true
::class Transfer subclass MigratableJobTransferAdapter
::method transfer
 return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~COMPLETED,"provider:verified","storage://NODE-B/CKPT-Q2",1000,"")
::class Commit subclass MigratableJobCommitAuthority
::method authorise
 return .MigratableJobCommitDecision~allow("commit:q2")
::class FakeHandoff
::method fenceSource
 use strict arg m,now
 m~markSourceFenced(now); m~markSourceAdmissionReleased(now)
 return .JobNodePlacementDecision~new(.true,"FENCED",m~sourceLease)
::method allocateDestination
 use strict arg m,now,leaseMs=30000
 l=.JobNodePlacementLease~new("PLACE-D",m~definition~jobId,"NODE-B","OWNER",1,1,now,now+leaseMs,"req","cap","obs","1","","","",3,0,"")
 m~setDestinationLease(l,now)
 return .JobNodePlacementDecision~new(.true,"PLACED",l)
::method verifyDestination
 return .true
::method releaseDestination
 return .true
::class DestinationExecutor subclass MigratableJobDestinationExecutor
::method start
 use strict arg i,checkpointRef,now
 if i~destinationNodeId<>"NODE-B" then return .MigratableJobResumeResult~failure("WRONG_NODE")
 if i~commitEvidenceRef<>"commit:q2" then return .MigratableJobResumeResult~failure("COMMIT_EVIDENCE_MISSING")
 return .MigratableJobResumeResult~success("execution:queue:"||i~handoffId)

::requires "MigratableJobQueueFabricAdapter.cls"
::requires "TestForeignCryptoBootstrap.cls"
