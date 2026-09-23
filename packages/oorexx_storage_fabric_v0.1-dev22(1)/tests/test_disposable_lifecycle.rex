GB=1024*1024*1024

/* Azure trial: physically capable storage, intentionally not safety. */
life=.StorageServiceLifecycle~new(.StorageSafetyClass~DISPOSABLE,.StorageLifecycleState~CREDIT_LIMITED,"2026-10-20","trial credit / account expected to disappear")
p=.StoragePool~new("azure-work","azure:test-us-east","/work","azurefs:nvme0n2",.StoragePoolMode~BOTH,1*GB,"azure-test-us-east","US-EAST",life)
call assertTrue p~canWorkspace,"disposable service may be workspace"
call assertTrue p~canDurable,"underlying pool can physically persist bytes"
call assertFalse p~countsAsDurable,"disposable lifecycle must not count as durable safety"
call assertTrue p~disposable,"pool disposable flag"
/* Even a mistaken SAFE label cannot make CREDIT_LIMITED service life durable. */
creditLife=.StorageServiceLifecycle~new(.StorageSafetyClass~SAFE,.StorageLifecycleState~CREDIT_LIMITED,"2026-10-20","bounded service")
creditPool=.StoragePool~new("credit-safe-label","azure:test-us-east","/credit","azurefs:credit",.StoragePoolMode~BOTH,0,"azure-test-us-east","US-EAST",creditLife)
call assertFalse creditPool~countsAsDurable,"non-stable service lifecycle cannot satisfy durability"

wm=.StorageWorkspaceManager~new
wm~registerPool(p)
wm~observeCapacity(.StorageCapacityObservation~new("azurefs:nvme0n2",1024*GB,900*GB))
a=wm~allocate("azure-work",100*GB,"video-transcode","az-ws")
call assertTrue a<>.nil,"large disposable workspace allocation is allowed"

/* A verified disposable copy must never authorize eviction of the safe copy. */
obj=.StorageObject~new(.StorageRef~new("sha256:source"),"source.mov",20*GB,"video/quicktime")
safe=.StorageLocation~new("local","/srv/space/source.mov","posixfs:local",.StorageLocationState~AVAILABLE,"",.true,"sha256:source",.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE,"tom")
disposable=.StorageLocation~new("azure:test-us-east","/work/source.mov","azurefs:nvme0n2",.StorageLocationState~AVAILABLE,"",.true,"sha256:source",.StorageSafetyClass~DISPOSABLE,.StorageLifecycleState~CREDIT_LIMITED,"azure-test-us-east")
obj~addLocation(safe)~addLocation(disposable)
policy=.StorageReplicaPolicy~new
call assertFalse policy~safeToEvict(obj,safe),"verified disposable replica is not safety"
call assertEq 1,policy~durableReplicaCount(obj),"only safe verified replica counts"

/* Once a second safe verified copy exists, eviction is permitted. */
drive=.StorageLocation~new("google-drive","drive:file-safe","gdrive:default",.StorageLocationState~AVAILABLE,"",.true,"sha256:source",.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE,"")
obj~addLocation(drive)
call assertTrue policy~safeToEvict(obj,safe),"verified safe remote replica authorizes eviction"
call assertEq 2,policy~durableReplicaCount(obj),"two safe replicas"

/* Safety/lifecycle/node facts are catalogue-persistent. */
tmp=SysTempFileName("/tmp/storage-life-??????")
cat=.StorageCatalogue~new; cat~put(obj); cat~save(tmp)
cat2=.StorageCatalogue~new; cat2~load(tmp)
loaded=cat2~get("sha256:source")
foundDisposable=.false
do l over loaded~locations
  if l~providerId="azure:test-us-east" then do
    call assertEq .StorageSafetyClass~DISPOSABLE,l~safetyClass,"persist disposable safety"
    call assertEq .StorageLifecycleState~CREDIT_LIMITED,l~lifecycleState,"persist service lifecycle"
    call assertEq "azure-test-us-east",l~nodeId,"persist node locality"
    foundDisposable=.true
  end
end
call SysFileDelete tmp
call assertTrue foundDisposable,"reloaded disposable location"

/* TERMINATING capacity is no longer admissible for new workspace. */
ending=.StorageServiceLifecycle~new(.StorageSafetyClass~DISPOSABLE,.StorageLifecycleState~TERMINATING,"2026-09-05","service terminating")
endPool=.StoragePool~new("ending","azure:test-us-east","/ending","azurefs:ending",.StoragePoolMode~WORKSPACE,0,"azure-test-us-east","US-EAST",ending)
wm~registerPool(endPool)
wm~observeCapacity(.StorageCapacityObservation~new("azurefs:ending",100*GB,100*GB))
call assertFalse endPool~canWorkspace,"terminating pool blocks new workspace"
call assertEq 0,wm~availableForPool("ending"),"terminating pool has zero allocatable workspace"

say "PASS disposable service lifecycle / replica safety"
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
