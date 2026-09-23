numeric digits 30
now=time('T')*1000
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
pReq=.JobPlacementRequest~new("JOB-NET-CHECK",req,"OWNER-A")
def=.MigratableJobDefinition~new("JOB-NET-CHECK",pReq,"definition:net-check","PART-N","OWNER-A")
app=.VerifierApp~new(def)
reg=.NodeCapabilityRegistry~new
cap=.NodeCapabilityStatement~new("NODE-B",1,"cap-b",uk)
obs=.NodeCapacityObservation~new("NODE-B",1,1,now,now+600000,8192,50000,8,5000000,0,0,"obs-b")
reg~advertiseCapability(cap); reg~observeCapacity(obs)
elig=.JobNodeEligibilityPolicy~new
placement=.JobNodePlacementPolicy~new
own=.JobNodeOwnershipRegistry~new
alloc=.JobNodeAllocator~new(reg,elig,placement,.TestDigest~new,.nil,"NET-VERIFY",.nil,own)
d=alloc~allocate(pReq,now,30000)
if d==.nil | \d~placed then call fail "local setup allocation"
lease=d~lease

transport=.QueueInProcessTransport~new
ma=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
mb=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
call must ma~createQueue("XMIT.B","TEMPORARY","JNA",100,"admin"),"create A xmit"
call must ma~createQueue("REPLY","TEMPORARY","JNA",100,"admin"),"create A reply"
call must ma~grant("REPLY","wire-a",.QueueAccess~PUT,"admin"),"grant reply put"
call must ma~grant("REPLY","client-start",.QueueAccess~GET,"admin"),"grant reply get"
call must mb~createQueue("REQUEST","TEMPORARY","JNA",100,"admin"),"create request"
call must mb~createQueue("XMIT.A","TEMPORARY","JNA",100,"admin"),"create B xmit"
call must mb~grant("REQUEST","wire-b",.QueueAccess~PUT,"admin"),"grant request put"
call must mb~grant("REQUEST","jna-service",.QueueAccess~GET,"admin"),"grant service get"
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
call must fa~defineRemoteQueue("B.JNA.REQUEST","REQUEST","QM.B","XMIT.B","A.TO.B","JNA","TEMPORARY","admin","admin"),"remote request"
call must fa~grantRemotePut("B.JNA.REQUEST","client-start","admin"),"grant remote request"
call must fb~defineRemoteQueue("A.JNA.REPLY","REPLY","QM.A","XMIT.A","B.TO.A","JNA","TEMPORARY","admin","admin"),"remote reply"
call must fb~grantRemotePut("A.JNA.REPLY","jna-service","admin"),"grant remote reply"

access=.JobNodeNetworkAccessPolicy~new
ignore=access~grant("client-start",.array~of("CHECK"),"OWNER-A")
service=.JobNodeNetworkAllocatorService~new(alloc,reg,elig,placement,mb,"REQUEST",fb,"jna-service",access,.JobNodeNetworkRequestLedger~new("",.QueueGraphPayloadCodec~new),.TestDigest~new,"ALLOCATOR-NET")
ignore=service~bindClientReply("client-start","A.JNA.REPLY")
client=.JobNodeNetworkAllocatorClient~new(fa,"B.JNA.REQUEST",ma,"REPLY","client-start","client-start",.TestDigest~new)
progress=.NetworkCheckProgress~new(fa,fb,service)
verifier=.MigratableJobJobNodeNetworkLeaseVerifier~new(app,client,3,0,progress)
startReq=.MigratableJobStartRequest~new("START-NET-CHECK","NEW","JOB-NET-CHECK","definition:net-check","PART-N","",now)
if \verifier~verify(lease,startReq,now+1) then call fail "network lease verifier rejected current lease"
if \alloc~releasePlacement(lease) then call fail "setup release"
if verifier~verify(lease,startReq,now+2) then call fail "network lease verifier accepted released lease"
say "PASS destination lease verifier uses job.node.allocator.network/0.1 CHECK authority"
exit 0

must: procedure
 use arg r,label
 if r==.nil then do; say "FAIL nil" label; exit 11; end
 if \r~ok then do; say "FAIL" label r~code r~detail; exit 12; end
 return
fail: procedure
 parse arg a
 say "FAIL" a
 exit 1
::class NetworkCheckProgress
::method init
 expose fa fb service
 use strict arg a,b,s
 fa=a; fb=b; service=s
::method progress
 expose fa fb service
 r=fa~pump("A.TO.B",1,"admin")
 if r<>.nil then if r~ok then do
   s=service~processOne
   if s<>.nil then if s~ok then ignore=fb~pump("B.TO.A",1,"admin")
 end
 return .true
::class VerifierApp subclass MigratableJobStarterApplication
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
 return .MigratableJobResumeResult~success("unused")
::class TestDigest
::method digest
 use strict arg text
 return "D:"||text
::requires "MigratableJobRemoteStart.cls"
