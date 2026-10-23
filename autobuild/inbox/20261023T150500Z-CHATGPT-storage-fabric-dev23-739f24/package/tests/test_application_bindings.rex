refVideo=.StorageRef~new('obj:video','sha256:video')
refAudio=.StorageRef~new('obj:audio','sha256:audio')

pinVideo=.StoragePinnedRef~new(refVideo,'471','','/human/road-camera.mp4')
pinAudio=.StoragePinnedRef~new(refAudio,'471','','/human/door-camera.wav')

set=.StorageRefSet~new('scene-42','471')
set~add('roadVideo',pinVideo)~add('doorAudio',pinAudio)~seal
call assertEq 2,set~count,'set member count'
call assertTrue set~identityManifest~pos('/human/')=0,'paths excluded from durable set identity'

/* Same durable set, different nodes and entirely different local paths. */
a=.FakeMaterialiser~new('/srv/space/materialised')
b=.FakeMaterialiser~new('/var/lib/storage-fabric/work')

bindA=.StorageJobBinding~new('audio-job-9','ed209a',set)~bind(a)
bindC=.StorageJobBinding~new('audio-job-9','ed209c',set)~bind(b)
call assertEq '/srv/space/materialised/obj_video',bindA~localPath('roadVideo'),'node A transient path'
call assertEq '/var/lib/storage-fabric/work/obj_video',bindC~localPath('roadVideo'),'node C transient path'
call assertEq bindA~lease('roadVideo')~identityKey,bindC~lease('roadVideo')~identityKey,'path changes do not change input identity'
call assertEq pinVideo~identityKey,bindA~lease('roadVideo')~identityKey,'lease preserves pin'

/* Discovery aliases may move without changing the durable pin. */
pinMoved=.StoragePinnedRef~new(refVideo,'471','','/somewhere/completely/different.mp4')
call assertTrue pinVideo~sameIdentity(pinMoved),'namespace path is not authority'

/* Friendly paths resolve once to a pin; later retargeting cannot mutate it. */
cat=.StorageCatalogue~new
refPath1=.StorageRef~new('obj:path-v1','sha256:path-v1')
refPath2=.StorageRef~new('obj:path-v2','sha256:path-v2')
cat~put(.StorageObject~new(refPath1,'camera.mp4',123,'video/mp4'))
cat~put(.StorageObject~new(refPath2,'camera.mp4',124,'video/mp4'))
env=.StorageEnvironment~new('LIVE',.StorageEnvironmentKind~LIVE,'',0,77)
ns=.StorageNamespace~new('live',cat,env)
ns~bind('/scene/camera',refPath1,.StorageWritePolicy~READ_ONLY)
resolver=.StorageNamespacePinResolver~new
pathPin=resolver~pin(ns,'/scene/camera')
call assertEq 'obj:path-v1',pathPin~ref~objectId,'friendly path resolves to exact object'
call assertEq '77',pathPin~generation~string,'namespace generation pinned'
ns~bind('/scene/camera',refPath2,.StorageWritePolicy~READ_ONLY)
call assertEq 'obj:path-v1',pathPin~ref~objectId,'later namespace retarget does not alter submitted pin'
rolePaths=.array~of(.StorageRolePath~new('camera','/scene/camera'))
pathSet=resolver~pinSet(ns,'scene-path-set',rolePaths)
call assertEq 'obj:path-v2',pathSet~member('camera')~ref~objectId,'new submission sees current namespace target'

/* Frozen input membership cannot be changed after submission. */
failed=.false
signal on syntax name SetMutationFailed
set~add('lateInput',.StoragePinnedRef~new(.StorageRef~new('obj:late'),'471'))
signal off syntax
signal ContinueSetTest
SetMutationFailed:
  failed=.true
  signal off syntax
ContinueSetTest:
call assertTrue failed,'sealed set rejects late member'

/* Output is reserved by requirement; its workspace path is also transient. */
wm=.StorageWorkspaceManager~new
pool=.StoragePool~new('a-work','local','/scratch/a','domain-a',.StoragePoolMode~WORKSPACE,0,'ed209a')
wm~registerPool(pool)
wm~observeCapacity(.StorageCapacityObservation~new('domain-a',1000000,900000))
intent=.StorageOutputIntent~new('alignedAudio','audio/wav',100000,1)
out=.StorageOutputAllocator~new~reserve(wm,'ed209a',intent,'audio-job-9','out-1')
call assertTrue out<>.nil,'output workspace allocated'
call assertEq '/scratch/a/workspaces/out-1/alignedAudio',out~localPath,'output local path generated from lease'
call assertTrue out~markWriting,'output enters writing state'

failed=.false
signal on syntax name EarlyCommitFailed
out~commit(.StorageRef~new('obj:result','sha256:result'),0)
signal off syntax
signal ContinueCommitTest
EarlyCommitFailed:
  failed=.true
  signal off syntax
ContinueCommitTest:
call assertTrue failed,'unsafe result cannot satisfy durable output intent'
result=out~commit(.StorageRef~new('obj:result','sha256:result'),1)
call assertEq 'obj:result',result~objectId,'durable result is StorageRef'
call assertEq .StorageOutputState~COMMITTED,out~state,'output committed'
call assertTrue out~release,'output lease release'
call assertEq 0,wm~reservedForDomain('domain-a'),'output release restores workspace reservation'

call assertTrue bindA~release,'binding release'
call assertEq .StorageBindingState~RELEASED,bindA~lease('roadVideo')~state,'lease released'
call assertEq 'obj:video|g=471|digest=sha256:video',pinVideo~identityKey,'release does not alter durable identity'

say 'PASS application StorageRef sets/materialisation leases/output intents'
exit 0

::class FakeMaterialiser subclass StorageMaterialisationAuthority
::method init
  expose root
  use arg rootArg
  root=rootArg~string
::method materialisePinned
  expose root
  use arg pin,node,access,leaseId
  name=changestr(':',pin~ref~objectId,'_')
  return .StorageMaterialisationLease~new(leaseId,pin,node,root||'/'||name,pin~digest,access,'fake:test')

::routine assertTrue
  use arg v,l
  if \v then do; say 'FAIL' l; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg e,a,l
  if e<>a then do; say 'FAIL' l 'expected='e 'actual='a; raise syntax 88.900 array('test assertion failed'); end

::requires "src/StorageFabric.cls"
::requires "src/StorageBinding.cls"
