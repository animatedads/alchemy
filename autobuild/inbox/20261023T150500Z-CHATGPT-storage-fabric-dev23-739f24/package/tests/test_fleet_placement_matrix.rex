GB=1024*1024*1024
MB=1024*1024

inv=.StorageNodeInventory~new
unknown=.StorageServiceLifecycle~new(.StorageSafetyClass~UNKNOWN,.StorageLifecycleState~STABLE)
disposable=.StorageServiceLifecycle~new(.StorageSafetyClass~DISPOSABLE,.StorageLifecycleState~CREDIT_LIMITED,"2026-10","temporary Azure trial")
inv~putNode(.StorageNodeDescriptor~new("ed209a","oracle","193.123.184.140","",unknown))
inv~putNode(.StorageNodeDescriptor~new("ed209b","oracle","193.123.190.35","",unknown))
inv~putNode(.StorageNodeDescriptor~new("ed209c","microsoft","52.146.17.8","US-EAST",disposable))
inv~putNode(.StorageNodeDescriptor~new("ed209d","aws","16.170.244.216","EU-NORTH-1",unknown))

wm=.StorageWorkspaceManager~new
/* The two Oracle capacity domains are intentionally separate. */
wm~registerPool(.StoragePool~new("ed209a-root","oracle","/work","fs:ed209a-root",.StoragePoolMode~WORKSPACE,0,"ed209a","",unknown))
wm~registerPool(.StoragePool~new("ed209b-root","oracle","/work","fs:ed209b-root",.StoragePoolMode~WORKSPACE,0,"ed209b","",unknown))
wm~observeCapacity(.StorageCapacityObservation~new("fs:ed209a-root",30*GB,30*GB))
wm~observeCapacity(.StorageCapacityObservation~new("fs:ed209b-root",30*GB,30*GB))

/* Azure root is admitted disposable workspace.  The discovered 1 TiB and
 * 110 GiB devices are deliberately absent from WorkspaceManager until they
 * are explicitly qualified/admitted. */
wm~registerPool(.StoragePool~new("ed209c-root","microsoft","/","fs:ed209c-root",.StoragePoolMode~WORKSPACE,0,"ed209c","US-EAST",disposable))
wm~observeCapacity(.StorageCapacityObservation~new("fs:ed209c-root",29*GB,27*GB))

video=.StorageObject~new(.StorageRef~new("sha256:video"),"video.mov",20*GB,"video/quicktime")
video~addLocation(.StorageLocation~new("oracle","/data/video.mov","fs:ed209a-root",.StorageLocationState~AVAILABLE,"",.true,"sha256:video",.StorageSafetyClass~UNKNOWN,.StorageLifecycleState~STABLE,"ed209a"))
inputs=.array~new; inputs~append(video)

matrix=.StorageFleetPlacementAdvisor~new~assessInventory(inv,inputs,25*GB,10*MB,5*GB,wm)
a=matrix~forNode("ed209a")
b=matrix~forNode("ed209b")
c=matrix~forNode("ed209c")
d=matrix~forNode("ed209d")

call assertTrue a~feasible,"ed209a storage feasible"
call assertEq .StoragePlacementAction~JOB_TO_DATA,a~action,"ed209a gets job-to-data evidence"
call assertEq 0,a~materializeBytes,"ed209a already has input"

call assertTrue b~feasible,"ed209b storage feasible"
call assertEq .StoragePlacementAction~DATA_TO_JOB,b~action,"ed209b requires data move"
call assertEq 20*GB,b~materializeBytes,"ed209b must materialise source"

call assertTrue c~feasible,"ed209c root fits 25 GiB request"
call assertEq 5*GB,c~mandatoryOutputCommitBytes,"Azure disposable output must leave node"
call assertTrue c~pool~disposable,"Azure selected pool remains disposable"

call assertFalse d~feasible,"ed209d has no observed/admitted workspace yet"

/* 40 GiB must fail on all currently admitted pools.  The inventory may know
 * Azure has a 1 TiB device, but mere device presence is not workspace. */
m40=.StorageFleetPlacementAdvisor~new~assessInventory(inv,inputs,40*GB,10*MB,5*GB,wm)
call assertFalse m40~forNode("ed209a")~feasible,"ed209a not secretly combined with ed209b"
call assertFalse m40~forNode("ed209b")~feasible,"ed209b not secretly combined with ed209a"
call assertFalse m40~forNode("ed209c")~feasible,"unqualified Azure 1 TiB device is not allocatable"
call assertFalse m40~forNode("ed209d")~feasible,"unknown AWS capacity is not invented"

say "PASS ED209 fleet storage-placement matrix / no invented capacity"
exit 0

::routine assertTrue
  use arg v,l
  if \v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::routine assertFalse
  use arg v,l
  if v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"
