/* Host-side task rendezvous for DiplomacyGame~press / ~orders. A task is
   a one-shot capability scoped to the authenticated participant and power.
   No legal move service or access to the referee. */
::class DiplomacyHumanTasks public
::method init
  expose owners tasks serial
  use strict arg seatOwners
  owners=seatOwners~copy
  tasks=.directory~new
  serial=0
::method issue
  expose owners tasks serial
  use strict arg view
  power=view['POWER']
  if \owners~hasIndex(power) | tasks~hasIndex(power) then return .nil
  serial+=1
  t=.directory~new
  t['ID']='T'||serial; t['OWNER']=owners[power]; t['STATE']='OPEN'; t['REPLY']=.nil
  /* Positive list; only detached text supplied by dev6 controller. */
  v=.directory~new
  do key over .array~of('YEAR','PHASE','KIND','POWER','BALANCE','TASK','MAP','BOARD','OWNERSHIP','LAST_RESULTS','DISLODGED','HISTORY','ROUND','ROUNDS','PLAYER_LIST','INBOX')
    if view~hasIndex(key) then v[key]=detachTask(view[key])
  end
  t['VIEW']=v; tasks[power]=t
  return t['ID']
::method project
  expose tasks
  use strict arg principal
  do power over tasks
    t=tasks[power]
    if t['OWNER']\==principal | t['STATE']\=='OPEN' then iterate
    out=.directory~new
    out['id']=t['ID']; v=.directory~new
    do key over t['VIEW']
      v[key]=detachTask(t['VIEW'][key])
    end
    out['view']=v
    return out
  end
  return .nil
::method submit
  expose tasks
  use strict arg principal,id,raw
  if \raw~isA(.string) then return 'BAD_RESPONSE'
  if raw~length>65536 then return 'RESPONSE_TOO_LONG'
  do power over tasks
    t=tasks[power]
    if t['ID']\==id then iterate
    if t['OWNER']\==principal then return 'TASK_DENIED'
    if t['STATE']\=='OPEN' then return 'TASK_CLOSED'
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
    result=.array~new
    do item over value
      result~append(detachTask(item))
    end
    return result
  end
  raise syntax 93.900 array('Unexpected task projection value')
