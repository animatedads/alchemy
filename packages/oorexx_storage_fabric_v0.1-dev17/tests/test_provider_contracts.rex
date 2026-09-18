GB=1024*1024*1024
p=.GoogleDriveStorageProvider~new("google-drive","user-store")
call assertTrue p~canCatalogue,"Drive catalogue"
call assertTrue p~canDurable,"Drive durable store"
call assertFalse p~canWorkspace,"Drive is not execution workspace"
call assertTrue p~requiresStreamingDataPlane,"large-object streaming is mandatory"
call assertEq "BOUNDED_MEMORY_STREAMING",p~dataPlaneRequirement,"streaming contract"

rp=.StoragePool~new("oracle-root","oracle-node","/var/tmp/storage-work","nodefs:oracle-root",.StoragePoolMode~WORKSPACE,2*GB,"oracle-1","UK-LONDON-1")
r=.RemoteNodeStorageProvider~new("oracle-node","oracle-1",rp)
call assertFalse r~ownsTransport,"Storage must not own SSH/remote execution"
say "PASS provider contracts"
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