
GB=1024*1024*1024
wm=.StorageWorkspaceManager~new
/* / and /srv/space can be distinct pool roots while sharing one filesystem. */
rootPool=.StoragePool~new("root-work","local","/var/tmp/work","posixfs:/dev/nvme0n1p3",.StoragePoolMode~WORKSPACE,5*GB)
spacePool=.StoragePool~new("space","local","/srv/space","posixfs:/dev/nvme0n1p3",.StoragePoolMode~BOTH,5*GB)
wm~registerPool(rootPool)~registerPool(spacePool)
wm~observeCapacity(.StorageCapacityObservation~new("posixfs:/dev/nvme0n1p3",324*GB,86*GB))

call assertEq 81*GB,wm~availableForPool("space"),"initial allocatable"
a=wm~allocate("space",50*GB,"video-job","big-video")
call assertTrue a<>.nil,"50 GiB reservation"
/* Same capacity domain: reservation must reduce both views. */
call assertEq 31*GB,wm~availableForPool("root-work"),"shared domain reservation"
b=wm~allocate("root-work",32*GB,"other-job")
call assertTrue b==.nil,"must not double-count shared filesystem free space"
call assertTrue wm~release("big-video"),"release"
call assertEq 81*GB,wm~availableForPool("space"),"capacity restored"
say "PASS capacity-domain dedup"
exit 0

::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use arg value,label
  if \value then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"