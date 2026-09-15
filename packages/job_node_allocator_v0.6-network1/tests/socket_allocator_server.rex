bridge=value("QF_CRYPTO_FOREIGN_BRIDGE",,"ENVIRONMENT")
if bridge<>"" then ignore=.CryptoForeignRuntimeInstaller~install(bridge)
parse arg storeRoot portFile clientPort keyHex count .
if count="" then count=5
now=200000
registry=.NodeCapabilityRegistry~new
ignore=registry~advertiseCapability(.NodeCapabilityStatement~new("NET-NODE-A",1,"proof-a",.array~of("UK"),.array~of("AUDIO"),.array~of("TRUSTED"),.nil,.nil,.array~of("OOREXX"),.nil,"X86_64",8192,100000,4,"r1"))
ignore=registry~advertiseCapability(.NodeCapabilityStatement~new("NET-NODE-B",1,"proof-b",.array~of("UK"),.array~of("AUDIO"),.array~of("TRUSTED"),.nil,.nil,.array~of("OOREXX"),.nil,"X86_64",16384,100000,8,"r1"))
ignore=registry~observeCapacity(.NodeCapacityObservation~new("NET-NODE-A",1,1,now,now+600000,4096,50000,2,1000,0,0,"obs-a"))
ignore=registry~observeCapacity(.NodeCapacityObservation~new("NET-NODE-B",1,1,now,now+600000,12000,90000,7,9000,0,0,"obs-b"))
eligibility=.JobNodeEligibilityPolicy~new; placement=.JobNodePlacementPolicy~new; ownership=.JobNodeOwnershipRegistry~new
allocator=.JobNodeAllocator~new(registry,eligibility,placement,.nil,.nil,"socket-net",.nil,ownership)
manager=.ObjectQueueManager~new(storeRoot,.QueueGraphPayloadCodec~new,"admin")
if manager~queue("REQUEST")==.nil then do
  call must manager~createQueue("REQUEST","PERMANENT","JNA",100,"admin"),"create REQUEST"
  call must manager~grant("REQUEST","wire-b",.QueueAccess~PUT,"admin"),"grant REQUEST put"
  call must manager~grant("REQUEST","jna-service",.QueueAccess~GET,"admin"),"grant REQUEST get"
end
if manager~queue("XMIT.A")==.nil then call must manager~createQueue("XMIT.A","PERMANENT","JNA",100,"admin"),"create XMIT.A"
transport=.QueueSocketClientTransport~new("admin")
ignore=transport~registerEndpoint("QM.A","127.0.0.1",clientPort,"wire-a","k1",keyHex)
fabric=.QueueChannelFabric~new("QM.B",manager,transport,"admin")
if fabric~receiverChannel("A.TO.B")==.nil then call must fabric~defineReceiverChannel("A.TO.B","QM.A","wire-b","TEMPORARY","admin"),"receiver A-B"
call must fabric~startReceiverChannel("A.TO.B","admin"),"start receiver"
if fabric~senderChannel("B.TO.A")==.nil then call must fabric~defineSenderChannel("B.TO.A","XMIT.A","QM.A","B.TO.A","admin","wire-a",5,"PERMANENT","admin"),"sender B-A"
call must fabric~startSenderChannel("B.TO.A","admin"),"start sender"
if fabric~remoteQueue("A.JNA.REPLY")==.nil then do
  call must fabric~defineRemoteQueue("A.JNA.REPLY","REPLY","QM.A","XMIT.A","B.TO.A","JNA","PERMANENT","admin","admin"),"remote reply"
  call must fabric~grantRemotePut("A.JNA.REPLY","jna-service","admin"),"grant remote reply"
end
access=.JobNodeNetworkAccessPolicy~new; ignore=access~grant("client-a",.array~of("PLAN","ALLOCATE","CHECK","RELEASE"),"OWNER-A")
ledger=.JobNodeNetworkRequestLedger~new(storeRoot || "/network.requests",.QueueGraphPayloadCodec~new)
service=.JobNodeNetworkAllocatorService~new(allocator,registry,eligibility,placement,manager,"REQUEST",fabric,"jna-service",access,ledger,.nil,"ALLOCATOR-SOCKET")
ignore=service~bindClientReply("client-a","A.JNA.REPLY")
listener=.QueueSocketListener~new("QM.B","127.0.0.1",0,fabric)
ignore=listener~trustPeer("QM.A","wire-b","k1",keyHex,.array~of("127.0.0.1"))
if \listener~start then exit 21
s=.stream~new(portFile); s~open("write replace"); ignore=s~lineout(listener~port); s~close

do i=1 to count
  sr=listener~serveOne
  if \sr~ok then do; say "FAIL serve" sr~code sr~detail; exit 22; end
  pr=service~processOne
  if \pr~ok then do; say "FAIL process" pr~code pr~detail; exit 23; end
  pp=fabric~pump("B.TO.A",1,"admin")
  if \pp~ok then do; say "FAIL response pump" pp~code pp~detail; exit 24; end
end
ignore=listener~stop
say "SERVER_OK requests="count "connections="listener~connectionCount "accepted="listener~acceptedCount
exit 0
must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 20; end
  return
::requires 'JobNodeNetworkService.cls'
::requires 'JobNodeLiveness.cls'
::requires 'ObjectQueueSocketTransport.cls'
::requires 'CryptoForeignRuntimeProvider.cls'
