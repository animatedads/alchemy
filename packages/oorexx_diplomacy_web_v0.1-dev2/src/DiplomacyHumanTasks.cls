/* Host-side task rendezvous for DiplomacyGame~press / ~orders. A task is
   a one-shot capability scoped to the authenticated participant and power.
   No legal move service or access to the referee. */
::class DiplomacyHumanTasks public
::method init
  expose owners tasks serial clock timeout prefix
  use strict arg seatOwners, clock=.nil, timeout=0, prefix=''
  owners=seatOwners~copy
  tasks=.directory~new
  serial=0
::method issue
  expose owners tasks serial clock timeout prefix
  use strict arg view
  numeric digits 18
  power=view['POWER']
  if \owners~hasIndex(power) | tasks~hasIndex(power) then return .nil
  serial+=1
  t=.directory~new
  t['ID']=prefix||'T'||serial; t['OWNER']=owners[power]; t['STATE']='OPEN'; t['REPLY']=.nil
  /* Positive list; only detached text supplied by dev7r1 controller. */
  v=.directory~new
  do key over .array~of('YEAR','PHASE','KIND','POWER','BALANCE','TASK','MAP','BOARD','OWNERSHIP','LAST_RESULTS','PUBLIC_SINCE_CALL','DISLODGED','HISTORY','ROUND','ROUNDS','PLAYER_LIST','INBOX')
    if view~hasIndex(key) then v[key]=detachTask(view[key])
  end
  t['VIEW']=v; t['DEADLINE']=''; if clock\==.nil then t['DEADLINE']=clock~now+timeout
  tasks[power]=t
  return t['ID']
::method project
  expose tasks clock
  use strict arg principal
  numeric digits 18
  do power over tasks
    t=tasks[power]
    if t['OWNER']\==principal | t['STATE']\=='OPEN' then iterate
    if clock\==.nil then if clock~now>=t['DEADLINE'] then iterate
    out=.directory~new
    out['deadline']=t['DEADLINE']; out['remaining']=''; if clock\==.nil then out['remaining']=max(0,t['DEADLINE']-clock~now)
    out['id']=t['ID']; v=.directory~new
    do key over t['VIEW']
      v[key]=detachTask(t['VIEW'][key])
    end
    out['view']=v
    return out
  end
  return .nil
::method submit
  expose tasks clock
  use strict arg principal,id,raw
  numeric digits 18
  if \raw~isA(.string) then return 'BAD_RESPONSE'
  if raw~length>65536 then return 'RESPONSE_TOO_LONG'
  do power over tasks
    t=tasks[power]
    if t['ID']\==id then iterate
    if t['OWNER']\==principal then return 'TASK_DENIED'
    if t['STATE']\=='OPEN' then return 'TASK_CLOSED'
    if clock\==.nil then if clock~now>=t['DEADLINE'] then return 'TASK_EXPIRED'
    if t['VIEW']['KIND']=='PRESS' then response=raw
    else do
      response=.array~new
      text=raw~changestr('0d0a'x,'0a'x)~changestr('0d'x,'0a'x)
      do line over text~makeArray('0a'x)
        if line\=='' then response~append(line)
      end
    end
    t['REPLY']=.array~of('OK',response); t['STATE']='SEALED'
    return 'SUBMITTED'
  end
  return 'TASK_DENIED'
::method take
  expose tasks
  use strict arg power,id
  t=tasks[power]
  if t==.nil then return .nil
  if t['ID']\==id | t['STATE']\=='SEALED' then return .nil
  tasks~remove(power)
  return t['REPLY']
::method expire
  expose tasks
  use strict arg power,id
  t=tasks[power]
  if t==.nil then return .false
  if t['ID']\==id | t['STATE']=='SEALED' then return .false
  tasks~remove(power)
  return .true

::routine detachTask
  use strict arg value
  if value~isA(.string) then return value
  if value~isA(.array) then do
    copyValue=.array~new
    do item over value
      copyValue~append(detachTask(item))
    end
    return copyValue
  end
  raise syntax 93.900 array('Unexpected task projection value')

/* The system clock must be UTC and monitored on the production host.
   Epoch-like integer uses Rexx base date; browser displays relative wait only.
   A backwards clock is clamped within this service. Worker independently
   bounds waits by elapsed time. */
::class DiplomacyTaskClock public
::method init
  expose last
  last=0
::method now
  expose last
  numeric digits 18
  value=date('B')*86400+time('S')
  if value>last then last=value
  return last
