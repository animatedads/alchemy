/* Demonstrate that one durable media job binds to different node-local paths. */
video=.StoragePinnedRef~new(.StorageRef~new('object:road-video','sha256:road'),'471','','/evidence/road/tp00025')
audio=.StoragePinnedRef~new(.StorageRef~new('object:door-audio','sha256:door'),'471','','/evidence/door/tp00026')
inputs=.StorageRefSet~new('scene:471','471')
inputs~add('roadVideo',video)~add('doorAudio',audio)~seal

a=.ExampleMaterialiser~new('/srv/space/job-materialised')
c=.ExampleMaterialiser~new('/var/lib/storage-fabric/job-materialised')
jobA=.StorageJobBinding~new('alignment-1','ed209a',inputs)~bind(a)
jobC=.StorageJobBinding~new('alignment-1','ed209c',inputs)~bind(c)

say 'durable identity:' video~identityKey
say 'ed209a path:' jobA~localPath('roadVideo')
say 'ed209c path:' jobC~localPath('roadVideo')

::class ExampleMaterialiser subclass StorageMaterialisationAuthority
::method init
  expose root
  use arg r
  root=r
::method materialisePinned
  expose root
  use arg pin,node,access,leaseId
  n=changestr(':',pin~ref~objectId,'_')
  return .StorageMaterialisationLease~new(leaseId,pin,node,root||'/'||n,pin~digest,access,'example')

::requires "src/StorageFabric.cls"
::requires "src/StorageBinding.cls"
