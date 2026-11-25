/* rexxos_arbitrator v0.1-dev5: the machine arbitrator.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).

   A machine does not run provisioning scripts.  It holds demands, and a
   MachineArbitrator - the one authority over that machine's resources -
   turns the demands and the machine's state into a ProvisionPlan: the
   ordered steps that reach the target state.  The plan is data.  Each step
   names the demand it serves, its inverse and whether it changes the
   machine (then it needs approval).  The plan is simulated step by step
   against a copy of the state and refused if any step breaks an invariant.

   dev2 (Tom Dyer, 2026-11-25):
   - An MU is disposable.  It holds nothing that cannot be rebuilt or
     moved: a demand's state lives on a FABRIC, in a CHECKPOINT, or is
     TEMPORARY.  LOCAL state is refused.
   - A task with its state on a fabric or in a checkpoint can be
     deactivated (Aglets: swapped out whole) and activated again, here or
     anywhere.  The arbitrator prefers deactivating lower-importance tasks
     to adding swap, and to making a higher-importance demand wait.  Each
     deactivation asks the cluster where the task should be activated.
   - Priority is importance, as in WLM.

   dev3 (Tom Dyer, 2026-11-25):
   - The disappearance of a node is just that: something the cluster grid
     deals with.  Recovery steps (fence a role, move a role's or a dead
     MU's service route, activate or restart what existed from its saved
     state) are pre-approved: they run without waiting, are logged with
     their cause and reported.  A recovery step may only restore what
     existed; a plan that would add capacity or change exposure drops back
     to NEEDS TOM'S DIRECT APPROVAL.
   - A plan, its demands and the machine ledger are text (toText/fromText)
     so the PlanRunner can journal them and survive a pulled plug.

   The arbitrator never moves a task itself: it asks the cluster
   (ASK_CLUSTER).  A cache's mode is decided per request.

   Units are MiB and seconds.  Nothing here touches a real machine. */

/* ------------------------------------------------------------------ */
::class Demand public
::method init
  expose id priority ramMiB pageableMiB storageMiB storageWhere wantsRamSpeed durability cacheMode stateWhere
  use strict arg id, priority, ramMiB = 0, pageableMiB = 0, storageMiB = 0, storageWhere = 'NONE', wantsRamSpeed = .false, durability = 'DURABLE', cacheMode = '', stateWhere = ''
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
  /* Where the truth lives.  The MU holds nothing that cannot be rebuilt or moved. */
  stateWhere = stateWhere~upper
  if stateWhere == '' then do
    if durability == 'TEMPORARY' then stateWhere = 'TEMPORARY'
    else stateWhere = 'FABRIC'
  end
  if stateWhere == 'LOCAL' then raise syntax 93.900 array ('Demand' id': LOCAL state is refused: an MU holds nothing that cannot be rebuilt or moved')
  if wordpos(stateWhere, 'FABRIC CHECKPOINT TEMPORARY') = 0 then raise syntax 93.900 array ('Demand' id': state must live on a FABRIC, in a CHECKPOINT, or be TEMPORARY')
  if durability \== 'TEMPORARY' & stateWhere == 'TEMPORARY' then raise syntax 93.900 array ('Demand' id':' durability 'data cannot have TEMPORARY state')
::attribute id get
::attribute priority get
::attribute ramMiB get
::attribute pageableMiB get
::attribute storageMiB get
::attribute storageWhere get
::attribute wantsRamSpeed get
::attribute durability get
::attribute cacheMode get
::attribute stateWhere get
/* WLM's word for it. */
::method importance
  expose priority
  return priority
::method residentMiB
  expose ramMiB pageableMiB
  return ramMiB - pageableMiB
/* Its state survives being swapped out whole: it can be activated again here or elsewhere. */
::method deactivatable
  expose stateWhere
  return stateWhere \== 'TEMPORARY'
::method string
  expose id
  return 'Demand' id
/* One line, fields separated by |, for the journal and the ledger. */
::method toText
  expose id priority ramMiB pageableMiB storageMiB storageWhere wantsRamSpeed durability cacheMode stateWhere
  return 'DEMAND|'id'|'priority'|'ramMiB'|'pageableMiB'|'storageMiB'|'storageWhere'|'wantsRamSpeed'|'durability'|'cacheMode'|'stateWhere
::method fromText class
  use strict arg line
  parse var line tag '|' id '|' pr '|' ram '|' pg '|' sto '|' where '|' fast '|' dur '|' mode '|' state
  if tag \== 'DEMAND' | state == '' then raise syntax 93.900 array ('Not a demand record:' line)
  return self~new(id, pr, ram, pg, sto, where, fast, dur, mode, state)

/* ------------------------------------------------------------------ */
/* What the machine has and what it is doing.  Free space excludes what
   running tasks and the swap file already hold.  parked: tasks whose
   state is saved on a fabric or in a checkpoint and may be activated here. */
::class MachineState public
::method init
  expose ramTotalMiB baseMiB diskFreeMiB fabricFreeMiB swapMiB swapSince running caches parked
  use strict arg ramTotalMiB, baseMiB, diskFreeMiB, fabricFreeMiB = 0
  do v over .Array~of(ramTotalMiB, baseMiB, diskFreeMiB, fabricFreeMiB)
    if \v~datatype('W') then raise syntax 93.900 array ('Machine sizes must be whole MiB')
    if v < 0 then raise syntax 93.900 array ('Machine sizes must not be negative')
  end
  if baseMiB >= ramTotalMiB then raise syntax 93.900 array ('Base use leaves no RAM')
  swapMiB = 0; swapSince = 0
  running = .Directory~new     /* id -> Demand */
  caches = .Directory~new      /* id -> Directory SIZE MODE SINCE DIRTY */
  parked = .Directory~new      /* id -> Demand */
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
::method parked
  expose parked
  return parked
::method ramBudget
  expose ramTotalMiB baseMiB
  return ramTotalMiB - baseMiB
::method copy
  expose ramTotalMiB baseMiB diskFreeMiB fabricFreeMiB swapMiB swapSince running caches parked
  c = .MachineState~new(ramTotalMiB, baseMiB, diskFreeMiB, fabricFreeMiB)
  c~restore(swapMiB, swapSince, running, caches, parked)
  return c
/* For copy only. */
::method restore
  expose swapMiB swapSince running caches parked
  use strict arg swapMiB, swapSince, r, k, p
  running = r~copy
  parked = p~copy
  caches = .Directory~new
  do id over k~allIndexes; caches[id] = k[id]~copy; end
/* The ledger as text lines: MACHINE, then RUN, PARK and CACHE records. */
::method toLines
  expose ramTotalMiB baseMiB diskFreeMiB fabricFreeMiB swapMiB swapSince running caches parked
  r = .Array~of('MACHINE|'ramTotalMiB'|'baseMiB'|'diskFreeMiB'|'fabricFreeMiB'|'swapMiB'|'swapSince)
  do id over running~allIndexes~sort; r~append('RUN|'running[id]~toText); end
  do id over parked~allIndexes~sort; r~append('PARK|'parked[id]~toText); end
  do id over caches~allIndexes~sort
    c = caches[id]
    r~append('CACHE|'id'|'c['SIZE']'|'c['MODE']'|'c['SINCE']'|'c['DIRTY'])
  end
  return r
::method fromLines class
  use strict arg lines
  m = .nil; run = .Directory~new; park = .Directory~new; k = .Directory~new
  do line over lines
    parse var line tag '|' rest
    select
      when tag == 'MACHINE' then do
        parse var rest t '|' b '|' df '|' ff '|' sw '|' since
        m = self~new(t, b, df, ff); swap = sw; swapSince = since
      end
      when tag == 'RUN'  then do; d = .Demand~fromText(rest); run[d~id] = d; end
      when tag == 'PARK' then do; d = .Demand~fromText(rest); park[d~id] = d; end
      when tag == 'CACHE' then do
        parse var rest id '|' size '|' mode '|' since '|' dirty
        c = .Directory~new; c['SIZE'] = size; c['MODE'] = mode; c['SINCE'] = since; c['DIRTY'] = (dirty == 1)
        k[id] = c
      end
      otherwise raise syntax 93.900 array ('Not a ledger record:' line)
    end
  end
  if m == .nil then raise syntax 93.900 array ('Ledger has no MACHINE record')
  m~restore(swap, swapSince, run, k, park)
  return m
/* Take on another ledger's contents (a resumed runner loads its snapshot). */
::method replaceWith
  expose ramTotalMiB baseMiB diskFreeMiB fabricFreeMiB swapMiB swapSince running caches parked
  use strict arg o
  ramTotalMiB = o~ramTotalMiB; baseMiB = o~baseMiB; diskFreeMiB = o~diskFreeMiB; fabricFreeMiB = o~fabricFreeMiB
  swapMiB = o~swapMiB; swapSince = o~swapSince
  running = o~running~copy; parked = o~parked~copy
  caches = .Directory~new
  do id over o~caches~allIndexes; caches[id] = o~caches[id]~copy; end
  return self
/* The cluster says a task's saved state may be activated here. */
::method park
  expose parked running
  use strict arg d
  if running~hasIndex(d~id) then raise syntax 93.900 array ('Task' d~id 'is running here')
  if \d~deactivatable then raise syntax 93.900 array ('Task' d~id 'has TEMPORARY state and cannot be parked')
  parked[d~id] = d
  return self
/* The cluster has taken a parked task elsewhere. */
::method unpark
  expose parked
  use strict arg id
  parked~remove(id)
  return self
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
  expose diskFreeMiB fabricFreeMiB swapMiB swapSince running caches parked
  use strict arg step, now = 0
  d = step~demand
  k = step~kind
  select
    when k == 'START_TASK' | k == 'ACTIVATE_TASK' then do
      if running~hasIndex(d~id) then raise syntax 93.900 array ('Task' d~id 'is already running')
      if k == 'ACTIVATE_TASK' then do
        if \parked~hasIndex(d~id) then raise syntax 93.900 array ('Task' d~id 'has no saved state here to activate')
        parked~remove(d~id)
      end
      running[d~id] = d
      if d~storageWhere == 'LOCAL'  then diskFreeMiB -= d~storageMiB
      if d~storageWhere == 'FABRIC' then fabricFreeMiB -= d~storageMiB
    end
    when k == 'STOP_TASK' | k == 'DEACTIVATE_TASK' then do
      if \running~hasIndex(d~id) then raise syntax 93.900 array ('Task' d~id 'is not running')
      if caches~hasIndex(d~id) then raise syntax 93.900 array ('Task' d~id 'still has a cache')
      if k == 'DEACTIVATE_TASK' then do
        if \d~deactivatable then raise syntax 93.900 array ('Task' d~id 'has TEMPORARY state and cannot be deactivated')
        parked[d~id] = d
      end
      running~remove(d~id)
      if d~storageWhere == 'LOCAL'  then diskFreeMiB += d~storageMiB
      if d~storageWhere == 'FABRIC' then fabricFreeMiB += d~storageMiB
    end
    when k == 'ADD_SWAP' then do
      if swapMiB = 0 then swapSince = now
      swapMiB += step~sizeMiB; diskFreeMiB -= step~sizeMiB
    end
    when k == 'REMOVE_SWAP' then do
      diskFreeMiB += swapMiB; swapMiB = 0; swapSince = 0
    end
    when k == 'ADD_CACHE' then do
      if caches~hasIndex(d~id) then raise syntax 93.900 array ('Cache for' d~id 'already exists')
      c = .Directory~new; c['SIZE'] = step~sizeMiB; c['MODE'] = step~mode; c['SINCE'] = now; c['DIRTY'] = .false
      caches[d~id] = c
    end
    when k == 'FLUSH_CACHE' then do
      if \caches~hasIndex(d~id) then raise syntax 93.900 array ('No cache for' d~id)
      caches[d~id]['DIRTY'] = .false
    end
    when k == 'DROP_CACHE' then do
      if \caches~hasIndex(d~id) then raise syntax 93.900 array ('No cache for' d~id)
      if caches[d~id]['DIRTY'] then raise syntax 93.900 array ('Cache for' d~id 'dropped while dirty')
      caches~remove(d~id)
    end
    when wordpos(k, 'ASK_CLUSTER CHECK_SERVING FENCE_ROLE ROUTE_SERVICE ANNOUNCE_ROLE REPOINT_DNS WAIT_DNS') > 0 then nop
    otherwise raise syntax 93.900 array ('Unknown step' k)
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
  if wordpos(kind, self~class~kinds) = 0 then raise syntax 93.900 array ('Unknown step kind' kind)
  if wordpos(status, 'PLANNED DEFERRED WAITING') = 0 then raise syntax 93.900 array ('Unknown step status' status)
::method kinds class
  return 'STOP_TASK DEACTIVATE_TASK FLUSH_CACHE DROP_CACHE ADD_SWAP START_TASK ACTIVATE_TASK REMOVE_SWAP ADD_CACHE ASK_CLUSTER'
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
    when kind == 'START_TASK'      then return 'STOP_TASK'
    when kind == 'STOP_TASK'       then return 'START_TASK'
    when kind == 'DEACTIVATE_TASK' then return 'ACTIVATE_TASK'
    when kind == 'ACTIVATE_TASK'   then return 'DEACTIVATE_TASK'
    when kind == 'ADD_SWAP'        then return 'REMOVE_SWAP'
    when kind == 'REMOVE_SWAP'     then return 'ADD_SWAP'
    when kind == 'ADD_CACHE'       then return 'DROP_CACHE'
    when kind == 'DROP_CACHE'      then return 'ADD_CACHE'
    otherwise return ''
  end
/* For some steps the note is the list of actions; describe prints it once. */
::method noteIsActions
  return .false
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
    when kind == 'DEACTIVATE_TASK' then
      return .Array~of('tell' demand~id 'to get ready to move (its deactivating hook)', 'write' demand~id"'s state to its" demand~stateWhere~lower, 'verify the saved state against its digest', 'release' demand~id"'s RAM")
    when kind == 'ACTIVATE_TASK' then
      return .Array~of('read' demand~id"'s saved state from its" demand~stateWhere~lower, 'verify it against its digest', 'resume' demand~id)
    when kind == 'START_TASK' then return .Array~of('start' demand~id)
    when kind == 'STOP_TASK'  then return .Array~of('stop' demand~id)
    otherwise return .Array~of('ask the cluster:' self~note)
  end
/* One line for the journal.  Text fields are escaped so | stays a separator. */
::method toText
  expose kind demand sizeMiB mode cause status note
  id = ''
  if demand \== .nil then id = demand~id
  return 'STEP|'kind'|'id'|'sizeMiB'|'mode'|'status'|'escapeText(cause)'|'escapeText(note)
/* demands: id -> Demand, for the demand the step names. */
::method fromText class
  use strict arg line, demands
  f = .ProvisionStep~fieldsFromText(line, demands)
  return .ProvisionStep~new(f[1], f[2], f[3], f[4], f[5], f[6], f[7])
/* kind, demand, cause, size, mode, status, note - for subclasses too. */
::method fieldsFromText class
  use strict arg line, demands
  parse var line tag '|' kind '|' id '|' size '|' mode '|' status '|' cause '|' note
  if tag \== 'STEP' then raise syntax 93.900 array ('Not a step record:' line)
  d = .nil
  if id \== '' then do
    if \demands~hasIndex(id) then raise syntax 93.900 array ('Step names unknown demand' id)
    d = demands[id]
  end
  return .Array~of(kind, d, unescapeText(cause), size, mode, status, unescapeText(note))
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
  expose steps violations purpose
  steps = .Array~new; violations = .Array~new; purpose = 'PROVISION'
/* PROVISION (every change needs Tom's direct approval) or RECOVERY (a node
   is gone; restoring steps are pre-approved). */
::method purpose
  expose purpose
  return purpose
::method setPurpose
  expose purpose
  use strict arg purpose
  if wordpos(purpose, 'PROVISION RECOVERY') = 0 then raise syntax 93.900 array ('Unknown plan purpose' purpose)
  return self
::method recoveryKinds class
  return 'FENCE_ROLE ROUTE_SERVICE ANNOUNCE_ROLE ACTIVATE_TASK START_TASK'
/* '' if every change in a recovery plan only restores; else the reason it needs approval. */
::method recoveryProblem
  expose purpose
  if purpose \== 'RECOVERY' then return 'not a recovery plan'
  do s over self~planned
    if \s~changesMachine then iterate
    if wordpos(s~kind, .ProvisionPlan~recoveryKinds) = 0 then return s~kind 'is not a restoring step'
  end
  return ''
/* RECOVERY: pre-approved, logged and reported.  TOM: needs Tom's direct approval. */
::method approvalClass
  if self~recoveryProblem == '' then return 'RECOVERY'
  return 'TOM'
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
  if self~approvalClass == 'RECOVERY' then return .false
  do s over self~planned; if s~changesMachine then return .true; end
  return .false
::method describe
  expose steps violations purpose
  lines = .Array~new
  cls = self~approvalClass
  if purpose == 'RECOVERY' & cls == 'TOM' then lines~append('Recovery plan, but it needs approval:' self~recoveryProblem)
  if cls == 'RECOVERY' then mark = '  RECOVERY: pre-approved (Tom Dyer, 2026-11-25); logged and reported'
  else mark = '  NEEDS TOM''S DIRECT APPROVAL'
  n = 0
  do s over steps
    n += 1
    flag = ''
    if s~status == 'PLANNED' & s~changesMachine then flag = mark
    lines~append(right(n, 2)'.' s~string flag)
    lines~append('    why:' s~cause)
    if s~note \== '' & s~kind \== 'ASK_CLUSTER' & \s~noteIsActions then lines~append('    note:' s~note)
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
/* The arbitrator's own record, for the PlanRunner's snapshots. */
::method snapshotLines
  expose state headroomPct dwellSec swapMarginPct minCacheMiB
  r = .Array~of('ARBSET|'headroomPct'|'dwellSec'|'swapMarginPct'|'minCacheMiB)
  do l over state~toLines; r~append(l); end
  return r
::method restoreFromLines
  expose state headroomPct dwellSec swapMarginPct minCacheMiB
  use strict arg lines
  rest = .Array~new
  do l over lines
    if l~startsWith('ARBSET|') then parse var l . '|' headroomPct '|' dwellSec '|' swapMarginPct '|' minCacheMiB
    else rest~append(l)
  end
  state~replaceWith(.MachineState~fromLines(rest))
  return self
/* Record that a step has been carried out on the real machine. */
::method completed
  expose state
  use strict arg step, now
  if step~status \== 'PLANNED' then raise syntax 93.900 array ('Only a planned step can complete')
  state~apply(step, now)
  return self

/* The steps that give a demand's resources back when the cluster takes
   it elsewhere: its cache first, then the task, deactivated so its state
   travels. */
::method releaseSteps
  expose state
  use strict arg d, why, st = .nil
  if st == .nil then st = state
  r = .Array~new
  if st~caches~hasIndex(d~id) then do
    c = st~caches[d~id]
    if c['MODE'] == 'WRITEBACK' then r~append(.ProvisionStep~new('FLUSH_CACHE', d, 'before giving back' d~id"'s write-back cache", c['SIZE'], c['MODE']))
    r~append(.ProvisionStep~new('DROP_CACHE', d, why, c['SIZE'], c['MODE']))
  end
  if st~running~hasIndex(d~id) then do
    if d~deactivatable then r~append(.ProvisionStep~new('DEACTIVATE_TASK', d, why))
    else r~append(.ProvisionStep~new('STOP_TASK', d, why))
  end
  return r

/* demands: every demand this machine currently holds.  now: seconds.
   st: plan against this state instead of the machine's own (the cluster
   uses it to try a placement on a copy). */
::method plan
  expose state headroomPct dwellSec swapMarginPct minCacheMiB
  use strict arg demands, now, st = .nil, restoreOnly = .false
  if st == .nil then st = state
  /* restoreOnly: a recovery placement.  It may start or activate what is
     demanded, nothing more: no swap, no new cache, no other task swapped out. */
  plan = .ProvisionPlan~new
  order = orderByPriority(demands)
  wanted = .Directory~new
  do d over order
    if wanted~hasIndex(d~id) then raise syntax 93.900 array ('Demand' d~id 'given twice')
    wanted[d~id] = d
  end
  budget = st~ramBudget

  /* Room if everything not yet decided were released. */
  diskRoom = st~diskFreeMiB + st~swapMiB
  fabricRoom = st~fabricFreeMiB
  do r over st~running~allItems
    if r~storageWhere == 'LOCAL'  then diskRoom += r~storageMiB
    if r~storageWhere == 'FABRIC' then fabricRoom += r~storageMiB
  end

  /* 1. Placement.  Running tasks first, then new demands by importance. */
  placed = .Array~new; residentSum = 0; pageSum = 0
  deactivate = .Array~new             /* running tasks to swap out whole */
  waitingOn = .Directory~new
  do d over order
    if \st~running~hasIndex(d~id) then iterate
    placed~append(d); residentSum += d~residentMiB; pageSum += d~pageableMiB
    if d~storageWhere == 'LOCAL'  then diskRoom -= d~storageMiB
    if d~storageWhere == 'FABRIC' then fabricRoom -= d~storageMiB
  end
  do d over order
    if st~running~hasIndex(d~id) then iterate
    why = fitProblem(d, residentSum, budget, diskRoom, fabricRoom)
    /* Lower-importance running tasks whose state survives are swapped out
       whole until the demand fits; the cluster decides where they resume. */
    do while why \== '' & \restoreOnly
      victim = lowestRunningBelow(st, wanted, d~priority, placed, .true)
      if victim == .nil then leave
      call swapOut victim, 'make room for' d~id '(importance' d~priority')'
      why = fitProblem(d, residentSum, budget, diskRoom, fabricRoom)
    end
    if why == '' then do
      placed~append(d); residentSum += d~residentMiB; pageSum += d~pageableMiB
      if d~storageWhere == 'LOCAL'  then diskRoom -= d~storageMiB
      if d~storageWhere == 'FABRIC' then fabricRoom -= d~storageMiB
      iterate
    end
    /* A running task whose state cannot travel is in the way: ask the cluster to move it. */
    blocker = lowestRunningBelow(st, wanted, d~priority, placed, .false)
    if blocker \== .nil then do
      plan~add(.ProvisionStep~new('ASK_CLUSTER', blocker, 'make room for' d~id '(importance' d~priority')',,, 'PLANNED', 'move' blocker~id '(importance' blocker~priority') to another machine'))
      plan~add(.ProvisionStep~new(startKind(st, d), d, 'demand' d~id,,, 'WAITING', 'waits for the move of' blocker~id'; re-planned when the cluster answers'))
      waitingOn[d~id] = blocker~id
    end
    else
      plan~add(.ProvisionStep~new('ASK_CLUSTER', d, 'not enough' why 'here for' d~id,,, 'PLANNED', 'place' d~id 'on another machine'))
  end

  /* 2. Pageable RAM beyond free RAM.  First swap out whole any placed task
     of lower importance than the most important placed demand whose state
     survives (Aglets swap-out); swap covers only what is left. */
  shortfall = pageSum - (budget - residentSum)
  if shortfall > 0 & restoreOnly then plan~noteViolation('restore only: would need' shortfall 'MiB more RAM or swap')
  if shortfall > 0 & \restoreOnly then do
    top = 0
    do d over placed; top = max(top, d~priority); end
    do forever
      if shortfall <= 0 then leave
      victim = .nil
      do d over placed
        if \d~deactivatable | d~priority >= top then iterate
        if victim == .nil then victim = d
        else if d~priority < victim~priority then victim = d
      end
      if victim == .nil then leave
      if st~running~hasIndex(victim~id) then call swapOut victim, 'free RAM instead of adding swap'
      else do
        plan~add(.ProvisionStep~new('ASK_CLUSTER', victim, 'free RAM instead of adding swap',,, 'PLANNED', 'activate' victim~id 'on another machine'))
        placed~removeItem(victim); residentSum -= victim~residentMiB; pageSum -= victim~pageableMiB
        if victim~storageWhere == 'LOCAL'  then diskRoom += victim~storageMiB
        if victim~storageWhere == 'FABRIC' then fabricRoom += victim~storageMiB
      end
      shortfall = pageSum - (budget - residentSum)
    end
  end
  ramAfterResident = budget - residentSum
  swapNeed = 0
  if pageSum > ramAfterResident then do
    swapNeed = pageSum - ramAfterResident
    swapNeed = (swapNeed * (100 + swapMarginPct) + 99) % 100
  end
  swapAdd = 0
  if swapNeed > st~swapMiB then do
    swapAdd = swapNeed - st~swapMiB
    if swapAdd > diskRoom - st~swapMiB then do
      /* No disk for swap: the lowest-importance new pageable demand goes to the cluster. */
      victim = .nil
      do d over placed
        if st~running~hasIndex(d~id) | d~pageableMiB = 0 then iterate
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
  headroom = (st~ramTotalMiB * headroomPct + 99) % 100
  usedByTasks = residentSum + max(0, min(pageSum, budget - residentSum))
  if swapNeed > 0 then usedByTasks = budget          /* swapping: no RAM to spare */
  keepRoom = budget - usedByTasks
  newRoom = keepRoom - headroom
  keep = .Directory~new; add = .Array~new
  do d over order
    if \d~wantsRamSpeed | \inArray(placed, d) then iterate
    if st~caches~hasIndex(d~id) then do
      size = st~caches[d~id]['SIZE']
      if size <= keepRoom then do
        keep[d~id] = size; keepRoom -= size; newRoom -= size
      end
    end
  end
  do d over order
    if \d~wantsRamSpeed | \inArray(placed, d) | keep~hasIndex(d~id) then iterate
    if st~caches~hasIndex(d~id) then iterate      /* being dropped: not re-added in the same plan */
    if waitingOn~hasIndex(d~id) | restoreOnly then iterate
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
  do id over st~running~allIndexes~sort
    if \wanted~hasIndex(id) then do
      if st~caches~hasIndex(id) then call dropCache plan, st, st~running[id], 'demand' id 'withdrawn'
      plan~add(.ProvisionStep~new('STOP_TASK', st~running[id], 'demand' id 'withdrawn'))
    end
  end
  /* b. Tasks swapped out whole, with their caches given back first. */
  do pair over deactivate
    d = pair[1]
    if st~caches~hasIndex(d~id) then call dropCache plan, st, d, 'task' d~id 'is being swapped out'
    plan~add(.ProvisionStep~new('DEACTIVATE_TASK', d, pair[2]))
  end
  /* c. Caches that no longer fit, or whose demand went, are given back. */
  do id over st~caches~allIndexes~sort
    if keep~hasIndex(id) then iterate
    if st~running~hasIndex(id) & \wanted~hasIndex(id) then iterate   /* done in a */
    if isDeactivating(deactivate, id) then iterate                  /* done in b */
    d = wanted[id]
    if d == .nil then d = st~running[id]
    if d == .nil then do
      plan~noteViolation('cache' id 'belongs to no demand or task')
      iterate
    end
    call dropCache plan, st, d, 'RAM is needed by more important demands'
  end
  /* d. Swap grows before anything that needs it starts. */
  if swapAdd > 0 then
    plan~add(.ProvisionStep~new('ADD_SWAP', .nil, 'pageable RAM of placed tasks exceeds free RAM by' swapNeed - st~swapMiB 'MiB with margin', swapAdd))
  /* e. New tasks start, or resume from saved state, most important first. */
  do d over placed
    if st~running~hasIndex(d~id) then iterate
    plan~add(.ProvisionStep~new(startKind(st, d), d, 'demand' d~id '(importance' d~priority')'))
  end
  /* f. Swap no longer needed goes, after its minimum lifetime. */
  if swapNeed = 0 & st~swapMiB > 0 then do
    if now - st~swapSince < dwellSec then
      plan~add(.ProvisionStep~new('REMOVE_SWAP', .nil, 'pageable RAM now fits in RAM', st~swapMiB,, 'DEFERRED', 'kept until' st~swapSince + dwellSec's (minimum lifetime' dwellSec's)'))
    else
      plan~add(.ProvisionStep~new('REMOVE_SWAP', .nil, 'pageable RAM now fits in RAM', st~swapMiB))
  end
  /* g. Spare RAM becomes fast storage for the demands that want it. */
  do pair over add
    d = pair[1]
    plan~add(.ProvisionStep~new('ADD_CACHE', d, 'spare RAM above' headroom 'MiB headroom; demand' d~id 'wants RAM speed', pair[2], d~cacheMode))
  end

  /* 5. Simulate the planned steps; every intermediate state must hold. */
  sim = st~copy
  n = 0
  do s over plan~steps
    n += 1
    if s~status \== 'PLANNED' then iterate
    sim~apply(s, now)
    do v over sim~violations; plan~noteViolation('after step' n '('s~string'):' v); end
  end
  return plan

/* Swap a running task out whole: its state travels, the cluster decides
   where it resumes.  Shares the plan method's variables. */
swapOut:
  use arg victim, whyOut
  plan~add(.ProvisionStep~new('ASK_CLUSTER', victim, whyOut,,, 'PLANNED', 'activate' victim~id 'on another machine'))
  deactivate~append(.Array~of(victim, whyOut))
  placed~removeItem(victim); residentSum -= victim~residentMiB; pageSum -= victim~pageableMiB
  if victim~storageWhere == 'LOCAL'  then diskRoom += victim~storageMiB
  if victim~storageWhere == 'FABRIC' then fabricRoom += victim~storageMiB
  return

::routine fitProblem
  use strict arg d, residentSum, budget, diskRoom, fabricRoom
  if residentSum + d~residentMiB > budget then return 'resident RAM'
  if d~storageWhere == 'LOCAL'  & d~storageMiB > diskRoom then return 'local disk'
  if d~storageWhere == 'FABRIC' & d~storageMiB > fabricRoom then return 'fabric space'
  return ''

::routine startKind
  use strict arg st, d
  if st~parked~hasIndex(d~id) then return 'ACTIVATE_TASK'
  return 'START_TASK'

::routine isDeactivating
  use strict arg deactivate, id
  do pair over deactivate; if pair[1]~id == id then return .true; end
  return .false

::routine dropCache
  use strict arg plan, st, d, why
  c = st~caches[d~id]
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

/* The least important running task below a given importance that is still
   placed; movable = .true asks for one whose state survives deactivation,
   .false for one that does not. */
::routine lowestRunningBelow
  use strict arg st, wanted, priority, placed, movable
  best = .nil
  do id over st~running~allIndexes~sort
    if \wanted~hasIndex(id) then iterate
    d = st~running[id]
    if d~priority >= priority | d~deactivatable \== movable | \inArray(placed, d) then iterate
    if best == .nil then best = d
    else if d~priority < best~priority then best = d
  end
  return best

::routine inArray
  use strict arg a, item
  do x over a; if x == item then return .true; end
  return .false

::routine escapeText
  use strict arg t
  return t~changeStr('%', '%25')~changeStr('|', '%7C')~changeStr('0a'x, '%0A')
::routine unescapeText
  use strict arg t
  return t~changeStr('%0A', '0a'x)~changeStr('%7C', '|')~changeStr('%25', '%')
