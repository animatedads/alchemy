call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
r=.ComponentProjectionRegistry~new
c=.FakeCatalogue~new
w=.FakeWorkspace~new
w~add(.FakeAllocation~new("a/1","ACTIVE",1024,"job","/tmp/a", "pool0"))
a=.StorageFabricComponentProjectionAdapter~new(r,c,w)
a~install
call assertEq 2,r~readObject("/storage/catalogue/count"),"catalogue count"
call assertEq 1,r~readObject("/storage/workspace/allocation_count"),"alloc count"
call assertEq 1024,r~readObject("/storage/workspace/allocations/a%2F1/reserved_bytes"),"bytes"
call assertTrue r~endpoint("/storage/workspace/allocations/a%2F1/state")~writable=.false,"read-only self observation"
say "PASS Storage Fabric component projection adapter"
exit 0
assertEq: procedure; use arg e,g,m; if e<>g then do; say "FAIL" m e g; exit 1; end; return
assertTrue: procedure; use arg v,m; if \v then do; say "FAIL" m; exit 1; end; return
::class FakeCatalogue
::method count; return 2
::method all; return .array~of("a","b")
::class FakePool
::attribute poolId get
::method init; expose poolId; use arg poolId
::class FakeAllocation
::attribute allocationId get; ::attribute state get; ::attribute reservedBytes get; ::attribute owner get; ::attribute locator get; ::attribute pool get
::method init
  expose allocationId state reservedBytes owner locator pool
  use arg i,s,b,o,l,p
  allocationId=i; state=s; reservedBytes=b; owner=o; locator=l; pool=.FakePool~new(p)
::class FakeWorkspace
::method init; expose a; a=.array~new
::method add; expose a; use arg x; a~append(x)
::method allocations; expose a; return a
::requires "ComponentProjectionStorageFabric.cls"
