p=.RemovableStorageProvider~new("usb-archive","WD8TB-01","fs-uuid-123")
identity=p~stableIdentity
call assertEq .StorageProviderAvailability~INTERMITTENT,p~availability,"removable availability class"
call assertEq .StorageLocationState~OFFLINE,p~state,"starts offline"
call assertFalse p~canWorkspace,"offline media is not workspace-capable"

p~connect("/run/media/hc3/VIDEO8")
call assertEq .StorageLocationState~AVAILABLE,p~state,"connected state"
call assertTrue p~canWorkspace,"connected USB can be workspace"
call assertEq identity,p~stableIdentity,"mount path is not identity"

book=.StoragePerformanceBook~new
book~observe(.StoragePerformanceObservation~new(p~providerId,125,108,8,"2026-09-05T16:50:00+01:00","transfer:test"))
obs=book~latestFor(p~providerId)
call assertEq 125,obs~sequentialReadMBps,"observed USB read performance"

p~disconnect
call assertEq .StorageLocationState~OFFLINE,p~state,"disconnected state"
call assertEq identity,p~stableIdentity,"stable identity survives disconnect"

/* Catalogue knowledge survives absence of the medium. */
cat=.StorageCatalogue~new
o=.StorageObject~new(.StorageRef~new("sha256:usb-only"),"archive.mov",999,"video/quicktime")
o~addLocation(.StorageLocation~new(p~providerId,"/bodycam/archive.mov","usbfs:"||p~volumeId,.StorageLocationState~OFFLINE))
cat~put(o)
path="/tmp/storage-removable-catalogue.tsv"
cat~save(path)
cat2=.StorageCatalogue~new; cat2~load(path); call SysFileDelete path
found=cat2~get("sha256:usb-only")
call assertTrue found<>.nil,"offline object remains catalogued"
call assertEq .StorageLocationState~OFFLINE,found~locations[1]~state,"offline state persists"

say "PASS removable provider identity / performance / offline catalogue"
exit 0

::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use arg v,l
  if \v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::routine assertFalse
  use arg v,l
  if v then do; say "FAIL" l; raise syntax 88.900 array("test assertion failed"); end
::requires "src/StorageFabric.cls"
