obj=.StorageObject~new(.StorageRef~new("sha256:media"),"media.mov",100,"video/quicktime")
local=.StorageLocation~new("tom-space","/srv/space/media.mov","posixfs:root",.StorageLocationState~AVAILABLE,"",.false,"")
obj~addLocation(local)
policy=.StorageReplicaPolicy~new
call assertFalse policy~safeToEvict(obj,local),"sole copy cannot be evicted"

remote=.StorageLocation~new("google-drive","drive:file123","gdrive:default",.StorageLocationState~AVAILABLE,"",.false,"")
obj~addLocation(remote)
call assertFalse policy~safeToEvict(obj,local),"unverified offload cannot authorize eviction"

verified=.StorageLocation~new("google-drive","drive:file123","gdrive:default",.StorageLocationState~AVAILABLE,"",.true,"sha256:media")
obj~addLocation(verified)
call assertTrue policy~safeToEvict(obj,local),"verified remote replica authorizes eviction"

t=.StorageTransfer~new("xfer-1",obj~ref,local,"google-drive","drive:file123",100)
call assertTrue t~begin,"begin"
call assertTrue t~progress(100),"progress"
call assertTrue t~copied,"copied"
call assertFalse t~commit,"cannot commit before verification"
call assertTrue t~verify("sha256:media"),"verify"
call assertTrue t~commit,"commit after verification"
call assertEq .StorageTransferState~COMMITTED,t~state,"state"
say "PASS transfer/replica safety"
exit 0

::routine assertTrue
  use arg value,label
  if \value then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end
::routine assertFalse
  use arg value,label
  if value then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end
::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"