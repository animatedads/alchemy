call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
r=.ComponentProjectionRegistry~new
c=.StorageCatalogue~new
obj=.StorageObject~new(.StorageRef~new("obj-1"),"one",12,"text/plain")
c~put(obj)
w=.StorageWorkspaceManager~new
p=.StoragePool~new("pool/1","local","/tmp/storage","domain1","WORKSPACE",0,"node1","local")
w~registerPool(p)
w~observeCapacity(.StorageCapacityObservation~new("domain1",100000,90000))
a1=w~allocate("pool/1",1000,"test-owner","alloc/1")
a=.StorageFabricComponentProjectionAdapter~new(r,c,w)
a~install
if r~readObject("/storage/catalogue/count")<>1 then call fail "actual catalogue count"
if r~readObject("/storage/workspace/allocation_count")<>1 then call fail "actual allocation count"
if r~readObject("/storage/workspace/allocations/alloc%2F1/reserved_bytes")<>1000 then call fail "actual reserved bytes"
if r~readObject("/storage/workspace/allocations/alloc%2F1/pool_id")<>"pool/1" then call fail "actual pool identity"
say "PASS Storage Fabric actual object projection adapter"
exit 0
fail: procedure; parse arg why; say "FAIL" why; exit 1
::requires "StorageFabric.cls"
::requires "ComponentProjection.cls"
::requires "ComponentProjectionStorageFabric.cls"
