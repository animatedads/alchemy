numeric digits 20
call testMain
exit 0

testMain:
  registry=.MemoryFabricRegistry~new("memory:test")

  mu=.MemoryFabricProvider~new("provider-mu-a","MU","MU-A","", "site-1","machine-a","local://mu-a", 1024,0,"ACTIVE","ACCEPTING",1,1,"boot-a")
  mi=.MemoryFabricProvider~new("provider-mi-b","MI","MU-B","MI-MEM-B","site-1","machine-b","queue://mi-mem-b",2048,0,"SPARE","RESERVED",1,1,"boot-b")

  call assert registry~registerProvider(mu), "register MU provider"
  call assert registry~registerProvider(mi), "register MI provider"

  binding=registry~bindMU("MU-A","provider-mu-a","local://mu-a",1)
  call assert binding<>.nil, "bind MU-A"
  discovered=registry~discoverForMU("MU-A")
  call assert discovered<>.nil, "discover MU-A"
  call assert discovered["provider_kind"]="MU", "MU can provide fabric"

  /* Rebind another MU to an MI-hosted provider. */
  bindingB=registry~bindMU("MU-B","provider-mi-b","queue://mi-mem-b",1)
  call assert bindingB<>.nil, "bind MU-B to MI provider"
  discoveredB=registry~discoverForMU("MU-B")
  call assert discoveredB["provider_kind"]="MI", "MI can provide fabric"
  call assert discoveredB["provider_mi"]="MI-MEM-B", "MI identity retained"

  /* General allocation avoids SPARE; explicit spare use allows it. */
  best=registry~bestProvider("MU-X","machine-x","site-1",512,.false)
  call assert best~providerId="provider-mu-a", "active provider selected"
  bestSpare=registry~bestProvider("MU-X","machine-x","site-1",1500,.true)
  call assert bestSpare~providerId="provider-mi-b", "spare usable when explicitly allowed"

  block=.MemoryFabricBlockRef~new("block-1",1,"provider-mu-a",0,256,"RECONSTRUCTABLE","storage:checkpoint:7",1)
  call assert registry~publishBlock(block), "publish block"
  call assert registry~resolveBlock("block-1",1)<>.nil, "resolve current block generation"
  call assert registry~resolveBlock("block-1",2)=.nil, "reject wrong block generation"

  /* Old provider epoch cannot replace a newer one. */
  newer=.MemoryFabricProvider~new("provider-mu-a","MU","MU-A","", "site-1","machine-a","local://mu-a",1024,0,"ACTIVE","ACCEPTING",2,1,"boot-a2")
  call assert registry~registerProvider(newer), "advance provider epoch"
  stale=.MemoryFabricProvider~new("provider-mu-a","MU","MU-A","", "site-1","machine-a","local://mu-a",1024,0,"ACTIVE","ACCEPTING",1,99,"boot-old")
  call assert \registry~registerProvider(stale), "reject stale provider epoch"
  call assert registry~resolveBlock("block-1",1)=.nil, "old block fenced by owner epoch"

  say "PASS memory.fabric/0.1"
  return

assert:
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  return

::requires "../src/MemoryFabric.cls"
