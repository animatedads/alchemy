/* Optional Memory Fabric integration for media-methodology work.
 *
 * Memory Fabric owns sparse backing, cursor state, horizon demands and data
 * movement.  This adapter creates/reference-maps media logical ranges and reads
 * demand evidence; it deliberately does not satisfy a horizon demand itself.
 */
::class MediaMethodologyMemoryFabricSession public
::method init
  expose workUnit sparseObject backingMap cursorId
  use strict arg workUnitArg, objectIdArg, objectEpochArg=1, backingRefArg=""
  if \workUnitArg~isA(.MediaWorkUnit) then raise syntax 93.900 array("MediaWorkUnit required")
  workUnit=workUnitArg
  sparseObject=.MemoryFabricSparseArray~new(objectIdArg,objectEpochArg)
  backingMap=.MemoryFabricSparseBackingMap~new(objectIdArg)
  if backingRefArg<>"" then backingMap~addExtent(workUnit~readFirst,workUnit~readLast,"REFERENCE",backingRefArg)
  cursorId="MEDIA:"||workUnit~workId
::attribute workUnit get
::attribute sparseObject get
::attribute backingMap get
::attribute cursorId get

::method open
  expose workUnit sparseObject cursorId
  use arg taskId="media-task", readerId="media-reader", horizonDistance=1, direction="FORWARD"
  c=sparseObject~openCursor(cursorId,taskId,readerId,workUnit~readFirst,workUnit~readFirst,workUnit~readLast,horizonDistance,direction)
  if c=.nil then return .nil
  sparseObject~armHorizonProjection
  return c

::method adaptHorizon
  expose sparseObject cursorId
  use strict arg consumptionRateItemsPerSecond, transferLatencyMilliseconds, safetyFactor=1.5, minimumDistance=1, maximumDistance=0
  return sparseObject~adaptCursorHorizon(cursorId,consumptionRateItemsPerSecond,transferLatencyMilliseconds,safetyFactor,minimumDistance,maximumDistance)

::method horizonThreshold
  expose sparseObject cursorId
  return sparseObject~cursorHorizonThreshold(cursorId)

::method observeRead
  expose sparseObject
  use strict arg logicalOrdinal
  return sparseObject~at(logicalOrdinal)

::method demands
  expose sparseObject
  return sparseObject~activeHorizonDemands

::method transferPlan
  expose backingMap workUnit
  return backingMap~transferPlan(workUnit~readFirst,workUnit~readLast)

::requires "MediaMethodologyExecution.cls"
::requires "MemoryFabricSparseArray.cls"
::requires "MemoryFabricSparseBacking.cls"
