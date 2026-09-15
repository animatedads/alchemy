root="/mnt/data/queuerexx-dev12-network1-mesh-composition"
address system "rm -rf " || root || " && mkdir -p " || root
now=1000000
registry=.NodeCapabilityRegistry~new
ignore=registry~advertiseCapability(.NodeCapabilityStatement~new("NODE-WORKER",1,"proof",.array~of("UK"),.array~of("AUDIO"),.array~of("TRUSTED"),.nil,.nil,.array~of("OOREXX"),.nil,"X86_64",8192,100000,4,"r1"))
ignore=registry~observeCapacity(.NodeCapacityObservation~new("NODE-WORKER",1,1,now,now+600000,4096,50000,3,5000,0,0,"obs"))
stack=.QueueRexxAuthorityStack~new(root,registry,.JobNodeEligibilityPolicy~new,.nil,"QUEUEREXX","queue","dev12","NODE-B","127.0.0.1",0,"B-admin",now,.TestDigest~new,.nil)
call assert stack~networkService~isA(.JobNodeNetworkAllocatorService),"exact network1 service"
call assert stack~networkLedger~isA(.JobNodeNetworkRequestLedger),"exact network1 ledger"
call assert stack~accessPolicy~isA(.JobNodeNetworkAccessPolicy),"exact network1 access policy"
mesh=stack~enablePeerMesh("B",.TestDigest~new)
ops=.array~of(.QueueRexxPeerOperation~HEALTH)
r=mesh~bindFabricPeer("A","NODE-A","mesh-ab",ops,10000); call must r,"bind peer"
r=stack~bindPeerClient("FD-A","A","JNA.REPLY.FD-A",.array~of("PLAN","ALLOCATE","CHECK","RENEW","RELEASE"),"OWNER-A"); call must r,"bind JNA peer client"
b=r~value["binding"]
call equal b~senderChannel,"QRX.SERVICE.JNA.REPLY.FD-A.SEND.A","JNA response reuses peer sender"
call equal stack~requestQueue,"JNA.REQUEST","shared authority request queue"

req=.JobNodeRequirement~new(.array~of("UK"),.array~of("AUDIO"),.array~of("TRUSTED"),.nil,.nil,.array~of("OOREXX"),.nil,"X86_64",1024,1000,1,1024,1000,1,0,.nil,"r1")
pr=.JobPlacementRequest~new("MESH-JOB",req,"OWNER-A",0,0,0,.nil)
wire=.table~new
wire["schema"]=.JobNodeNetworkBuild~REQUEST_SCHEMA; wire["api"]=.JobNodeNetworkBuild~API
wire["requestId"]="MESH-ALLOC-1"; wire["clientId"]="FD-A"; wire["operation"]="ALLOCATE"
wire["placementRequest"]=.JobNodeNetworkCodec~encodePlacementRequest(pr); wire["lease"]=.nil
wire["nowEpochMs"]=now; wire["leaseDurationMs"]=30000
options=.table~new; options["persistent"]=.true; options["securityDomain"]="JNA"; options["correlationId"]="MESH-ALLOC-1"
call must stack~queueManager~put("JNA.REQUEST",wire,options,"mesh-ab"),"put authority request"
processed=stack~networkService~processOne; call must processed,"process exact network1"
response=processed~value
call equal response["code"],"PLACED","allocate code"
lease=.JobNodeNetworkCodec~decodeLease(response["data"]["lease"])
call assert lease<>.nil,"lease returned"
call equal lease~ownerNodeId,"OWNER-A","owner binding"
xmitName="QRX.SERVICE.JNA.REPLY.FD-A.XMIT.A"
xmit=stack~queueManager~queue(xmitName)
call assert xmit<>.nil,"peer xmit exists"
depth=stack~queueManager~depth(xmitName,"B-admin"); call must depth,"xmit depth"
call assert depth~value["ready"]>0,"network1 reply queued on peer mesh xmit"

/* network1 ledger replay occurs before another allocator mutation. */
call must stack~queueManager~put("JNA.REQUEST",wire,options,"mesh-ab"),"put replay"
replayed=stack~networkService~processOne; call must replayed,"process replay"
call assert replayed~value["replayed"],"exact replay"
call equal replayed~value["data"]["lease"]["placementId"],lease~placementId,"same lease replay"

changed=wire~copy; changed["leaseDurationMs"]=31000
call must stack~queueManager~put("JNA.REQUEST",changed,options,"mesh-ab"),"put conflict"
conflict=stack~networkService~processOne; call must conflict,"process conflict"
call equal conflict~value["code"],"REQUEST_ID_CONFLICT","request id conflict"

say "PASS QueueRexx dev12: general peer mesh carries exact job.node.allocator.network/0.1 service without a second placement protocol; replay/ACL/lease authority remain network1/JTN"
exit 0
must: procedure
  use arg r,label
  if r==.nil | \r~ok then do
    say "FAIL" label
    if r<>.nil then say r~code r~detail
    exit 20
  end
  return
assert: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 21; end
  return
equal: procedure
  use arg got,want,label
  if got<>want then do; say "FAIL" label "got="got "want="want; exit 22; end
  return
::class TestDigest public
::method digest
  use strict arg text
  return "D:"||c2x(text~string)
::requires "QueueRexxAuthority.cls"
