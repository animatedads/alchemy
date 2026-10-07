numeric digits 20
call testMain
exit 0

testMain:
  GB=1024*1024*1024
  registry=.MemoryFabricRegistry~new("memory:test")

  /* No single provider has 64 GiB.  Two same-site 32 GiB providers do. */
  registry~registerProvider(.MemoryFabricProvider~new("p-a","MI","MU-A","MI-MEM-A","site-1","host-a","queue://a",32*GB,0,"ACTIVE","ACCEPTING",1,1,"boot-a"))
  registry~registerProvider(.MemoryFabricProvider~new("p-b","MI","MU-B","MI-MEM-B","site-1","host-b","queue://b",32*GB,0,"ACTIVE","ACCEPTING",1,1,"boot-b"))
  registry~registerProvider(.MemoryFabricProvider~new("p-remote","MI","MU-C","MI-MEM-C","site-2","host-c","queue://c",128*GB,0,"ACTIVE","ACCEPTING",1,1,"boot-c"))

  planner=.MemoryFabricCapacityPlanner~new(registry)
  plan=planner~plan("MU-X","host-x","site-1",64*GB,.false,2,.MemoryFabricLocality~SAME_SITE)

  call assert plan~complete, "64 GiB plan completes"
  call assert plan~providerCount=2, "64 GiB is split across two providers"
  call assert plan~totalBytes=64*GB, "planned bytes exact"
  call assert plan~worstLocality=.MemoryFabricLocality~SAME_SITE, "same-site bound retained"

  tooSmall=planner~plan("MU-X","host-x","site-1",64*GB,.false,1,.MemoryFabricLocality~SAME_SITE)
  call assert \tooSmall~complete, "single-provider limit correctly cannot satisfy 64 GiB"

  say "PASS memory.fabric multi-provider capacity"
  return

assert:
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  return

::requires "../src/MemoryFabric.cls"
