/* Architecture: Tom Dyer. Coding: ChatGPT.
   Trusted owning-MU component. No placement, credentials or job authority. */
::class MiLaunchSpec public
::attribute id get
::attribute owner get
::attribute incarnation get
::attribute service get
::attribute root get
::method init
  expose id owner incarnation service root
  use strict arg id, owner, incarnation, service, root
  do v over .array~of(id,owner,incarnation,service)
    if v=='' | v~length>128 | v~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-')>0 then raise syntax 93.900 array('Invalid commissioned MI identity')
  end
  if root~left(1)\=='/' | root=='/' | root~length>4096 | root~pos('00'x)>0 then raise syntax 93.900 array('Invalid root path')

::class MiChildBackend public
::method init
  expose runner provider helper
  use strict arg helper
  if helper~left(1)\=='/' then raise syntax 93.900 array('Helper must be an absolute path')
  provider=.ProcessProvider~new
  runner=.ProcessRunner~new(provider)
::method argv
  expose helper
  use strict arg spec
  return .array~of(helper,spec~root,spec~id,spec~owner,spec~incarnation,spec~service)
::method spawn
  expose runner provider
  use strict arg spec
  p=.ProcessSpec~new(self~argv(spec))
  p~detach=.true; p~stdoutPolicy='DISCARD'; p~stderrPolicy='DISCARD'
  r=runner~run(p)
  out=.Directory~new; out['STARTED']=r~started; out['PID']=r~pid; out['HANDLE']=.nil; out['IDENTITY']=''
  if \r~started then return out
  observed=provider~observe(r~pid)
  if observed==.nil then return out
  h=provider~openProcessHandle(observed)
  if \h['OK'] then return out
  out['HANDLE']=h['PROCESS_HANDLE']; out['IDENTITY']=observed~identity
  return out
::method reap
  expose runner
  use strict arg pid
  return runner~reap(pid)

::class MiLaunchEntry public
::attribute spec get
::attribute pid get
::attribute handle get
::attribute identity get
::attribute state
::method init
  expose spec pid handle identity state
  use strict arg spec, child
  pid=child['PID']; handle=child['HANDLE']; identity=child['IDENTITY']
  state='STARTING'
  if handle==.nil then state='UNCERTAIN'

::class MiLauncher public
::method init
  expose backend registrar logger owner entries used capacity blocked
  use strict arg owner, backend, registrar, logger, capacity=2
  if \capacity~datatype('W') | capacity<1 | capacity>32 then raise syntax 93.900 array('Capacity 1..32')
  entries=.Directory~new; used=.Directory~new; blocked=.false
::method event private
  expose logger blocked
  use strict arg kind, spec, detail=''
  d=.Directory~new; d['KIND']=kind; d['MI']=spec~id; d['MU']=spec~owner
  d['INCARNATION']=spec~incarnation; d['SERVICE']=spec~service; d['DETAIL']=detail
  signal on syntax name failed
  if logger~log(.Log~INFO,d) then return .true
  failed:
  blocked=.true
  return .false
::method start
  expose backend entries used capacity owner blocked
  use strict arg spec
  if blocked then return 'LOG_UNAVAILABLE'
  if spec~owner\==owner then return 'WRONG_OWNER'
  if entries~hasIndex(spec~id) then return 'ALREADY_PRESENT'
  key=spec~id'/'spec~incarnation
  if used~hasIndex(key) then return 'INCARNATION_REUSED'
  if used~items>=4096 then return 'HISTORY_FULL'
  if entries~items>=capacity then return 'CAPACITY'
  do e over entries~allItems
    if e~spec~service==spec~service | e~spec~root==spec~root then return 'RESOURCE_CONFLICT'
  end
  if \self~event('MI_START_REQUEST',spec) then return 'LOG_UNAVAILABLE'
  used[key]=1
  child=backend~spawn(spec)
  if \child['STARTED'] then do
    self~event('MI_START_FAILED',spec)
    return 'START_FAILED'
  end
  e=.MiLaunchEntry~new(spec,child); entries[spec~id]=e
  if \self~event('MI_STARTED',spec,e~identity) then do
    e~state='QUARANTINED'; return 'LOG_UNAVAILABLE'
  end
  return e~state
::method poll
  expose entries registrar blocked backend
  use strict arg id
  if \entries~hasIndex(id) then return 'NOT_FOUND'
  e=entries[id]; s=e~spec
  if e~handle==.nil then do
    /* Reap only our own child; never signal by numeric PID. */
    r=backend~reap(e~pid)
    if r~termination=='EXIT' | r~termination=='SIGNAL' then do
      entries~remove(id); self~event('MI_EXIT',s,r~termination); return 'EXITED'
    end
    return 'UNCERTAIN'
  end
  w=e~handle~waitExit(0)
  if \w['OK'] then do
    e~state='QUARANTINED'; self~event('MI_OBSERVATION_GAP',s); return e~state
  end
  if w['EXITED'] then do
    r=backend~reap(e~pid)
    e~handle~close; entries~remove(id)
    self~event('MI_EXIT',s,r~termination)
    return 'EXITED'
  end
  if blocked | e~state=='QUARANTINED' then return 'QUARANTINED'
  /* Registrar belongs to owning controller. It verifies transport, incarnation
     and registration authority. This is not a network-supplied Boolean. */
  signal on syntax name gap
  p=registrar~observe(s~id,s~owner,s~incarnation,s~service,e~identity)
  good=.false
  if p\==.nil then do
    if p['VERIFIED']==.true & p['MI']==s~id & p['MU']==s~owner & p['INCARNATION']==s~incarnation & p['SERVICE']==s~service & p['PROCESS_IDENTITY']==e~identity then good=.true
  end
  if good then do
    if e~state\=='REGISTERED' then if \self~event('MI_REGISTERED',s,e~identity) then do; e~state='QUARANTINED'; return e~state; end
    e~state='REGISTERED'
  end
  else do
    if e~state=='REGISTERED' then if \self~event('MI_REGISTRATION_LOST',s) then do; e~state='QUARANTINED'; return e~state; end
    e~state='STARTING'
  end
  return e~state
  gap:
  e~state='QUARANTINED'; self~event('MI_OBSERVATION_GAP',s); return e~state
::method stop
  expose entries
  use strict arg id, incarnation
  if \entries~hasIndex(id) then return 'NOT_FOUND'
  e=entries[id]; s=e~spec
  if s~incarnation\==incarnation then return 'STALE_INCARNATION'
  if e~handle==.nil then return 'UNCERTAIN'
  /* A safety stop must remain possible if the logging lane is down. */
  self~event('MI_STOP_REQUEST',s)
  r=e~handle~signal(15)
  if \r['OK'] then return self~poll(id)
  w=e~handle~waitExit(5000)
  if w['OK'] & w['EXITED'] then return self~poll(id)
  e~state='QUARANTINED'; self~event('MI_STOP_UNCONFIRMED',s)
  return 'STOP_UNCONFIRMED'
/* Trusted controller can register these persistent process handles in its
   own event mux. On readiness it must call poll(id); not a proposal API. */
::method exitSources
  expose entries
  out=.Array~new
  do e over entries~allItems
    if e~handle==.nil then iterate
    row=.Directory~new; row['MI']=e~spec~id; row['INCARNATION']=e~spec~incarnation; row['HANDLE']=e~handle
    out~append(row)
  end
  return out
::method count
  expose entries
  return entries~items
::requires 'ProcessProvider.cls'
::requires 'Process.cls'
::requires 'LoggingCore.cls'
