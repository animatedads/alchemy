numeric digits 30
now=time('T')*1000
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
placement=.JobPlacementRequest~new("JOB-REMOTE-START",req,"OWNER-A",1000,1000)
def=.MigratableJobDefinition~new("JOB-REMOTE-START",placement,"definition:remote-start","PART-R","OWNER-A","OOREXX","5.3-r13196","rev-remote")
sourceApp=.RemoteStartApp~new(def,"source")
destApp=.RemoteStartApp~new(def,"destination")

reg=.NodeCapabilityRegistry~new
ca=.NodeCapabilityStatement~new("NODE-A",1,"cap-a",uk)
oa=.NodeCapacityObservation~new("NODE-A",1,1,now,now+600000,4096,50000,4,1000000,0,0,"obs-a")
cb=.NodeCapabilityStatement~new("NODE-B",1,"cap-b",uk)
ob=.NodeCapacityObservation~new("NODE-B",1,1,now,now+600000,16384,100000,16,30000000,0,0,"obs-b")
reg~advertiseCapability(ca); reg~observeCapacity(oa); reg~advertiseCapability(cb); reg~observeCapacity(ob)
own=.JobNodeOwnershipRegistry~new
elig=.JobNodeEligibilityPolicy~new
alloc=.JobNodeAllocator~new(reg,elig,.nil,.TestDigest~new,.nil,"REMOTE-START",.nil,own)

/* Two queue managers with ordinary remote queues. */
transport=.QueueInProcessTransport~new
ma=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
mb=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
call must ma~createQueue("XMIT.B","TEMPORARY","MIGRATABLE_JOB",100,"admin"),"create source xmit"
call must ma~createQueue("REPLY","TEMPORARY","MIGRATABLE_JOB",100,"admin"),"create source reply"
call must ma~grant("REPLY","wire-a",.QueueAccess~PUT,"admin"),"grant reply put"
call must ma~grant("REPLY","client-a",.QueueAccess~GET,"admin"),"grant reply get"
call must mb~createQueue("START.REQUEST","TEMPORARY","MIGRATABLE_JOB",100,"admin"),"create destination request"
call must mb~createQueue("XMIT.A","TEMPORARY","MIGRATABLE_JOB",100,"admin"),"create destination xmit"
call must mb~grant("START.REQUEST","wire-b",.QueueAccess~PUT,"admin"),"grant request wire"
call must mb~grant("START.REQUEST","mj-start-service",.QueueAccess~GET,"admin"),"grant request service"
fa=.QueueChannelFabric~new("QM.A",ma,transport,"admin")
fb=.QueueChannelFabric~new("QM.B",mb,transport,"admin")
ignore=transport~registerEndpoint("QM.A",fa); ignore=transport~registerEndpoint("QM.B",fb)
call must fa~defineSenderChannel("A.TO.B","XMIT.B","QM.B","A.TO.B","admin","wire-b",0,"TEMPORARY","admin"),"sender A-B"
call must fb~defineReceiverChannel("A.TO.B","QM.A","wire-b","TEMPORARY","admin"),"receiver A-B"
call must fb~defineSenderChannel("B.TO.A","XMIT.A","QM.A","B.TO.A","admin","wire-a",0,"TEMPORARY","admin"),"sender B-A"
call must fa~defineReceiverChannel("B.TO.A","QM.B","wire-a","TEMPORARY","admin"),"receiver B-A"
call must fa~startSenderChannel("A.TO.B","admin"),"start A-B"
call must fb~startReceiverChannel("A.TO.B","admin"),"recv A-B"
call must fb~startSenderChannel("B.TO.A","admin"),"start B-A"
call must fa~startReceiverChannel("B.TO.A","admin"),"recv B-A"
call must fa~defineRemoteQueue("B.MJ.START","START.REQUEST","QM.B","XMIT.B","A.TO.B","MIGRATABLE_JOB","TEMPORARY","admin","admin"),"remote start"
call must fa~grantRemotePut("B.MJ.START","client-a","admin"),"grant remote start"
call must fb~defineRemoteQueue("A.MJ.REPLY","REPLY","QM.A","XMIT.A","B.TO.A","MIGRATABLE_JOB","TEMPORARY","admin","admin"),"remote reply"
call must fb~grantRemotePut("A.MJ.REPLY","mj-start-service","admin"),"grant remote reply"

receiptPath="/tmp/mj-remote-start.receipts"; ledgerPath="/tmp/mj-remote-start.rpc"
call SysFileDelete receiptPath; call SysFileDelete ledgerPath
store=.MigratableJobStartReceiptStore~new(receiptPath,.TestDigest~new)
starter=.MigratableJobStarter~new(destApp,store)
verifier=.MigratableJobLocalPlacedStartLeaseVerifier~new(destApp,alloc)
access=.MigratableJobRemoteStartAccessPolicy~new; ignore=access~grant("client-a","OWNER-A")
ledger=.MigratableJobRemoteStartRequestLedger~new(ledgerPath,.QueueGraphPayloadCodec~new)
service=.MigratableJobRemoteStartService~new("NODE-B",starter,verifier,mb,"START.REQUEST",fb,"mj-start-service",access,ledger,.TestDigest~new,"NODE-B-START")
ignore=service~bindClientReply("client-a","A.MJ.REPLY")
progress=.RemoteStartProgress~new(fa,fb,service)
executor=.MigratableJobQueuePlacedStartExecutor~new(fa,ma,"REPLY","client-a","client-a",.TestDigest~new,3,0,progress)
ignore=executor~bindNodeQueue("NODE-B","B.MJ.START")
tool=.MigratableJobManagedPlacementTool~new(sourceApp,alloc,reg,elig,.nil,executor)
startReq=.MigratableJobStartRequest~new("START-REMOTE-1","NEW","JOB-REMOTE-START","definition:remote-start","PART-R","",now)

result=tool~allocateStart(startReq,now,30000,"OP-REMOTE")
if \result~ok | result~code<>"RUNNING" then call fail "remote allocate-start not running" result~code result~detail
if result~lease==.nil | result~lease~nodeId<>"NODE-B" then call fail "wrong destination lease"
if result~startResult==.nil | result~startResult~executionRef<>"destination:START-REMOTE-1" then call fail "wrong remote execution ref"
if destApp~starts<>1 then call fail "destination started wrong count"
if sourceApp~starts<>0 then call fail "source application was started"

/* Restart the remote-start service/ledger, then retry the exact same start.
 * The RPC ledger must replay the response without entering the starter again. */
ledger2=.MigratableJobRemoteStartRequestLedger~new(ledgerPath,.QueueGraphPayloadCodec~new)
service2=.MigratableJobRemoteStartService~new("NODE-B",starter,verifier,mb,"START.REQUEST",fb,"mj-start-service",access,ledger2,.TestDigest~new,"NODE-B-START-RESTART")
ignore=service2~bindClientReply("client-a","A.MJ.REPLY")
progress2=.RemoteStartProgress~new(fa,fb,service2)
executor2=.MigratableJobQueuePlacedStartExecutor~new(fa,ma,"REPLY","client-a","client-a",.TestDigest~new,3,0,progress2)
ignore=executor2~bindNodeQueue("NODE-B","B.MJ.START")
tool2=.MigratableJobManagedPlacementTool~new(sourceApp,alloc,reg,elig,.nil,executor2)
again=tool2~start(startReq,result~lease,now+1,"OP-REMOTE-REPLAY")
if \again~ok | again~code<>"RUNNING" then call fail "remote replay failed"
if destApp~starts<>1 then call fail "remote replay started twice"
if \again~startResult~replayed then call fail "remote replay flag missing"

/* Reusing the same RPC/start id with a different lease binding fails closed. */
badLease=.JobNodePlacementLease~new(result~lease~placementId,result~lease~jobId,"NODE-B",result~lease~ownerNodeId,result~lease~capabilityGeneration,result~lease~capacityObservationGeneration,result~lease~issuedEpochMs,result~lease~expiresEpochMs,result~lease~requirementDigest,result~lease~capabilityDigest,result~lease~capacityDigest,result~lease~allocationPolicyGeneration,result~lease~proofRef,result~lease~reservationRef,result~lease~signature,result~lease~ownershipEpoch+1,result~lease~renewalSequence,result~lease~supersedesPlacementId)
bad=executor2~start(badLease,startReq,now+2)
if bad==.nil | bad~ok then call fail "conflicting remote request accepted"
if bad~code<>"REQUEST_ID_CONFLICT" then call fail "wrong conflict code" bad~code
if destApp~starts<>1 then call fail "conflict reached runtime"

say "PASS remote placed-start Queue Fabric RPC, destination lease recheck, replay and conflict binding"
exit 0

must: procedure
  use arg r,label
  if r==.nil then do; say "FAIL nil" label; exit 11; end
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 12; end
  return
fail: procedure
  parse arg a,b,c
  say "FAIL" a b c
  exit 1

::class RemoteStartProgress
::method init
  expose fa fb service
  use strict arg faArg, fbArg, serviceArg
  fa=faArg; fb=fbArg; service=serviceArg
::method progress
  expose fa fb service
  r=fa~pump("A.TO.B",1,"admin")
  if r<>.nil then if r~ok then do
    s=service~processOne
    if s<>.nil then if s~ok then ignore=fb~pump("B.TO.A",1,"admin")
  end
  return .true

::class RemoteStartApp subclass MigratableJobStarterApplication
::attribute starts get
::method init
  expose d prefix starts
  use strict arg defArg, prefixArg
  d=defArg; prefix=prefixArg~string; starts=0
::method definition
  expose d
  use arg request=.nil
  return d
::method startNew
  expose prefix starts
  use strict arg request, definition
  starts+=1
  return .MigratableJobResumeResult~success(prefix||":"||request~startId)

::class TestDigest
::method digest
  use strict arg text
  return "D:"||text

::requires "MigratableJobRemoteStart.cls"
