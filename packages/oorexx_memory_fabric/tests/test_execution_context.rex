numeric digits 20
call testMain
exit 0

testMain:
  GB=1024*1024*1024

  registry=.MemoryFabricRegistry~new("memory:test")
  registry~registerProvider(.MemoryFabricProvider~new("mem-a","MI","MU-A","MI-MEM-A","site-1","host-a","queue://a",32*GB,0,"ACTIVE","ACCEPTING",1,1,"boot-a"))
  registry~registerProvider(.MemoryFabricProvider~new("mem-b","MI","MU-B","MI-MEM-B","site-1","host-b","queue://b",32*GB,0,"ACTIVE","ACCEPTING",1,1,"boot-b"))
  memPlanner=.MemoryFabricCapacityPlanner~new(registry)
  planner=.RegisteredJobExecutionContextPlanner~new(memPlanner)

  profiles=.array~new
  profiles~append(.RegisteredJobExecutionProfile~new("PREFERRED",64*GB,64*GB,2,.MemoryFabricLocality~SAME_SITE,3,100*1024*1024,.true))
  profiles~append(.RegisteredJobExecutionProfile~new("IDLE-DEGRADED",24*GB,32*GB,2,.MemoryFabricLocality~SAME_SITE,1,100*1024*1024,.true))

  candidates=.array~new
  storageA=.RegisteredJobStorageEvidence~new("node-a",.true,500,0,.true,0,"storage-evidence-a")
  candidates~append(.RegisteredJobNodeCandidate~new("node-a","MU-A","MI-WORK-A","host-a","site-1",.true,.true,1,0,"",storageA))

  planResult=planner~choose(profiles,candidates)
  call assert planResult~action=.RegisteredJobPlacementAction~RUN_EXISTING, "idle degraded profile used"
  call assert planResult~profile~profileId="IDLE-DEGRADED", "degraded profile explicit"

  /* When no idle node exists, a commissioned same-site context can span both
   * memory providers.  Job-to-Node hard eligibility remains an input. */
  candidates2=.array~new
  storageC=.RegisteredJobStorageEvidence~new("node-c",.true,0,1000,.true,5,"storage-evidence-c")
  candidates2~append(.RegisteredJobNodeCandidate~new("node-c","MU-X","MI-WORK-X","host-x","site-1",.true,.false,3,0.31,"offer-17",storageC))

  econ=.RegisteredJobEconomicPolicy~new(0.20,0.60,0,1000,2000,.true,.true,.true,24*GB,64*GB,1)
  forecast=.RegisteredJobPriceForecast~new(0.18,300,0.82,"price-model",100)

  planResult=planner~choose(profiles,candidates2,econ,100,forecast)
  call assert planResult~action=.RegisteredJobPlacementAction~ECONOMIC_HOLD, "commissioning can be economically held"

  planResult=planner~choose(profiles,candidates2,econ,1000,forecast)
  call assert planResult~action=.RegisteredJobPlacementAction~COMMISSION, "latest start releases hold"
  call assert planResult~memoryPlan~providerCount=2, "commissioned execution context uses two-provider memory plan"

  /* A node which Job-to-Node declares hard-ineligible is never rescued by
   * cheap memory/storage evidence. */
  bad=.array~new
  bad~append(.RegisteredJobNodeCandidate~new("bad-node","MU-X","MI-BAD","host-x","site-1",.false,.true,99,0,"",storageC))
  planResult=planner~choose(profiles,bad)
  call assert planResult~action=.RegisteredJobPlacementAction~NO_CONTEXT, "hard eligibility cannot be outweighed"

  say "PASS registered.job.execution-context/0.1"
  return

assert:
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  return

::requires "../src/MemoryFabric.cls"
::requires "../src/RegisteredJobEconomicHold.cls"
::requires "../src/RegisteredJobExecutionContext.cls"
