parse arg tmp .
if tmp="" then tmp="/tmp/jna-network-ledger-test.tsv"
call sysfiledelete tmp
now=300000
registry=.NodeCapabilityRegistry~new
ignore=registry~advertiseCapability(.NodeCapabilityStatement~new("NODE-Z",1,"proof",.array~of("UK"),.nil,.nil,.nil,.nil,.array~of("OOREXX"),.nil,"X86_64",8192,10000,4,"r1"))
ignore=registry~observeCapacity(.NodeCapacityObservation~new("NODE-Z",1,1,now,now+60000,4096,5000,3,1000,0,0,"obs"))
elig=.JobNodeEligibilityPolicy~new; policy=.JobNodePlacementPolicy~new; ownership=.JobNodeOwnershipRegistry~new
allocator=.JobNodeAllocator~new(registry,elig,policy,.TestDigest~new,.nil,"p",.nil,ownership)
access=.JobNodeNetworkAccessPolicy~new; ignore=access~grant("client-a",.array~of("ALLOCATE"),"OWNER-A")
ledger1=.JobNodeNetworkRequestLedger~new(tmp,.QueueGraphPayloadCodec~new)
service1=.JobNodeNetworkAllocatorService~new(allocator,registry,elig,policy,.nil,"",.nil,"svc",access,ledger1,.TestDigest~new,"S1")
req=.JobNodeRequirement~new(.array~of("UK"),.nil,.nil,.nil,.nil,.array~of("OOREXX"),.nil,"X86_64",1,1,1,1,1,1,0,.nil,"r1")
pr=.JobPlacementRequest~new("LEDGER-JOB",req,"OWNER-A")
wire=.table~new; wire["schema"]=.JobNodeNetworkBuild~REQUEST_SCHEMA; wire["api"]=.JobNodeNetworkBuild~API; wire["requestId"]="RID-1"; wire["clientId"]="client-a"; wire["operation"]="ALLOCATE"; wire["placementRequest"]=.JobNodeNetworkCodec~encodePlacementRequest(pr); wire["lease"]=.nil; wire["nowEpochMs"]=now; wire["leaseDurationMs"]=30000
r1=service1~handle(wire)
if r1["code"]<>"PLACED" then do; say "FAIL initial" r1["code"]; exit 10; end
pid=r1["data"]["lease"]["placementId"]
/* Reopen only the network ledger. A throwing allocator proves replay occurs before mutation. */
ledger2=.JobNodeNetworkRequestLedger~new(tmp,.QueueGraphPayloadCodec~new)
service2=.JobNodeNetworkAllocatorService~new(.ThrowAllocator~new,registry,elig,policy,.nil,"",.nil,"svc",access,ledger2,.TestDigest~new,"S2")
r2=service2~handle(wire)
if \r2["replayed"] then do; say "FAIL not replayed"; exit 11; end
if r2["data"]["lease"]["placementId"]<>pid then do; say "FAIL placement changed"; exit 12; end
wire["leaseDurationMs"]=31000
r3=service2~handle(wire)
if r3["code"]<>"REQUEST_ID_CONFLICT" then do; say "FAIL conflict" r3["code"]; exit 13; end
say "PASS network request ledger restart replay placement="pid
call sysfiledelete tmp
exit 0
::class TestDigest
::method digest
  use arg text
  return "D:" || text
::class ThrowAllocator
::method allocate
  raise syntax 88.900 array("allocator must not be called during network replay")
::requires 'JobNodeNetworkService.cls'
::requires 'JobNodeLiveness.cls'
