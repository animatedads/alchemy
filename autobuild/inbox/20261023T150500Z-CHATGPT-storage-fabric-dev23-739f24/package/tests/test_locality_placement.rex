GB=1024*1024*1024
MB=1024*1024
wm=.StorageWorkspaceManager~new

/* Two Oracle nodes each have 30 GiB free.  They are separate capacity domains. */
lifeSafe=.StorageServiceLifecycle~new(.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE)
oa=.StoragePool~new("oracle-a","oracle","/work","nodefs:oracle-a",.StoragePoolMode~BOTH,0,"oracle-a","UK-LONDON-1",lifeSafe)
ob=.StoragePool~new("oracle-b","oracle","/work","nodefs:oracle-b",.StoragePoolMode~BOTH,0,"oracle-b","UK-LONDON-1",lifeSafe)
wm~registerPool(oa)~registerPool(ob)
wm~observeCapacity(.StorageCapacityObservation~new("nodefs:oracle-a",30*GB,30*GB))
wm~observeCapacity(.StorageCapacityObservation~new("nodefs:oracle-b",30*GB,30*GB))

/* Azure has a large but disposable workspace. */
azLife=.StorageServiceLifecycle~new(.StorageSafetyClass~DISPOSABLE,.StorageLifecycleState~CREDIT_LIMITED,"2026-10","trial")
az=.StoragePool~new("azure-big-work","azure","/work","azurefs:nvme0n2",.StoragePoolMode~BOTH,0,"azure-test-us-east","US-EAST",azLife)
wm~registerPool(az)
wm~observeCapacity(.StorageCapacityObservation~new("azurefs:nvme0n2",1024*GB,900*GB))

video=.StorageObject~new(.StorageRef~new("sha256:video"),"video.mov",20*GB,"video/quicktime")
video~addLocation(.StorageLocation~new("oracle","/data/video.mov","nodefs:oracle-a",.StorageLocationState~AVAILABLE,"",.true,"sha256:video",.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE,"oracle-a"))
video~addLocation(.StorageLocation~new("google-drive","drive:video","gdrive:default",.StorageLocationState~AVAILABLE,"",.true,"sha256:video",.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE,""))
inputs=.array~new; inputs~append(video)
advisor=.StoragePlacementAdvisor~new
jobBytes=10*MB

/* Data already on Oracle A: move the tiny job, not 20 GiB of media. */
ea=advisor~assessCandidate("oracle-a",inputs,25*GB,jobBytes,5*GB,wm)
call assertTrue ea~feasible,"oracle A feasible"
call assertEq 20*GB,ea~localInputBytes,"oracle A local bytes"
call assertEq 0,ea~materializeBytes,"oracle A no input transfer"
call assertEq .StoragePlacementAction~JOB_TO_DATA,ea~action,"job-to-data classification"
call assertEq jobBytes,ea~movementBytes,"safe local workspace only moves job package"

/* Oracle B fits but needs the media copied. */
eb=advisor~assessCandidate("oracle-b",inputs,25*GB,jobBytes,5*GB,wm)
call assertTrue eb~feasible,"oracle B feasible"
call assertEq 20*GB,eb~materializeBytes,"oracle B materialises media"
call assertEq .StoragePlacementAction~DATA_TO_JOB,eb~action,"data-to-job classification"
call assertEq 20*GB+jobBytes,eb~movementBytes,"oracle B movement includes input"

/* The two 30 GiB Oracle pools must not masquerade as one 60 GiB pool. */
e40a=advisor~assessCandidate("oracle-a",inputs,40*GB,jobBytes,5*GB,wm)
e40b=advisor~assessCandidate("oracle-b",inputs,40*GB,jobBytes,5*GB,wm)
call assertFalse e40a~feasible,"40 GiB job does not fit Oracle A"
call assertFalse e40b~feasible,"40 GiB job does not fit Oracle B"

/* Azure can fit it, but output must leave disposable workspace before durable completion. */
eaz=advisor~assessCandidate("azure-test-us-east",inputs,40*GB,jobBytes,5*GB,wm)
call assertTrue eaz~feasible,"Azure large workspace feasible"
call assertEq 20*GB,eaz~materializeBytes,"Azure input materialisation"
call assertEq 5*GB,eaz~mandatoryOutputCommitBytes,"disposable output must be committed out"
call assertEq 25*GB+jobBytes,eaz~movementBytes,"Azure movement includes required durable output export"
call assertTrue eaz~pool~disposable,"Azure chosen pool is explicitly disposable"

say "PASS data-locality placement evidence / separate node capacity"
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
