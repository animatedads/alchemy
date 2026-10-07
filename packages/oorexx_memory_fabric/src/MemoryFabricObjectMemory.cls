/* MemoryFabricObjectMemory.cls
 * ooRexx Memory Fabric v0.1-dev3
 *
 * Promoted from the earlier clustered big-memory proof.
 * Adds collection-epoch snapshots so parallel scans, local computation and
 * explicit materialisation have deterministic membership semantics while
 * placement/pull mutations continue concurrently.
 *
 * A snapshot freezes collection membership and address generations, not the
 * internal mutable state of arbitrary resident application objects.
 */

/* ====================================================================== */
::class MemoryItem public

::method init
    expose id value logicalBytes
    use arg id, value, logicalBytes

::attribute id get
::attribute value get
::attribute logicalBytes get

/* Test stand-in for an audio-local operation.  A real AudioChunk can expose
 * analyse(), FFT(), fingerprint(), etc.; BigMemory does not need to know the
 * operation's meaning.
 */
::method localMeasure
    expose value
    return value~length


/* ====================================================================== */
/* Immutable logical-to-physical address version. */
::class MemoryAddress public

::method init
    expose logicalIndex moduleId offset length generation itemId state
    use arg logicalIndex, moduleId, offset, length, generation, itemId, state

::attribute logicalIndex get
::attribute moduleId get
::attribute offset get
::attribute length get
::attribute generation get
::attribute itemId get
::attribute state get

::method asPulled
    expose logicalIndex moduleId offset length generation itemId
    return .MemoryAddress~new(logicalIndex, moduleId, offset, length, generation, itemId, 'PULLED')


/* ====================================================================== */
::class FreeExtent public

::method init
    expose offset length
    use arg offset, length

::attribute offset get
::attribute length get


/* ====================================================================== */
/* One allocation generation at one physical module offset. */
::class MemorySlot public

::method init
    expose logicalIndex offset length generation itemId item live
    use arg logicalIndex, offset, length, generation, itemId, item
    live = .true

::attribute logicalIndex get
::attribute offset get
::attribute length get
::attribute generation get
::attribute itemId get
::attribute live get

::method item
    expose item
    return item

::method pull
    expose item live
    if \live then return .nil
    answer = item
    item = .nil
    live = .false
    return answer


/* ====================================================================== */
::class MemoryMutation public

::method init
    expose kind logicalIndex moduleId offset length generation itemId
    use arg kind, logicalIndex, moduleId, offset, length, generation, itemId

::attribute kind get
::attribute logicalIndex get
::attribute moduleId get
::attribute offset get
::attribute length get
::attribute generation get
::attribute itemId get


/* ====================================================================== */
/* Lightweight result returned by a local parallel scan. */
::class MemoryHit public

::method init
    expose logicalIndex moduleId offset length generation itemId
    use arg logicalIndex, moduleId, offset, length, generation, itemId

::attribute logicalIndex get
::attribute moduleId get
::attribute offset get
::attribute length get
::attribute generation get
::attribute itemId get


/* ====================================================================== */
/* Used only during explicit materialisation. */
::class LocatedItem public

::method init
    expose logicalIndex item
    use arg logicalIndex, item

::attribute logicalIndex get
::attribute item get


/* ====================================================================== */
/* Compact result of a computation executed beside resident data. */
::class MemoryComputationResult public

::method init
    expose logicalIndex moduleId offset generation itemId result
    use arg logicalIndex, moduleId, offset, generation, itemId, result

::attribute logicalIndex get
::attribute moduleId get
::attribute offset get
::attribute generation get
::attribute itemId get
::attribute result get


/* ====================================================================== */
/* One immutable member captured at a collection epoch.  Holding the item
 * reference pins membership for the lifetime of the snapshot even if the
 * live collection subsequently pulls or reuses the physical extent. */
::class MemorySnapshotEntry public

::method init
    expose logicalIndex moduleId offset length generation itemId item
    use arg logicalIndex, moduleId, offset, length, generation, itemId, item

::attribute logicalIndex get
::attribute moduleId get
::attribute offset get
::attribute length get
::attribute generation get
::attribute itemId get

::method item
    expose item
    return item


/* Immutable collection-membership view.  The owner object is retained only
 * for foreign-snapshot rejection; it is not exposed as placement authority. */
::class MemoryCollectionSnapshot public

::method init
    expose owner epoch entries byModule logicalSize
    use arg owner, epoch, entries, byModule, logicalSize

::attribute epoch get
::attribute logicalSize get

::method belongsTo
    expose owner
    use arg candidate
    return owner == candidate

::method liveCount
    expose entries
    return entries~items

::method entries
    expose entries
    answer=.array~new
    do e over entries
        answer~append(e)
    end
    return answer

::method moduleIds
    expose byModule
    answer=.array~new
    do id over byModule
        answer~append(id)
    end
    return answer

::method entriesForModule
    expose byModule
    use arg moduleId
    source=byModule[moduleId]
    answer=.array~new
    if source == .nil then return answer
    do e over source
        answer~append(e)
    end
    return answer


/* Snapshot-local worker.  It has no ability to mutate the live module. */
::class MemorySnapshotModuleView public

::method init
    expose moduleId entries
    use arg moduleId, entries

::attribute moduleId get

::method scanContains unguarded
    expose entries moduleId
    use arg needle
    hits=.array~new
    do e over entries
        item=e~item
        if pos(needle,item~value)>0 then
            hits~append(.MemoryHit~new(e~logicalIndex,moduleId,e~offset,e~length,e~generation,e~itemId))
    end
    return hits

::method materialize unguarded
    expose entries
    answer=.array~new
    do e over entries
        answer~append(.LocatedItem~new(e~logicalIndex,e~item))
    end
    return answer

::method invoke unguarded
    expose entries moduleId
    use arg methodName, args
    if args == .nil then args=.array~new
    answer=.array~new
    do e over entries
        item=e~item
        callMessage=.message~new(item,methodName,'a',args)
        result=callMessage~send
        answer~append(.MemoryComputationResult~new(e~logicalIndex,moduleId,e~offset,e~generation,e~itemId,result))
    end
    return answer


/* ====================================================================== */
/* Represents one physical memory node/module. */
::class MemoryModule public

::method init
    expose id limit highWater liveBytes freeExtents slotHistory currentByOffset -
           nextGeneration directedReadCount
    use arg id, limit

    highWater = 0
    liveBytes = 0
    freeExtents = .array~new
    slotHistory = .array~new
    currentByOffset = .directory~new
    nextGeneration = 1
    directedReadCount = 0

::attribute id get
::attribute limit get
::attribute highWater get
::attribute liveBytes get
::attribute directedReadCount get

::method spareBytes
    expose freeExtents
    total = 0
    do extent over freeExtents
        total += extent~length
    end
    return total

::method spareExtentCount
    expose freeExtents
    return freeExtents~items

::method unassignedBytes
    expose limit highWater
    return limit - highWater

::method availableBytes
    return self~spareBytes + self~unassignedBytes

::method canFit
    expose limit highWater freeExtents
    use arg bytes

    do extent over freeExtents
        if extent~length >= bytes then return .true
    end

    return highWater + bytes <= limit

/* Allocate locally.  Existing assignments are never shifted.  A free extent
 * may be split, but surrounding live addresses remain unchanged.
 */
::method allocate
    expose id limit highWater liveBytes freeExtents slotHistory currentByOffset -
           nextGeneration
    use arg item, logicalIndex

    bytes = item~logicalBytes
    chosenOffset = -1
    chosenIndex = 0
    chosenLength = 0

    do i = 1 to freeExtents~items
        extent = freeExtents[i]
        if extent~length >= bytes then do
            chosenOffset = extent~offset
            chosenIndex = i
            chosenLength = extent~length
            leave
        end
    end

    if chosenIndex > 0 then do
        /* Array~delete() is intentional.  remove() would leave a sparse Array
         * and is the wrong operation for this queue-like extent list.
         */
        freeExtents~delete(chosenIndex)
        if chosenLength > bytes then
            freeExtents~append(.FreeExtent~new(chosenOffset + bytes, chosenLength - bytes))
    end
    else do
        if highWater + bytes > limit then return .nil
        chosenOffset = highWater
        highWater += bytes
    end

    generation = nextGeneration
    nextGeneration += 1

    slot = .MemorySlot~new(logicalIndex, chosenOffset, bytes, generation, item~id, item)
    slotHistory~append(slot)
    currentByOffset[chosenOffset] = slot
    liveBytes += bytes

    return .MemoryAddress~new(logicalIndex, id, chosenOffset, bytes, generation, item~id, 'LIVE')

/* A directed read.  The caller has already resolved this module from the
 * cluster directory, so no other module participates.
 */
::method getByAddress
    expose currentByOffset directedReadCount
    use arg address

    directedReadCount += 1
    slot = currentByOffset[address~offset]
    if slot == .nil then return .nil
    if \slot~live then return .nil
    if slot~generation <> address~generation then return .nil
    if slot~itemId <> address~itemId then return .nil
    return slot~item

::method pullByAddress
    expose currentByOffset liveBytes freeExtents
    use arg address

    slot = currentByOffset[address~offset]
    if slot == .nil then return .nil
    if \slot~live then return .nil
    if slot~generation <> address~generation then return .nil
    if slot~itemId <> address~itemId then return .nil

    answer = slot~pull
    if answer == .nil then return .nil

    liveBytes -= slot~length
    freeExtents~append(.FreeExtent~new(slot~offset, slot~length))
    return answer

/* Snapshot capture path: validate the exact address generation without
 * incrementing directed-read accounting.  The returned snapshot entry pins
 * the current item reference but cannot mutate the live slot. */
::method snapshotEntry
    expose id currentByOffset
    use arg address
    slot=currentByOffset[address~offset]
    if slot == .nil then return .nil
    if \slot~live then return .nil
    if slot~generation <> address~generation then return .nil
    if slot~itemId <> address~itemId then return .nil
    return .MemorySnapshotEntry~new(slot~logicalIndex,id,slot~offset,slot~length,slot~generation,slot~itemId,slot~item)

/* Current occupant at this physical offset, if any.  Used for diagnostics and
 * stale-generation tests.  No item payload is returned.
 */
::method addressAtOffset
    expose id currentByOffset
    use arg offset

    slot = currentByOffset[offset]
    if slot == .nil then return .nil

    state = 'PULLED'
    if slot~live then state = 'LIVE'

    return .MemoryAddress~new(slot~logicalIndex, id, slot~offset, slot~length, -
                              slot~generation, slot~itemId, state)

/* Module-local scan.  This method returns only references; item data stays
 * resident on the module.
 */
::method scanContains unguarded
    expose id slotHistory
    use arg needle

    hits = .array~new
    do slot over slotHistory
        if slot~live then do
            item = slot~item
            if pos(needle, item~value) > 0 then
                hits~append(.MemoryHit~new(slot~logicalIndex, id, slot~offset, -
                                           slot~length, slot~generation, slot~itemId))
        end
    end
    return hits

/* Explicit gather primitive.  Payloads cross the boundary only because the
 * caller asked to materialise all memory.
 */
::method materializeLive unguarded
    expose slotHistory

    answer = .array~new
    do slot over slotHistory
        if slot~live then
            answer~append(.LocatedItem~new(slot~logicalIndex, slot~item))
    end
    return answer

/* Execute one method against every live object while execution is beside this
 * module.  Only each method's result crosses back; the resident item itself
 * stays here.  Different modules run this method concurrently.
 */
::method invokeLive unguarded
    expose id slotHistory
    use arg methodName, args

    if args == .nil then args = .array~new
    answer = .array~new

    do slot over slotHistory
        if slot~live then do
            item = slot~item
            callMessage = .message~new(item, methodName, 'a', args)
            result = callMessage~send
            answer~append(.MemoryComputationResult~new(slot~logicalIndex, id, -
                          slot~offset, slot~generation, slot~itemId, result))
        end
    end

    return answer


/* ====================================================================== */
::class BigMemory public

::method init
    expose moduleLimit modules moduleById logicalDirectory mutations nextIndex -
           nextModuleNumber lastParallelScanModuleCount collectionEpoch
    use arg moduleLimit

    modules = .array~new
    moduleById = .directory~new
    logicalDirectory = .array~new
    mutations = .array~new
    nextIndex = 1
    nextModuleNumber = 1
    lastParallelScanModuleCount = 0
    collectionEpoch = 0

::attribute lastParallelScanModuleCount get
::attribute collectionEpoch get

::method newModule
    expose moduleLimit modules moduleById nextModuleNumber

    id = 'memory-' || nextModuleNumber
    nextModuleNumber += 1
    module = .MemoryModule~new(id, moduleLimit)
    modules~append(module)
    moduleById[id] = module
    return module

::method moduleCount
    expose modules
    return modules~items

::method nextLogicalIndex
    expose nextIndex
    return nextIndex

::method mutationCount
    expose mutations
    return mutations~items

::method liveCount
    expose logicalDirectory
    count = 0
    do address over logicalDirectory
        if address~state = 'LIVE' then count += 1
    end
    return count

::method totalSpareBytes
    expose modules
    total = 0
    do module over modules
        total += module~spareBytes
    end
    return total

/* Placement policy for the proof:
 *   1. stay beside current memory if it can fit;
 *   2. otherwise move execution to an existing module with spare/unused room;
 *   3. otherwise create a new module and move there.
 * Data is never moved merely to satisfy this allocation.
 */
::method selectModule
    expose modules
    use arg bytes, currentModule

    if currentModule \== .nil then
        if currentModule~canFit(bytes) then return currentModule

    do module over modules
        if currentModule \== .nil then
            if module~id = currentModule~id then iterate
        if module~canFit(bytes) then return module
    end

    return self~newModule

::method place
    expose logicalDirectory mutations nextIndex collectionEpoch
    use arg item, module

    address = module~allocate(item, nextIndex)
    if address == .nil then return .nil

    logicalDirectory~append(address)
    mutations~append(.MemoryMutation~new('ASSIGN', nextIndex, address~moduleId, -
                      address~offset, address~length, address~generation, address~itemId))
    nextIndex += 1
    collectionEpoch += 1
    return address

::method locate
    expose logicalDirectory
    use arg logicalIndex

    if logicalIndex < 1 | logicalIndex > logicalDirectory~items then return .nil
    return logicalDirectory[logicalIndex]

/* One logical address -> one module -> one reply. */
::method at
    expose moduleById
    use arg logicalIndex

    address = self~locate(logicalIndex)
    if address == .nil then return .nil
    if address~state <> 'LIVE' then return .nil

    module = moduleById[address~moduleId]
    if module == .nil then return .nil
    return module~getByAddress(address)

::method pull
    expose logicalDirectory moduleById mutations collectionEpoch
    use arg logicalIndex

    address = self~locate(logicalIndex)
    if address == .nil then return .nil
    if address~state <> 'LIVE' then return .nil

    module = moduleById[address~moduleId]
    if module == .nil then return .nil

    item = module~pullByAddress(address)
    if item == .nil then return .nil

    logicalDirectory[logicalIndex] = address~asPulled
    mutations~append(.MemoryMutation~new('PULL', logicalIndex, address~moduleId, -
                      address~offset, address~length, address~generation, address~itemId))
    collectionEpoch += 1
    return item

::method addressAtPhysical
    expose moduleById
    use arg moduleId, offset

    module = moduleById[moduleId]
    if module == .nil then return .nil
    return module~addressAtOffset(offset)

/* Resolve an already-held physical address.  A stale generation will fail
 * even if its old offset has since been reused by a different item.
 */
::method resolveAddress
    expose moduleById
    use arg address
    module = moduleById[address~moduleId]
    if module == .nil then return .nil
    return module~getByAddress(address)

::method totalDirectedReads
    expose modules
    total = 0
    do module over modules
        total += module~directedReadCount
    end
    return total

::method directedReadsFor
    expose moduleById
    use arg moduleId
    module = moduleById[moduleId]
    if module == .nil then return 0
    return module~directedReadCount

/* Capture one stable collection-membership epoch.  Capture is serialized by
 * the BigMemory object.  Later place/pull operations advance collectionEpoch
 * but do not alter this snapshot's membership or address generations. */
::method snapshot
    expose logicalDirectory moduleById collectionEpoch

    entries=.array~new
    byModule=.directory~new
    logicalSize=logicalDirectory~items

    do logicalIndex=1 to logicalSize
        address=logicalDirectory[logicalIndex]
        if address~state='LIVE' then do
            module=moduleById[address~moduleId]
            if module \== .nil then do
                entry=module~snapshotEntry(address)
                if entry \== .nil then do
                    entries~append(entry)
                    bucket=byModule[entry~moduleId]
                    if bucket == .nil then do
                        bucket=.array~new
                        byModule[entry~moduleId]=bucket
                    end
                    bucket~append(entry)
                end
            end
        end
    end

    return .MemoryCollectionSnapshot~new(self,collectionEpoch,entries,byModule,logicalSize)

::method requireSnapshot
    use arg snapshot
    if snapshot == .nil then return .false
    return snapshot~belongsTo(self)

/* Existing API: take a snapshot at method entry, then scan that immutable
 * membership view in parallel. */
::method containsParallel
    use arg needle
    return self~containsParallelAt(self~snapshot,needle)

::method containsParallelAt
    expose lastParallelScanModuleCount
    use arg snapshot, needle
    if \self~requireSnapshot(snapshot) then return .nil

    messages=.array~new
    moduleIds=snapshot~moduleIds
    lastParallelScanModuleCount=moduleIds~items

    do moduleId over moduleIds
        view=.MemorySnapshotModuleView~new(moduleId,snapshot~entriesForModule(moduleId))
        args=.array~of(needle)
        message=.message~new(view,'SCANCONTAINS','a',args)
        messages~append(message)
        message~start
    end

    hits=.array~new
    do message over messages
        localHits=message~result
        do hit over localHits
            hits~append(hit)
        end
    end
    return hits

/* Existing API: computation observes the collection membership present at
 * method entry. */
::method parallelMessage
    use arg methodName, args
    return self~parallelMessageAt(self~snapshot,methodName,args)

::method parallelMessageAt
    use arg snapshot, methodName, args
    if \self~requireSnapshot(snapshot) then return .nil
    if args == .nil then args=.array~new
    messages=.array~new

    do moduleId over snapshot~moduleIds
        view=.MemorySnapshotModuleView~new(moduleId,snapshot~entriesForModule(moduleId))
        invokeArgs=.array~of(methodName,args)
        message=.message~new(view,'INVOKE','a',invokeArgs)
        messages~append(message)
        message~start
    end

    results=.array~new
    do message over messages
        localResults=message~result
        do localResult over localResults
            results~append(localResult)
        end
    end
    return results

/* Existing API: explicit gather observes the collection membership present at
 * method entry. */
::method materializeAll
    return self~materializeAllAt(self~snapshot)

::method materializeAllAt
    use arg snapshot
    if \self~requireSnapshot(snapshot) then return .nil

    messages=.array~new
    do moduleId over snapshot~moduleIds
        view=.MemorySnapshotModuleView~new(moduleId,snapshot~entriesForModule(moduleId))
        message=.message~new(view,'MATERIALIZE')
        messages~append(message)
        message~start
    end

    byLogicalIndex=.directory~new
    do message over messages
        locatedItems=message~result
        do located over locatedItems
            byLogicalIndex[located~logicalIndex]=located~item
        end
    end

    allMemory=.array~new
    do e over snapshot~entries
        item=byLogicalIndex[e~logicalIndex]
        if item \== .nil then allMemory~append(item)
    end
    return allMemory

/* ====================================================================== */
::class MovableRunner public

::method init
    expose memory currentModule transposeCount
    use arg memory

    currentModule = .nil
    transposeCount = 0

::attribute transposeCount get

::method append
    expose memory currentModule transposeCount
    use arg item

    target = memory~selectModule(item~logicalBytes, currentModule)
    if target == .nil then return .nil

    if currentModule == .nil then do
        currentModule = target
        say 'RUNNER START ->' currentModule~id
    end
    else if currentModule~id <> target~id then do
        oldId = currentModule~id
        currentModule = target
        transposeCount += 1
        say 'TRANSPOSE' oldId '->' currentModule~id
    end

    return memory~place(item, currentModule)
