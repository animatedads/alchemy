/* dev9 peer-source resolver semantic smoke with fake materialiser. */
ref=.StorageRef~new("peer-source:test","sha256:"||copies("b",64))
obj=.StorageObject~new(ref,"peer-source-test",10,"application/octet-stream")
loc=.StorageLocation~new("peer-provider","peer:test","peer-domain",.StorageLocationState~AVAILABLE,"",.true,"sha256:peer",.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE,"NODE-B","VENDOR-B","SITE-B","VENDOR-B/SITE-B")
obj~addLocation(loc)

allowed=.array~of("NODE-B","NODE-C")
selector=.StorageRepairPeerSelector~new(allowed)
payload=.directory~new
metadata=.directory~new
metadata["source_peer"]="NODE-B"
payload["metadata"]=metadata
call assert selector~select(obj,payload)="NODE-B","explicit verified peer selected"

metadata["source_peer"]="NODE-X"
call assert selector~select(obj,payload)="","non-allowlisted peer rejected"
metadata["source_peer"]="NODE-B"

allocator=.FakePathAllocator~new("/tmp/peer-repair-test")
materialiser=.FakeMaterialiser~new(ref)
resolver=.StoragePeerRepairSourceResolver~new(.FakeClient~new,materialiser,selector,allocator)
result=resolver~resolve(obj,payload)
call assert result~ok,"resolver succeeds"
call assert result~verified,"resolver returns verified source"
call assert result~temporary,"resolver marks source temporary"
call assert result~verificationRef="sha256:"||copies("b",64),"verification ref"
call assert materialiser~peer="NODE-B","materialiser receives selected peer"

say "PASS Storage peer repair-source resolver semantic smoke"
exit 0

assert: procedure
  use strict arg condition,label
  if \\condition then do
    say "FAIL" label
    exit 1
  end
  return

::class FakeClient public

::class FakePathAllocator public
::method init
  expose path
  use strict arg pathArg
  path=pathArg
::method allocate
  expose path
  use strict arg object,payload=.nil
  return path

::class FakePeerResult public
::attribute ok get
::attribute code get
::attribute path get
::attribute digest get
::method init
  expose ok code path digest
  use strict arg pathArg,digestArg
  ok=.true; code="VERIFIED"; path=pathArg; digest=digestArg

::class FakeMaterialiser public
::attribute peer get
::method init
  expose ref peer
  use strict arg refArg
  ref=refArg; peer=""
::method materialise
  expose ref peer
  use strict arg client,peerNodeId,refArg,target
  peer=peerNodeId
  return .FakePeerResult~new(target,substr(ref~digest,8))

::requires "../src/StorageRepairPeerSource.cls"
