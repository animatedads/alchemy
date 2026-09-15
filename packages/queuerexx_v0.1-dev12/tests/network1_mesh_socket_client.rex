bridge=value("QF_CRYPTO_FOREIGN_BRIDGE",,"ENVIRONMENT")
if bridge<>"" then ignore=.CryptoForeignRuntimeInstaller~install(bridge)
parse arg root clientPortFile serverPortFile resultFile keyHex
codec=.QueueGraphPayloadCodec~new
manager=.ObjectQueueManager~new(root||"/fabric",codec,"A-admin")
transport=.QueueSocketClientTransport~new("A-admin",codec)
fabric=.QueueChannelFabric~new("NODE-A",manager,transport,"A-admin")
listener=.QueueSocketListener~new("NODE-A","127.0.0.1",0,fabric,codec)
mesh=.QueueRexxPeerMeshRuntime~new("A",root,"NODE-A",manager,fabric,transport,listener,"A-admin",.TestDigest~new)
ignore=listener~trustPeer("NODE-B","mesh-ab","k1",keyHex,.array~of("127.0.0.1"))
if \mesh~startListener then do; say listener~lastError; exit 51; end
call lineout clientPortFile,listener~port; call lineout clientPortFile
serverPort=""
do i=1 to 400
  if stream(serverPortFile,"c","query exists")<>"" then do
    f=.stream~new(serverPortFile); f~open("read"); serverPort=f~linein~strip; f~close
    if serverPort<>"" then leave
  end
  call SysSleep 0.025
end
if serverPort="" then exit 52
peer=mesh~bindSocketPeer("B","NODE-B","127.0.0.1",serverPort,"mesh-ab","k1",keyHex,.array~of("127.0.0.1"),.array~of(.QueueRexxPeerOperation~HEALTH),10000)
call must peer,"bind peer"
health=mesh~client~request("B",.QueueRexxPeerOperation~HEALTH,.directory~new,.directory~new,0,0,"socket-health")
call must health,"mesh health"
if health~value["decision"]<>"APPROVE" then do; say "FAIL health decision"; exit 53; end
created=.QueueRexxJobNodePeerClientFactory~create(mesh,"B","FD-A","JNA.REPLY.FD-A","jna-client","JNA.REQUEST")
call must created,"create exact network1 client"
proxy=created~value["allocator_proxy"]
call assert created~value["client"]~isA(.JobNodeNetworkAllocatorClient),"exact upstream client"
now=200000
req=.JobNodeRequirement~new(.array~of("UK"),.array~of("AUDIO"),.array~of("TRUSTED"),.nil,.nil,.array~of("OOREXX"),.nil,"X86_64",1024,1000,1,1024,1000,1,0,.nil,"r1")
pr=.JobPlacementRequest~new("MESH-SOCKET-JOB",req,"OWNER-A",0,0,0,.nil)
d=proxy~allocate(pr,now,30000)
call assert d~placed,"allocate"
lease=d~lease
call equal lease~nodeId,"NET-NODE-B","node"
call assert proxy~verifyLease(lease,pr,now+1000),"check"
call assert proxy~releasePlacement(lease),"release"
call lineout resultFile,"node="||lease~nodeId||";placement="||lease~placementId||";auth="||listener~authenticatedCount||";accepted="||listener~acceptedCount
call lineout resultFile
ignore=listener~stop
exit 0
must: procedure
  use arg r,label
  if r==.nil | \r~ok then do; say "FAIL" label; if r<>.nil then say r~code r~detail; exit 50; end
  return
assert: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 54; end
  return
equal: procedure
  use arg got,want,label
  if got<>want then do; say "FAIL" label got want; exit 55; end
  return
::class TestDigest public
::method digest
  use strict arg text
  return "D:"||c2x(text~string)
::requires "QueueRexxAuthority.cls"
::requires "CryptoForeignRuntimeProvider.cls"
