/* AudioV9MemoryHorizonExecution.cls
 * Candidate20: adaptive Memory Fabric horizon -> fenced execution handoff.
 *
 * API: audio.v9.memory-horizon-execution/1
 *
 * This layer does not move audio.  It maps a Memory Fabric horizon demand to
 * an already-resident fenced block, requires external Job-to-Node placement
 * verification, then asks cluster.object.peer/0.2 to move the runner to the
 * provider that owns that block.
 *
 * Authority split:
 *   Audio V9       owns acoustic semantics and compact continuation state.
 *   Memory Fabric  owns horizon/demand state, block residency and fencing.
 *   Job-to-Node    owns placement/admission authority (supplied as guard).
 *   Queue Fabric   carries the runner/control envelope.
 *   Storage Fabric owns durable audio/material identity.
 */
::options numeric inherit

::class AudioV9MemoryHorizonBuild public
::constant VERSION "0.1-dev1"
::constant API "audio.v9.memory-horizon-execution/1"
::constant MEMORY_HORIZON_API "memory.fabric.horizon/0.1"
::constant ADAPTIVE_HORIZON_API "memory.fabric.adaptive-horizon/0.1"
::constant CLUSTER_OBJECT_API "cluster.object.peer/0.2"
::constant MEMORY_FABRIC_API "memory.fabric/0.1"

/* A read-only relation between one logical Audio range and one fenced Memory
 * Fabric block reference.  context normally carries the Audio V9
 * ClusterExecutionPlan for that block; it is not memory authority. */
::class AudioV9ResidentWindowRoute public
::method init
  expose logicalRange memoryRef context
  use strict arg logicalRangeArg,memoryRefArg,contextArg=.nil
  if logicalRangeArg==.nil then raise syntax 88.900 array("logical range is required")
  logicalRange=logicalRangeArg
  memoryRef=self~normaliseRef(memoryRefArg)
  if memoryRef==.nil then raise syntax 88.900 array("fenced memory reference is required")
  context=contextArg
::attribute logicalRange get
::attribute memoryRef get
::attribute context get

::method normaliseRef private
  use strict arg refArg
  if refArg==.nil then return .nil
  if refArg~isA(.Directory) then return refArg
  if refArg~hasMethod("ASDIRECTORY") then return refArg~asDirectory
  return .nil

::method exactRange
  expose logicalRange
  use strict arg requestedRange
  if requestedRange==.nil then return .false
  if logicalRange~first~compare(requestedRange~first)<>0 then return .false
  if logicalRange~last~compare(requestedRange~last)<>0 then return .false
  return .true

::method covers
  expose logicalRange
  use strict arg requestedRange
  if requestedRange==.nil then return .false
  if logicalRange~first~compare(requestedRange~first)>0 then return .false
  if logicalRange~last~compare(requestedRange~last)<0 then return .false
  return .true

/* A route after its Memory Fabric block/provider have been revalidated. */
::class AudioV9ResolvedResidentWindowRoute public
::method init
  expose route block provider destinationNode
  use strict arg routeArg,blockArg,providerArg,destinationArg
  route=routeArg; block=blockArg; provider=providerArg; destinationNode=destinationArg~string
::attribute route get
::attribute block get
::attribute provider get
::attribute destinationNode get
::attribute context get
  expose route
  return route~context

/* Read-only routing projection.  It never publishes/moves/frees a Memory
 * Fabric block.  Every resolve revalidates against current Memory Fabric
 * provider epoch + block generation. */
::class AudioV9ResidentWindowDirectory public
::method init
  expose fabricRegistry fabricId routes
  use strict arg registryArg,fabricIdArg
  fabricRegistry=registryArg; fabricId=fabricIdArg~string~strip
  if fabricRegistry==.nil | fabricId="" then raise syntax 88.900 array("Memory Fabric registry/fabric id required")
  routes=.array~new
::attribute fabricId get

::method publish
  expose routes
  use strict arg logicalRange,memoryRef,context=.nil
  route=.AudioV9ResidentWindowRoute~new(logicalRange,memoryRef,context)
  checked=self~validateRoute(route)
  if checked==.nil then return .nil
  routes~append(route)
  return route

::method publishPlan
  use strict arg logicalRange,plan
  if plan==.nil then return .nil
  return self~publish(logicalRange,plan~memoryRef,plan)

::method validateRoute private
  expose fabricRegistry fabricId
  use strict arg route
  d=route~memoryRef
  if d==.nil then return .nil
  if d["schema"]<>.AudioV9ExecutionContract~MEMORY_REF_SCHEMA then return .nil
  if d["fabric_id"]<>fabricId then return .nil
  block=fabricRegistry~resolveBlock(d["block_id"],d["generation"])
  if block==.nil then return .nil
  if block~providerId<>d["provider_id"] then return .nil
  if block~ownerEpoch<>d["owner_epoch"] then return .nil
  provider=fabricRegistry~provider(block~providerId)
  if provider==.nil then return .nil
  destination=provider~miId
  if destination="" then destination=provider~muId
  if destination="" then return .nil
  return .AudioV9ResolvedResidentWindowRoute~new(route,block,provider,destination)

::method resolve
  expose routes
  use strict arg requestedRange
  /* Prefer exact block/window identity. */
  do route over routes
    if route~exactRange(requestedRange) then do
      checked=self~validateRoute(route)
      if checked<>.nil then return checked
    end
  end
  /* A larger already-resident block may cover a smaller demand. */
  do route over routes
    if route~covers(requestedRange) then do
      checked=self~validateRoute(route)
      if checked<>.nil then return checked
    end
  end
  return .nil

::method count
  expose routes
  return routes~items

/* Result is intentionally compact. */
::class AudioV9HorizonMoveResult public
::method init
  expose ok code demandId destinationNode blockId generation detail
  use strict arg okArg,codeArg,demandArg="",destinationArg="",blockArg="",generationArg=0,detailArg=""
  ok=(okArg==.true); code=codeArg~string; demandId=demandArg~string
  destinationNode=destinationArg~string; blockId=blockArg~string
  generation=generationArg+0; detail=detailArg~string
::attribute ok get
::attribute code get
::attribute demandId get
::attribute destinationNode get
::attribute blockId get
::attribute generation get
::attribute detail get
::method success class
  use strict arg demandId,destinationNode,blockId,generation
  return self~new(.true,"OK",demandId,destinationNode,blockId,generation)
::method failure class
  use strict arg code,demandId="",detail=""
  return self~new(.false,code,demandId,"","",0,detail)

/* The placement guard must revalidate existing Job-to-Node authority.  It must
 * not manufacture a placement decision.  Contract:
 *   verify(plan, destinationNode, block, demand) -> .true/.false
 */
::class AudioV9MemoryHorizonCoordinator public
::method init
  expose sparseArray routes moveCoordinator placementGuard objectId fabricId
  use strict arg sparseArrayArg,routeDirectoryArg,moveCoordinatorArg,placementGuardArg,objectIdArg
  sparseArray=sparseArrayArg; routes=routeDirectoryArg; moveCoordinator=moveCoordinatorArg
  placementGuard=placementGuardArg; objectId=objectIdArg~string~strip
  if sparseArray==.nil | routes==.nil | moveCoordinator==.nil | placementGuard==.nil | objectId="" then
    raise syntax 88.900 array("horizon coordinator dependencies are required")
  fabricId=routes~fabricId

::method adaptCursor
  expose sparseArray
  use strict arg cursorId,itemsPerSecond,acquisitionLatencyMs,safetyFactor=1.5,minimumDistance=1,maximumDistance=0
  return sparseArray~adaptCursorHorizon(cursorId,itemsPerSecond,acquisitionLatencyMs,safetyFactor,minimumDistance,maximumDistance)

::method serviceNext
  expose sparseArray
  demands=sparseArray~activeHorizonDemands
  if demands~items=0 then return .AudioV9HorizonMoveResult~failure("NO_ACTIVE_DEMAND")
  return self~serviceDemand(demands[1])

::method serviceDemand
  expose sparseArray routes moveCoordinator placementGuard objectId fabricId
  use strict arg demand
  if demand==.nil then return .AudioV9HorizonMoveResult~failure("DEMAND_REQUIRED")
  if demand~state<>"TRIGGERED" then return .AudioV9HorizonMoveResult~failure("DEMAND_NOT_ACTIVE",demand~demandId)
  if demand~objectId<>sparseArray~objectId then return .AudioV9HorizonMoveResult~failure("DEMAND_OBJECT_MISMATCH",demand~demandId)
  if demand~objectEpoch<>sparseArray~objectEpoch then return .AudioV9HorizonMoveResult~failure("DEMAND_EPOCH_STALE",demand~demandId)

  route=routes~resolve(demand~requestedRange)
  if route==.nil then return .AudioV9HorizonMoveResult~failure("NEXT_WINDOW_NOT_RESIDENT",demand~demandId)

  plan=route~context
  if plan==.nil then return .AudioV9HorizonMoveResult~failure("EXECUTION_PLAN_REQUIRED",demand~demandId)
  if \self~planTargetsRoute(plan,route) then return .AudioV9HorizonMoveResult~failure("PLAN_MEMORY_REF_MISMATCH",demand~demandId)
  if \self~validateCursorTransitions(demand) then return .AudioV9HorizonMoveResult~failure("CURSOR_TRANSITION_INVALID",demand~demandId)

  verified=placementGuard~verify(plan,route~destinationNode,route~block,demand)
  if verified<>.true then return .AudioV9HorizonMoveResult~failure("PLACEMENT_NOT_VERIFIED",demand~demandId)

  moveOutcome=moveCoordinator~moveToBlock(objectId,route~destinationNode,route~block,fabricId)
  if moveOutcome==.nil then return .AudioV9HorizonMoveResult~failure("MOVE_FAILED",demand~demandId)
  if \moveOutcome~ok then return .AudioV9HorizonMoveResult~failure(moveOutcome~code,demand~demandId)

  if \self~advanceCursors(demand) then return .AudioV9HorizonMoveResult~failure("MOVED_CURSOR_STATE_FAILED",demand~demandId)
  if \sparseArray~satisfyHorizonDemand(demand~demandId) then return .AudioV9HorizonMoveResult~failure("MOVED_DEMAND_STATE_FAILED",demand~demandId)

  return .AudioV9HorizonMoveResult~success(demand~demandId,route~destinationNode,route~block~blockId,moveOutcome~generation)

::method planTargetsRoute private
  use strict arg plan,route
  ref=plan~memoryRef
  if ref==.nil then return .false
  d=ref~asDirectory
  if d["fabric_id"]<>route~route~memoryRef["fabric_id"] then return .false
  if d["block_id"]<>route~block~blockId then return .false
  if d["generation"]<>route~block~generation then return .false
  if d["provider_id"]<>route~block~providerId then return .false
  if d["owner_epoch"]<>route~block~ownerEpoch then return .false
  return .true

::method validateCursorTransitions private
  expose sparseArray
  use strict arg demand
  ids=demand~cursorIds
  if ids~items=0 then return .false
  requested=demand~requestedRange
  do id over ids
    c=sparseArray~cursor(id)
    if c==.nil then return .false
    if \c~active then return .false
    if c~objectId<>demand~objectId then return .false
    if c~objectEpoch<>demand~objectEpoch then return .false
    if demand~direction="FORWARD" then do
      if c~residentRange~last~successor~compare(requested~first)<>0 then return .false
    end
    else if demand~direction="BACKWARD" then do
      if c~residentRange~first~value="1" then return .false
      if c~residentRange~first~predecessor~compare(requested~last)<>0 then return .false
    end
    else return .false
  end
  return .true

/* After the runner is accepted beside the next block, advance the Memory
 * Fabric cursor without ever manufacturing a gap as resident.  A temporary
 * bridge contains both adjacent windows, position moves into the new block,
 * then the old block is dropped from this cursor's resident window. */
::method advanceCursors private
  expose sparseArray
  use strict arg demand
  requested=demand~requestedRange
  do id over demand~cursorIds
    c=sparseArray~cursor(id)
    if c==.nil then return .false
    old=c~residentRange
    if demand~direction="FORWARD" then do
      bridge=.MemoryFabricLogicalRange~new(old~first,requested~last)
      if \c~replaceWindow(bridge) then return .false
      if \c~moveTo(requested~first~value) then return .false
      if \c~replaceWindow(requested) then return .false
    end
    else do
      bridge=.MemoryFabricLogicalRange~new(requested~first,old~last)
      if \c~replaceWindow(bridge) then return .false
      if \c~moveTo(requested~last~value) then return .false
      if \c~replaceWindow(requested) then return .false
    end
  end
  return .true

::requires "AudioV9ExecutionIntegration.cls"
::requires "ClusterObjectMemoryFabricTransport.cls"
::requires "MemoryFabricSparseArray.cls"
