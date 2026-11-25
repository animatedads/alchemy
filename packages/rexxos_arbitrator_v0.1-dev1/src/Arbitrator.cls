/* rexxos_arbitrator v0.1-dev1
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).

   A machine does not run provisioning scripts.  It holds demands, and a
   MachineArbitrator - the one authority over that machine's resources -
   turns the demands and the machine's state into a ProvisionPlan: the
   ordered steps that reach the target state.  The plan is data.  Each step
   names the demand it serves, its inverse and whether it changes the
   machine (then it needs approval).  The plan is simulated step by step
   against a copy of the state and refused if any step breaks an invariant.

   The arbitrator never moves a task itself: it asks the cluster
   (ASK_CLUSTER) for cross-arbitration and re-plans when the answer arrives
   as an event.  A cache's mode is decided per request (Demand cacheMode).

   Units are MiB and seconds.  dev1 is the planner only; nothing here
   touches a real machine. */

/* ------------------------------------------------------------------ */
::class Demand public
::method init
  expose id priority ramMiB pageableMiB storageMiB storageWhere wantsRamSpeed durability cacheMode
  use strict arg id, priority, ramMiB = 0, pageableMiB = 0, storageMiB = 0, storageWhere = 'NONE', wantsRamSpeed = .false, durability = 'DURABLE', cacheMode = ''
  if \id~isA(.String) | id~length < 1 | id~length > 64 | id~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.') > 0 then
    raise syntax 93.900 array ('Demand id must be 1-64 characters of A-Z a-z 0-9 - _ .')
  do v over .Array~of(priority, ramMiB, pageableMiB, storageMiB)
    if \v~datatype('W') then raise syntax 93.900 array ('Demand' id': numbers must be whole')
    if v < 0 then raise syntax 93.900 array ('Demand' id': numbers must not be negative')
  end
  if pageableMiB > ramMiB then raise syntax 93.900 array ('Demand' id': pageable RAM exceeds RAM')
  storageWhere = storageWhere~upper
  if wordpos(storageWhere, 'NONE LOCAL FABRIC') = 0 then raise syntax 93.900 array ('Demand' id': storage must be NONE, LOCAL or FABRIC')
  if (storageWhere == 'NONE') \== (storageMiB = 0) then raise syntax 93.900 array ('Demand' id': storage size and place disagree')
  durability = durability~upper
  if wordpos(durability, 'READONLY TEMPORARY DURABLE') = 0 then raise syntax 93.900 array ('Demand' id': durability must be READONLY, TEMPORARY or DURABLE')
  if \wantsRamSpeed~isA(.String) | wordpos(wantsRamSpeed, '0 1') = 0 then raise syntax 93.900 array ('Demand' id': wantsRamSpeed must be .true or .false')
  if wantsRamSpeed & storageMiB = 0 then raise syntax 93.900 array ('Demand' id': RAM speed asked for with no storage')
  /* Case by case: the request may name its cache mode, else its durability decides. */
  cacheMode = cacheMode~upper
  if cacheMode == '' then select
    when durability == 'READONLY'  then cacheMode = 'READONLY'
    when durability == 'TEMPORARY' then cacheMode = 'WRITEBACK'
    otherwise cacheMode = 'WRITETHROUGH'
  end
  if wordpos(cacheMode, 'READONLY WRITEBACK WRITETHROUGH') = 0 then raise syntax 93.900 array ('Demand' id': cache mode must be READONLY, WRITEBACK or WRITETHROUGH')
  if cacheMode == 'READONLY' & durability \== 'READONLY' then raise syntax 93.900 array ('Demand' id': a READONLY cache needs READONLY data')
  if cacheMode == 'WRITEBACK' & durability == 'DURABLE' then raise syntax 93.900 array ('Demand' id': DURABLE data may not use a WRITEBACK cache')
::attribute id get
::attribute priority get
::attribute ramMiB get
::attribute pageableMiB get
::attribute storageMiB get
::attribute storageWhere get
::attribute wantsRamSpeed get
::attribute durability get
::attribute cacheMode get
::method residentMiB
  expose ramMiB pageableMiB
  return ramMiB - pageableMiB
::method string
  expose id
  return 'Demand' id

/* ------------------------------------------------------------------ */
/* What the machine has and what it is doing.  Free space excludes what
   running tasks and the swap file already hold. */
::class MachineState public
::method init
  expose ramTotalMiB baseMiB diskFreeMiB fabricFreeMiB swapMiB swapSince running caches
  use strict arg ramTotalMiB, baseMiB, diskFreeMiB, fabricFreeMiB = 0
  do v over .Array~of(ramTotalMiB, baseMiB, diskFreeMiB, fabricFreeMiB)
    if \v~datatype('W') then raise syntax 93.900 array ('Machine sizes must be whole MiB')
    if v < 0 then raise syntax 93.900 array ('Machine sizes must not be negative')
  end
  if baseMiB >= ramTotalMiB then raise syntax 93.900 array ('Base use leaves no RAM')
  swapMiB = 0; swapSince = 0
  running = .Directory~new     /* id -> Demand */
  caches = .Directory~new      /* id -> Directory SIZE MODE SINCE */
::attribute ramTotalMiB get
::attribute baseMiB get
::attribute diskFreeMiB get
::attribute fabricFreeMiB get
::attribute swapMiB get
::attribute swapSince get
::method running
  expose running
  return running
::method caches
  expose caches
  return caches
::method ramBudget
  expose ramTotalMiB baseMiB
  return ramTotalMiB - baseMiB
::method copy
  expose ramTotalMiB baseMiB diskFreeMiB fabricFreeMiB swapMiB swapSince running caches
  c = .MachineState~new(ramTotalMiB, baseMiB, diskFreeMiB, fabricFreeMiB)
  c~restore(swapMiB, swapSince, running, caches)
  return c
/* For copy only. */
::method restore
  expose swapMiB swapSince running caches
  use strict arg swapMiB, swapSince, r, k
  running = r~copy
  caches = .Directory~new
  do id over k~allIndexes; caches[id] = k[id]~copy; end
::method residentInUse
  expose running caches
  n = 0
  do d over running~allItems; n += d~residentMiB; end
  do c over caches~allItems; n += c['SIZE']; end
  return n
::method pageableInUse
  expose running
  n = 0
  do d over running~allItems; n += d~pageableMiB; end
  return n
/* Every rule the machine must keep at every step of a plan. */
::method violations
  expose diskFreeMiB fabricFreeMiB swapMiB
  v = .Array~new
  if self~residentInUse > self~ramBudget then
    v~append('resident RAM' self~residentInUse 'MiB is over the' self~ramBudget 'MiB budget')
  if self~residentInUse + self~pageableInUse > self~ramBudget + swapMiB then
    v~append('RAM plus pageable' self~residentInUse + self~pageableInUse 'MiB is over RAM plus swap' self~ramBudget + swapMiB 'MiB')
  if diskFreeMiB < 0 then v~append('local disk overcommitted by' (-diskFreeMiB) 'MiB')
  if fabricFreeMiB < 0 then v~append('fabric overcommitted by' (-fabricFreeMiB) 'MiB')
  return v
/* Apply one step to this state (used for simulation and for the
   recorded state after a real step completes). */
::method apply
  expose diskFreeMiB fabricFreeMiB swapMiB swapSince running caches
  use strict arg step, now = 0
  d = step~demand
  select
    when step~kind == 'START_TASK' then do
      if running~hasIndex(d~id) then raise syntax 93.900 array ('Task' d~id 'is already running')
      running[d~id] = d
      if d~storageWhere == 'LOCAL'  then diskFreeMiB -= d~storageMiB
      if d~storageWhere == 'FABRIC' then fabricFreeMiB -= d~storageMiB
    end
    when step~kind == 'STOP_TASK' then do
      if \running~hasIndex(d~id) then raise syntax 93.900 array ('Task' d~id 'is not running')
      running~remove(d~id)
      if d~storageWhere == 'LOCAL'  then diskFreeMiB += d~storageMiB
      if d~storageWhere == 'FABRIC' then fabricFreeMiB += d~storageMiB
    end
    when step~kind == 'ADD_SWAP' then do
      if swapMiB = 0 then swapSince = now
      swapMiB += step~sizeMiB; diskFreeMiB -= step~sizeMiB
    end
    when step~kind == 'REMOVE_SWAP' then do
      diskFreeMiB += swapMiB; swapMiB = 0; swapSince = 0
    end
    when step~kind == 'ADD_CACHE' then do
      if caches~hasIndex(d~id) then raise syntax 93.900 array ('Cache for' d~id 'already exists')
      c = .Directory~new; c['SIZE'] = step~sizeMiB; c['MODE'] = step~mode; c['SINCE'] = now; c['DIRTY'] = .false
      caches[d~id] = c
    end
    when step~kind == 'FLUSH_CACHE' then do
      if \caches~hasIndex(d~id) then raise syntax 93.900 array ('No cache for' d~id)
      caches[d~id]['DIRTY'] = .false
    end
    when step~kind == 'DROP_CACHE' then do
      if \caches~hasIndex(d~id) then raise syntax 93.900 array ('No cache for' d~id)
      if caches[d~id]['DIRTY'] then raise syntax 93.900 array ('Cache for' d~id 'dropped while dirty')
      caches~remove(d~id)
    end
    when step~kind == 'ASK_CLUSTER' then nop
    otherwise raise syntax 93.900 array ('Unknown step' step~kind)
  end
  return self
/* A write-back cache holds writes the drive does not have yet. */
::method markDirty
  expose caches
  use strict arg id
  if caches~hasIndex(id) then if caches[id]['MODE'] == 'WRITEBACK' then caches[id]['DIRTY'] = .true
  return self

/* ------------------------------------------------------------------ */
::class ProvisionStep public
::method init
  expose kind demand sizeMiB mode cause status note
  use strict arg kind, demand, cause, sizeMiB = 0, mode = '', status = 'PLANNED', note = ''
  if wordpos(kind, .ProvisionStep~kinds) = 0 then raise syntax 93.900 array ('Unknown step kind' kind)
  if wordpos(status, 'PLANNED DEFERRED WAITING') = 0 then raise syntax 93.900 array ('Unknown step status' status)
::method kinds class
  return 'STOP_TASK FLUSH_CACHE DROP_CACHE ADD_SWAP START_TASK REMOVE_SWAP ADD_CACHE ASK_CLUSTER'
::attribute kind get
::attribute demand get
::attribute sizeMiB get
::attribute mode get
::attribute cause get
::attribute status get
::attribute note get
::method inverse
  expose kind
  select
    when kind == 'START_TASK'  then return 'STOP_TASK'
    when kind == 'STOP_TASK'   then return 'START_TASK'
    when kind == 'ADD_SWAP'    then return 'REMOVE_SWAP'
    when kind == 'REMOVE_SWAP' then return 'ADD_SWAP'
    when kind == 'ADD_CACHE'   then return 'DROP_CACHE'
    when kind == 'DROP_CACHE'  then return 'ADD_CACHE'
    otherwise return ''
  end
/* Everything but a question to the cluster changes the machine. */
::method changesMachine
  expose kind
  return kind \== 'ASK_CLUSTER'
/* What the step does, in the order it is done. */
::method actions
  expose kind demand sizeMiB mode
  select
    when kind == 'ADD_CACHE' & mode == 'READONLY' then
      return .Array~of('make a RAM store of' sizeMiB 'MiB', 'copy' demand~id 'from its drive', 'verify the copy against its digest', 'switch' demand~id"'s root to the RAM store")
    when kind == 'ADD_CACHE' then
      return .Array~of('make a RAM store of' sizeMiB 'MiB', 'attach it in front of' demand~id"'s drive as a" mode~lower 'cache')
    when kind == 'DROP_CACHE' & mode == 'READONLY' then
      return .Array~of('switch' demand~id"'s root back to its drive", 'release the RAM store')
    when kind == 'DROP_CACHE' then
      return .Array~of('detach the cache from' demand~id"'s drive", 'release the RAM store')
    when kind == 'FLUSH_CACHE' then
      return .Array~of('write' demand~id"'s cached writes to its drive", 'confirm the drive holds them')
    when kind == 'ADD_SWAP' then
      return .Array~of('make a swap file of' sizeMiB 'MiB on local disk', 'enable it')
    when kind == 'REMOVE_SWAP' then
      return .Array~of('bring swapped pages back into RAM', 'disable and delete the swap file')
    when kind == 'START_TASK' then return .Array~of('start' demand~id)
    when kind == 'STOP_TASK'  then return .Array~of('stop' demand~id)
    otherwise return .Array~of('ask the cluster:' self~note)
  end
::method string
  expose kind demand sizeMiB mode status
  s = kind
  if demand \== .nil then s = s demand~id
  if sizeMiB > 0 then s = s sizeMiB'MiB'
  if mode \== '' then s = s mode
  if status \== 'PLANNED' then s = s '('status')'
  return s

/* ------------------------------------------------------------------ */
::class ProvisionPlan public
::method init
  expose steps violations
  steps = .Array~new; violations = .Array~new
::method add
  expose steps
  use strict arg step
  steps~append(step)
  return step
::method steps
  expose steps
  return steps
::method planned
  expose steps
  r = .Array~new
  do s over steps; if s~status == 'PLANNED' then r~append(s); end
  return r
::method kinds
  /* The planned steps as one line of words, for tests and logs. */
  r = ''
  do s over self~planned; r = r s~kind; end
  return r~strip
::method violations
  expose violations
  return violations
::method noteViolation
  expose violations
  use strict arg text
  violations~append(text)
::method ok
  expose violations
  return violations~items = 0
::method needsApproval
  do s over self~planned; if s~changesMachine then return .true; end
  return .false
::method describe
  expose steps violations
  lines = .Array~new
  n = 0
  do s over steps
    n += 1
    flag = ''
    if s~status == 'PLANNED' & s~changesMachine then flag = '  NEEDS TOM''S DIRECT APPROVAL'
    lines~append(right(n, 2)'.' s~string flag)
    lines~append('    why:' s~cause)
    if s~note \== '' & s~kind \== 'ASK_CLUSTER' then lines~append('    note:' s~note)
    do a over s~actions; lines~append('    -' a); end
    if s~inverse \== '' then lines~append('    undo:' s~inverse)
  end
  if steps~items = 0 then lines~append('No steps: the machine is already in the target state.')
  do v over violations; lines~append('REFUSED:' v); end
  return lines

/* ------------------------------------------------------------------ */
::class MachineArbitrator public
::method init
  expose state headroomPct dwellSec swapMarginPct minCacheMiB
  use strict arg state, headroomPct = 15, dwellSec = 600, swapMarginPct = 10, minCacheMiB = 256
  if \state~isA(.MachineState) then raise syntax 93.900 array ('MachineState required')
  do v over .Array~of(headroomPct, dwellSec, swapMarginPct, minCacheMiB)
    if \v~datatype('W') then raise syntax 93.900 array ('Arbitrator settings must be whole numbers')
    if v < 0 then raise syntax 93.900 array ('Arbitrator settings must not be negative')
  end
::attribute state get
/* Record that a step has been carried out on the real machine. */
::method completed
  expose state
  use strict arg step, now
  if step~status \== 'PLANNED' then raise syntax 93.900 array ('Only a planned step can complete')
  state~apply(step, now)
  return self

/* demands: every demand this machine currently holds.  now: seconds. */
::method plan
  expose state headroomPct dwellSec swapMarginPct minCacheMiB
  use strict arg demands, now
  plan = .ProvisionPlan~new
  order = orderByPriority(demands)
  wanted = .Directory~new
  do d over order
    if wanted~hasIndex(d~id) then raise syntax 93.900 array ('Demand' d~id 'given twice')
    wanted[d~id] = d
  end
  budget = state~ramBudget

  /* Room if everything not yet decided were released. */
  diskRoom = state~diskFreeMiB + state~swapMiB
  fabricRoom = state~fabricFreeMiB
  do r over state~running~allItems
    if r~storageWhere == 'LOCAL'  then diskRoom += r~storageMiB
    if r~storageWhere == 'FABRIC' then fabricRoom += r~storageMiB
  end

  /* 1. Placement.  A running task keeps its place until the cluster
     moves it: running tasks are placed first, then new demands by
     priority. */
  placed = .Array~new; residentSum = 0; pageSum = 0
  waitingOn = .Directory~new          /* new demand id -> blocking running task id */
  do d over order
    if \state~running~hasIndex(d~id) then iterate
    placed~append(d); residentSum += d~residentMiB; pageSum += d~pageableMiB
    if d~storageWhere == 'LOCAL'  then diskRoom -= d~storageMiB
    if d~storageWhere == 'FABRIC' then fabricRoom -= d~storageMiB
  end
  do d over order
    if state~running~hasIndex(d~id) then iterate
    why = ''
    if residentSum + d~residentMiB > budget then why = 'resident RAM'
    else if d~storageWhere == 'LOCAL'  & d~storageMiB > diskRoom then why = 'local disk'
    else if d~storageWhere == 'FABRIC' & d~storageMiB > fabricRoom then why = 'fabric space'
    if why == '' then do
      placed~append(d); residentSum += d~residentMiB; pageSum += d~pageableMiB
      if d~storageWhere == 'LOCAL'  then diskRoom -= d~storageMiB
      if d~storageWhere == 'FABRIC' then fabricRoom -= d~storageMiB
      iterate
    end
    /* It does not fit.  Is a lower-priority running task in the way? */
    blocker = lowestRunningBelow(state, wanted, d~priority)
    if blocker \== .nil then do
      plan~add(.ProvisionStep~new('ASK_CLUSTER', blocker, 'make room for' d~id '(priority' d~priority')',,, 'PLANNED', 'move' blocker~id '(priority' blocker~priority') to another machine'))
      plan~add(.ProvisionStep~new('START_TASK', d, 'demand' d~id,,, 'WAITING', 'waits for the move of' blocker~id'; re-planned when the cluster answers'))
      waitingOn[d~id] = blocker~id
    end
    else
      plan~add(.ProvisionStep~new('ASK_CLUSTER', d, 'not enough' why 'here for' d~id,,, 'PLANNED', 'place' d~id 'on another machine'))
  end

  /* 2. Swap: only if the placed pageable RAM does not fit in RAM. */
  ramAfterResident = budget - residentSum
  swapNeed = 0
  if pageSum > ramAfterResident then do
    swapNeed = pageSum - ramAfterResident
    swapNeed = (swapNeed * (100 + swapMarginPct) + 99) % 100
  end
  swapAdd = 0
  if swapNeed > state~swapMiB then do
    swapAdd = swapNeed - state~swapMiB
    if swapAdd > diskRoom - state~swapMiB then do
      /* No disk for swap: the lowest-priority new pageable demand goes to the cluster. */
      victim = .nil
      do d over placed
        if state~running~hasIndex(d~id) | d~pageableMiB = 0 then iterate
        if victim == .nil then victim = d
        else if d~priority < victim~priority then victim = d
      end
      if victim \== .nil then do
        plan~add(.ProvisionStep~new('ASK_CLUSTER', victim, 'not enough local disk for' swapAdd 'MiB of swap',,, 'PLANNED', 'place' victim~id 'on another machine'))
        placed~removeItem(victim); residentSum -= victim~residentMiB; pageSum -= victim~pageableMiB
        swapAdd = 0; swapNeed = 0
        if pageSum > budget - residentSum then plan~noteViolation('swap needed by running tasks and no disk for it')
      end
      else plan~noteViolation('running tasks need' swapAdd 'MiB more swap and the disk cannot hold it')
    end
  end

  /* 3. Caches.  A new cache needs headroom; an existing one only needs
     to fit.  That gap is the hysteresis. */
  headroom = (state~ramTotalMiB * headroomPct + 99) % 100
  usedByTasks = residentSum + max(0, min(pageSum, budget - residentSum))
  if swapNeed > 0 then usedByTasks = budget          /* swapping: no RAM to spare */
  keepRoom = budget - usedByTasks
  newRoom = keepRoom - headroom
  keep = .Directory~new; add = .Array~new
  do d over order
    if \d~wantsRamSpeed | \inArray(placed, d) then iterate
    if state~caches~hasIndex(d~id) then do
      size = state~caches[d~id]['SIZE']
      if size <= keepRoom then do
        keep[d~id] = size; keepRoom -= size; newRoom -= size
      end
    end
  end
  do d over order
    if \d~wantsRamSpeed | \inArray(placed, d) | keep~hasIndex(d~id) then iterate
    if state~caches~hasIndex(d~id) then iterate      /* being dropped: not re-added in the same plan */
    if waitingOn~hasIndex(d~id) then iterate
    /* A READONLY store replaces the root, so it holds the whole of the
       data.  A cache in front of a drive may hold part of it. */
    if d~cacheMode == 'READONLY' then size = d~storageMiB
    else size = min(d~storageMiB, newRoom)
    if size <= newRoom & size >= min(minCacheMiB, d~storageMiB) & size > 0 then do
      add~append(.Array~of(d, size)); newRoom -= size; keepRoom -= size
    end
  end

  /* 4. The steps, in an order that frees before it takes. */
  /* a. Tasks no longer demanded stop. */
  do id over state~running~allIndexes~sort
    if \wanted~hasIndex(id) then do
      if state~caches~hasIndex(id) then call dropCache plan, state, state~running[id], 'demand' id 'withdrawn'
      plan~add(.ProvisionStep~new('STOP_TASK', state~running[id], 'demand' id 'withdrawn'))
    end
  end
  /* b. Caches that no longer fit, or whose demand went, are given back. */
  do id over state~caches~allIndexes~sort
    if keep~hasIndex(id) then iterate
    if state~running~hasIndex(id) & \wanted~hasIndex(id) then iterate   /* done in a */
    d = wanted[id]
    if d == .nil then d = state~running[id]
    if d == .nil then do
      plan~noteViolation('cache' id 'belongs to no demand or task')
      iterate
    end
    call dropCache plan, state, d, 'RAM is needed by higher-priority demands'
  end
  /* c. Swap grows before anything that needs it starts. */
  if swapAdd > 0 then
    plan~add(.ProvisionStep~new('ADD_SWAP', .nil, 'pageable RAM of placed tasks exceeds free RAM by' swapNeed - state~swapMiB 'MiB with margin', swapAdd))
  /* d. New tasks start, highest priority first. */
  do d over placed
    if state~running~hasIndex(d~id) then iterate
    plan~add(.ProvisionStep~new('START_TASK', d, 'demand' d~id '(priority' d~priority')'))
  end
  /* e. Swap no longer needed goes, after its minimum lifetime. */
  if swapNeed = 0 & state~swapMiB > 0 then do
    if now - state~swapSince < dwellSec then
      plan~add(.ProvisionStep~new('REMOVE_SWAP', .nil, 'pageable RAM now fits in RAM', state~swapMiB,, 'DEFERRED', 'kept until' state~swapSince + dwellSec's (minimum lifetime' dwellSec's)'))
    else
      plan~add(.ProvisionStep~new('REMOVE_SWAP', .nil, 'pageable RAM now fits in RAM', state~swapMiB))
  end
  /* f. Spare RAM becomes fast storage for the demands that want it. */
  do pair over add
    d = pair[1]
    plan~add(.ProvisionStep~new('ADD_CACHE', d, 'spare RAM above' headroom 'MiB headroom; demand' d~id 'wants RAM speed', pair[2], d~cacheMode))
  end

  /* 5. Simulate the planned steps; every intermediate state must hold. */
  sim = state~copy
  n = 0
  do s over plan~steps
    n += 1
    if s~status \== 'PLANNED' then iterate
    sim~apply(s, now)
    do v over sim~violations; plan~noteViolation('after step' n '('s~string'):' v); end
  end
  return plan

::routine dropCache
  use strict arg plan, state, d, why
  c = state~caches[d~id]
  if c['MODE'] == 'WRITEBACK' then
    plan~add(.ProvisionStep~new('FLUSH_CACHE', d, 'before giving back' d~id"'s write-back cache", c['SIZE'], c['MODE']))
  plan~add(.ProvisionStep~new('DROP_CACHE', d, why, c['SIZE'], c['MODE']))
  return

::routine orderByPriority
  use strict arg demands
  r = .Array~new
  do d over demands
    if \d~isA(.Demand) then raise syntax 93.900 array ('Only Demand objects can be planned')
    i = 1
    do while i <= r~items
      e = r[i]
      if d~priority > e~priority then leave
      if d~priority = e~priority & d~id << e~id then leave
      i += 1
    end
    if i = 1 then r~insert(d, .nil)
    else r~insert(d, i - 1)
  end
  return r

::routine lowestRunningBelow
  use strict arg state, wanted, priority
  best = .nil
  do id over state~running~allIndexes~sort
    if \wanted~hasIndex(id) then iterate
    d = state~running[id]
    if d~priority >= priority then iterate
    if best == .nil then best = d
    else if d~priority < best~priority then best = d
  end
  return best

::routine inArray
  use strict arg a, item
  do x over a; if x == item then return .true; end
  return .false
