now=100000
registry=.NodeCapabilityRegistry~new
capA=.NodeCapabilityStatement~new("NODE-A",1,"proof-a",.array~of("UK"),.array~of("AUDIO"),.array~of("TRUSTED"),.nil,.nil,.array~of("OOREXX"),.array~of("SOURCE"),"X86_64",8192,100000,4,"r1")
capB=.NodeCapabilityStatement~new("NODE-B",1,"proof-b",.array~of("UK"),.array~of("AUDIO"),.array~of("TRUSTED"),.nil,.nil,.array~of("OOREXX"),.array~of("FAST"),"X86_64",16384,100000,8,"r1")
call assert registry~advertiseCapability(capA), "advertise A"
call assert registry~advertiseCapability(capB), "advertise B"
call assert registry~observeCapacity(.NodeCapacityObservation~new("NODE-A",1,1,now,now+600000,4096,50000,2,1000,0,0,"obs-a")), "capacity A"
call assert registry~observeCapacity(.NodeCapacityObservation~new("NODE-B",1,1,now,now+600000,12000,90000,7,9000,0,0,"obs-b")), "capacity B"
eligibility=.JobNodeEligibilityPolicy~new
placement=.JobNodePlacementPolicy~new
ownership=.JobNodeOwnershipRegistry~new
allocator=.JobNodeAllocator~new(registry,eligibility,placement,.TestDigest~new,.nil,"net-test",.nil,ownership)

transport=.QueueInProcessTransport~new
ma=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
mb=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
call must ma~createQueue("XMIT.B","TEMPORARY","JNA",100,"admin"), "create A xmit"
call must ma~createQueue("REPLY","TEMPORARY","JNA",100,"admin"), "create A reply"
call must ma~grant("REPLY","wire-a",.QueueAccess~PUT,"admin"), "grant A reply wire"
call must ma~grant("REPLY","client-a",.QueueAccess~GET,"admin"), "grant A reply get"
call must mb~createQueue("REQUEST","TEMPORARY","JNA",100,"admin"), "create B request"
call must mb~createQueue("XMIT.A","TEMPORARY","JNA",100,"admin"), "create B xmit"
call must mb~grant("REQUEST","wire-b",.QueueAccess~PUT,"admin"), "grant B request wire"
call must mb~grant("REQUEST","jna-service",.QueueAccess~GET,"admin"), "grant B request get"
fa=.QueueChannelFabric~new("QM.A",ma,transport,"admin")
fb=.QueueChannelFabric~new("QM.B",mb,transport,"admin")
ignore=transport~registerEndpoint("QM.A",fa)
ignore=transport~registerEndpoint("QM.B",fb)
call must fa~defineSenderChannel("A.TO.B","XMIT.B","QM.B","A.TO.B","admin","wire-b",0,"TEMPORARY","admin"), "sender A-B"
call must fb~defineReceiverChannel("A.TO.B","QM.A","wire-b","TEMPORARY","admin"), "receiver A-B"
call must fb~defineSenderChannel("B.TO.A","XMIT.A","QM.A","B.TO.A","admin","wire-a",0,"TEMPORARY","admin"), "sender B-A"
call must fa~defineReceiverChannel("B.TO.A","QM.B","wire-a","TEMPORARY","admin"), "receiver B-A"
call must fa~startSenderChannel("A.TO.B","admin"), "start sender A-B"
call must fb~startReceiverChannel("A.TO.B","admin"), "start recv A-B"
call must fb~startSenderChannel("B.TO.A","admin"), "start sender B-A"
call must fa~startReceiverChannel("B.TO.A","admin"), "start recv B-A"
call must fa~defineRemoteQueue("B.JNA.REQUEST","REQUEST","QM.B","XMIT.B","A.TO.B","JNA","TEMPORARY","admin","admin"), "remote request"
call must fa~grantRemotePut("B.JNA.REQUEST","client-a","admin"), "grant remote request"
call must fb~defineRemoteQueue("A.JNA.REPLY","REPLY","QM.A","XMIT.A","B.TO.A","JNA","TEMPORARY","admin","admin"), "remote reply"
call must fb~grantRemotePut("A.JNA.REPLY","jna-service","admin"), "grant remote reply"

access=.JobNodeNetworkAccessPolicy~new
ignore=access~grant("client-a",.array~of("PLAN","ALLOCATE","CHECK","RENEW","RELEASE"),"OWNER-A")
ledger=.JobNodeNetworkRequestLedger~new("",.QueueGraphPayloadCodec~new)
service=.JobNodeNetworkAllocatorService~new(allocator,registry,eligibility,placement,mb,"REQUEST",fb,"jna-service",access,ledger,.TestDigest~new,"ALLOCATOR-1")
ignore=service~bindClientReply("client-a","A.JNA.REPLY")
client=.JobNodeNetworkAllocatorClient~new(fa,"B.JNA.REQUEST",ma,"REPLY","client-a","client-a",.TestDigest~new)

req=.JobNodeRequirement~new(.array~of("UK"),.array~of("AUDIO"),.array~of("TRUSTED"),.nil,.nil,.array~of("OOREXX"),.nil,"X86_64",1024,1000,1,1024,1000,1,0,.nil,"r1")
pr=.JobPlacementRequest~new("JOB-1",req,"OWNER-A",0,0,0,.nil)

plan=roundtrip(client,fa,fb,service,"REQ-PLAN","PLAN",pr,.nil,now,30000)
call equal plan["code"], "PLAN_READY", "plan code"
call equal plan["data"]["selectedNodeId"], "NODE-B", "plan selected fast node"

allocated=roundtrip(client,fa,fb,service,"REQ-ALLOC","ALLOCATE",pr,.nil,now,30000)
call equal allocated["code"], "PLACED", "allocate code"
lease=.JobNodeNetworkCodec~decodeLease(allocated["data"]["lease"])
call equal lease~nodeId, "NODE-B", "allocated node"
call assert lease~ownershipEpoch>0, "ownership epoch"

replay=roundtrip(client,fa,fb,service,"REQ-ALLOC","ALLOCATE",pr,.nil,now,30000)
call assert replay["replayed"], "duplicate replayed"
call equal replay["data"]["lease"]["placementId"], lease~placementId, "same placement on replay"

conflict=roundtrip(client,fa,fb,service,"REQ-ALLOC","ALLOCATE",pr,.nil,now,31000)
call equal conflict["code"], "REQUEST_ID_CONFLICT", "conflicting request id"

checked=roundtrip(client,fa,fb,service,"REQ-CHECK","CHECK",pr,lease,now+1000,30000)
call equal checked["code"], "LEASE_VALID", "check lease"

renewed=roundtrip(client,fa,fb,service,"REQ-RENEW","RENEW",pr,lease,now+2000,30000)
call equal renewed["code"], "RENEWED", "renew lease"
lease2=.JobNodeNetworkCodec~decodeLease(renewed["data"]["lease"])
call equal lease2~renewalSequence, 1, "renewal sequence"

released=roundtrip(client,fa,fb,service,"REQ-RELEASE","RELEASE",.nil,lease2,now+3000,30000)
call equal released["code"], "RELEASED", "release"
call assert ownership~current("JOB-1",now+3000)==.nil, "ownership released"

badPr=.JobPlacementRequest~new("JOB-2",req,"OWNER-X",0,0,0,.nil)
denied=roundtrip(client,fa,fb,service,"REQ-DENIED","ALLOCATE",badPr,.nil,now+4000,30000)
call equal denied["code"], "CLIENT_NOT_AUTHORISED", "owner binding enforced"

say "PASS network allocator in-process request/reply, replay, owner auth, allocate/check/renew/release"
exit 0

roundtrip: procedure
  use arg client,fa,fb,service,id,op,pr,lease,now,duration
  call must client~submit(id,op,pr,lease,now,duration), "submit" op
  call must fa~pump("A.TO.B",1,"admin"), "pump request" op
  call must service~processOne, "service process" op
  call must fb~pump("B.TO.A",1,"admin"), "pump response" op
  rr=client~receive
  call must rr, "receive" op
  return rr~value

must: procedure
  use arg r,label
  if r==.nil then do; say "FAIL nil result" label; exit 10; end
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 11; end
  return
assert: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 12; end
  return
 equal: procedure
  use arg got,want,label
  if got<>want then do; say "FAIL" label "got="got "want="want; exit 13; end
  return

::class TestDigest
::method digest
  use arg text
  return "D:" || text

::requires 'JobNodeNetworkService.cls'
::requires 'JobNodeLiveness.cls'
