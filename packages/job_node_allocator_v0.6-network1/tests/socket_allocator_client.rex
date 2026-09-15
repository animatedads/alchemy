bridge=value("QF_CRYPTO_FOREIGN_BRIDGE",,"ENVIRONMENT")
if bridge<>"" then ignore=.CryptoForeignRuntimeInstaller~install(bridge)
parse arg storeRoot clientPortFile serverPortFile keyHex .
manager=.ObjectQueueManager~new(storeRoot,.QueueGraphPayloadCodec~new,"admin")
if manager~queue("XMIT.B")==.nil then call must manager~createQueue("XMIT.B","PERMANENT","JNA",100,"admin"),"create XMIT.B"
if manager~queue("REPLY")==.nil then do
  call must manager~createQueue("REPLY","PERMANENT","JNA",100,"admin"),"create REPLY"
  call must manager~grant("REPLY","wire-a",.QueueAccess~PUT,"admin"),"grant reply put"
  call must manager~grant("REPLY","client-a",.QueueAccess~GET,"admin"),"grant reply get"
end
/* Fabric must exist before listener; endpoint B is registered after server port appears. */
transport=.QueueSocketClientTransport~new("admin")
fabric=.QueueChannelFabric~new("QM.A",manager,transport,"admin")
if fabric~receiverChannel("B.TO.A")==.nil then call must fabric~defineReceiverChannel("B.TO.A","QM.B","wire-a","TEMPORARY","admin"),"receiver B-A"
call must fabric~startReceiverChannel("B.TO.A","admin"),"start receiver"
listener=.QueueSocketListener~new("QM.A","127.0.0.1",0,fabric)
ignore=listener~trustPeer("QM.B","wire-a","k1",keyHex,.array~of("127.0.0.1"))
if \listener~start then exit 31
s=.stream~new(clientPortFile); s~open("write replace"); ignore=s~lineout(listener~port); s~close
/* Wait for server port publication. */
do i=1 to 400
  if stream(serverPortFile,"c","query exists")<>"" then leave
  call syssleep .025
end
if stream(serverPortFile,"c","query exists")="" then exit 32
s=.stream~new(serverPortFile); s~open("read"); serverPort=s~linein; s~close
ignore=transport~registerEndpoint("QM.B","127.0.0.1",serverPort,"wire-b","k1",keyHex)
if fabric~senderChannel("A.TO.B")==.nil then call must fabric~defineSenderChannel("A.TO.B","XMIT.B","QM.B","A.TO.B","admin","wire-b",5,"PERMANENT","admin"),"sender A-B"
call must fabric~startSenderChannel("A.TO.B","admin"),"start sender"
if fabric~remoteQueue("B.JNA.REQUEST")==.nil then do
  call must fabric~defineRemoteQueue("B.JNA.REQUEST","REQUEST","QM.B","XMIT.B","A.TO.B","JNA","PERMANENT","admin","admin"),"remote request"
  call must fabric~grantRemotePut("B.JNA.REQUEST","client-a","admin"),"grant request"
end
client=.JobNodeNetworkAllocatorClient~new(fabric,"B.JNA.REQUEST",manager,"REPLY","client-a","client-a")
now=200000
req=.JobNodeRequirement~new(.array~of("UK"),.array~of("AUDIO"),.array~of("TRUSTED"),.nil,.nil,.array~of("OOREXX"),.nil,"X86_64",1024,1000,1,1024,1000,1,0,.nil,"r1")
pr=.JobPlacementRequest~new("SOCKET-JOB",req,"OWNER-A",0,0,0,.nil)
plan=roundtrip(client,fabric,listener,"NET-PLAN","PLAN",pr,.nil,now,30000); call equal plan["code"],"PLAN_READY","plan"
alloc=roundtrip(client,fabric,listener,"NET-ALLOC","ALLOCATE",pr,.nil,now,30000); call equal alloc["code"],"PLACED","allocate"
lease=.JobNodeNetworkCodec~decodeLease(alloc["data"]["lease"]); call equal lease~nodeId,"NET-NODE-B","node"
replay=roundtrip(client,fabric,listener,"NET-ALLOC","ALLOCATE",pr,.nil,now,30000); call assert replay["replayed"],"replay"
check=roundtrip(client,fabric,listener,"NET-CHECK","CHECK",pr,lease,now+1000,30000); call equal check["code"],"LEASE_VALID","check"
release=roundtrip(client,fabric,listener,"NET-RELEASE","RELEASE",.nil,lease,now+2000,30000); call equal release["code"],"RELEASED","release"
ignore=listener~stop
say "CLIENT_OK network allocator encrypted socket round-trip node="lease~nodeId "placement="lease~placementId
exit 0
roundtrip: procedure
  use arg client,fabric,listener,id,op,pr,lease,now,duration
  call must client~submit(id,op,pr,lease,now,duration),"submit" op
  call must fabric~pump("A.TO.B",1,"admin"),"pump" op
  accepted=listener~serveOne
  call must accepted,"receive socket response" op
  rr=client~receive; call must rr,"receive queue response" op
  return rr~value
must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 30; end
  return
assert: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 33; end
  return
equal: procedure
  use arg got,want,label
  if got<>want then do; say "FAIL" label "got="got "want="want; exit 34; end
  return
::requires 'JobNodeNetworkService.cls'
::requires 'ObjectQueueSocketTransport.cls'
::requires 'CryptoForeignRuntimeProvider.cls'
