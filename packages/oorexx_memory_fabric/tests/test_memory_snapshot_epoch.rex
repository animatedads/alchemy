numeric digits 20
call testMain
exit 0

testMain:
  memory=.BigMemory~new(8)
  runner=.MovableRunner~new(memory)

  a=.MemoryItem~new("A","alpha",4)
  b=.MemoryItem~new("B","bravo",4)
  c=.MemoryItem~new("C","charlie",4)

  addrA=runner~append(a)
  addrB=runner~append(b)
  call assert addrA<>.nil & addrB<>.nil, "initial placement"
  call assert memory~collectionEpoch=2, "epoch advances on assign"

  snap=memory~snapshot
  call assert snap~epoch=2, "snapshot records epoch"
  call assert snap~liveCount=2, "snapshot captures two live members"

  pulled=memory~pull(1)
  call assert pulled~id="A", "pull A"
  call assert memory~collectionEpoch=3, "epoch advances on pull"

  addrC=runner~append(c)
  call assert addrC<>.nil, "place C after snapshot"
  call assert memory~collectionEpoch=4, "epoch advances on extent reuse"
  call assert addrC~offset=addrA~offset, "spare extent reused"
  call assert addrC~generation<>addrA~generation, "reused offset has new generation"

  oldItems=memory~materializeAllAt(snap)
  call assert oldItems<>.nil, "materialize snapshot"
  call assert oldItems~items=2, "snapshot membership unchanged"
  call assert oldItems[1]~id="A", "snapshot retains pulled A"
  call assert oldItems[2]~id="B", "snapshot retains B"

  liveItems=memory~materializeAll
  call assert liveItems~items=2, "live collection has two members"
  call assert liveItems[1]~id="B", "live collection excludes A"
  call assert liveItems[2]~id="C", "live collection includes C"

  oldA=memory~containsParallelAt(snap,"alpha")
  call assert oldA~items=1, "snapshot scan still sees A"
  call assert oldA[1]~generation=addrA~generation, "snapshot preserves old generation"

  liveA=memory~containsParallel("alpha")
  call assert liveA~items=0, "live scan no longer sees A"
  liveC=memory~containsParallel("charlie")
  call assert liveC~items=1, "live scan sees C"
  call assert liveC[1]~generation=addrC~generation, "live scan sees new generation"

  results=memory~parallelMessageAt(snap,"LOCALMEASURE",.array~new)
  call assert results~items=2, "snapshot-local computation covers captured members"

  other=.BigMemory~new(8)
  call assert other~materializeAllAt(snap)=.nil, "foreign snapshot rejected"

  /* Stale physical address remains fenced even while snapshot retains the old item. */
  call assert memory~resolveAddress(addrA)=.nil, "stale physical address rejected after reuse"

  say "PASS memory.fabric object snapshot epoch"
  return

assert:
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  return

::requires "../src/MemoryFabricObjectMemory.cls"
