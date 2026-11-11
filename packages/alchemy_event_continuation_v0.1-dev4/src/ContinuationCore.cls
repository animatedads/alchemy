/* Alchemy Event Continuation 0.1-dev2.
   ooRexx domain: durable edge detection, leased delivery, receipt and completion.
   No browser, HTTP, process or storage-provider policy in these objects. */

::class ContinuationBuild public
::constant API 'alchemy.event.continuation/0.1'
::constant RELEASE '0.1-dev4'

::class ContinuationClock public
::method now class
  /* Subtract a fixed base-day origin to keep the second counter within
     default NUMERIC DIGITS 9 for the prototype's operating horizon.
     Absolute B-days * 86400 would round away lease-second precision. */
  return (date('B') - 738000) * 86400 + time('S')

::class ContinuationWatch public
::attribute watchId get
::attribute testName get
::attribute path get
::attribute target get
::attribute message get
::attribute threshold get

::method init
  expose watchId testName path target message threshold observed initialized
  use strict arg watchId, testName, path, target, message, threshold=0
  testName=testName~upper
  if testName<>'FILE_EXISTS' & testName<>'FILE_ABSENT' & testName<>'FILE_SIZE_GE' then -
    raise syntax 93.900 array('Unsupported watch test: '||testName)
  if watchId='' | target='' | path='' | message='' then -
    raise syntax 93.900 array('Watch requires id, path, target and message')
  if \self~safe(watchId) | \self~safe(path) | \self~safe(target) | \self~safe(message) then -
    raise syntax 93.900 array('Watch contains journal delimiter or newline')
  if \datatype(threshold,'W') then raise syntax 93.900 array('Threshold must be an integer')
  if threshold<0 then raise syntax 93.900 array('Threshold must be nonnegative')
  observed=.false
  initialized=.false

::method safe
  use strict arg value
  return pos('|',value)=0 & pos('0A'x,value)=0 & pos('0D'x,value)=0 & pos('09'x,value)=0

::method condition
  expose testName path threshold
  exists=(stream(path,'C','QUERY EXISTS')<>'')
  select
    when testName='FILE_EXISTS' then return exists
    when testName='FILE_ABSENT' then return \exists
    when testName='FILE_SIZE_GE' then do
      if \exists then return .false
      call stream path,'C','OPEN READ'
      count=chars(path)
      call stream path,'C','CLOSE'
      return count>=threshold
    end
  end
  return .false

/* Persist the FALSE re-arm edge.  E|... is the durable TRUE edge.
   Replaying those records, not inspecting an old 'seen' flag, recovers the
   correct state if the daemon restarts between absence and re-appearance. */
::method sample
  expose watchId observed initialized
  use strict arg store
  current=self~condition
  if \initialized then do
    initialized=.true
    observed=store~latched(watchId)
  end
  if \current then do
    if observed then do
      store~rearm(watchId)
      observed=.false
    end
    return .nil
  end
  if observed then return .nil
  ev=store~enqueue(self)
  observed=.true
  return ev

::class ContinuationEvent public
::attribute eventId get
::attribute watchId get
::attribute target get
::attribute message get
::attribute received get
::attribute receiptOwner get
::attribute completed get
::attribute leaseOwner get
::attribute leaseUntil get

::method init
  expose eventId watchId target message received receiptOwner completed leaseOwner leaseUntil
  use strict arg eventId, watchId, target, message
  received=.false
  receiptOwner=''
  completed=.false
  leaseOwner=''
  leaseUntil=0

::method setLease
  expose leaseOwner leaseUntil
  use strict arg owner, until
  leaseOwner=owner
  leaseUntil=until+0

::method deliverable
  expose leaseOwner leaseUntil completed
  use strict arg now
  return \completed & (leaseOwner='' | now>=leaseUntil)

::method owned
  expose leaseOwner leaseUntil completed
  use strict arg owner, now
  return \completed & leaseOwner==owner & now<leaseUntil

::method markReceived
  expose received receiptOwner
  use strict arg owner
  received=.true
  receiptOwner=owner

::method markCompleted
  expose completed
  completed=.true

::method wire
  expose eventId target message
  return eventId||'09'x||target||'09'x||message

::class ContinuationStore public
::attribute journalPath get

::method init
  expose journalPath events order latches sequence registered watchOrder
  use strict arg journalPath
  events=.directory~new
  order=.array~new
  latches=.directory~new
  sequence=1
  registered=.directory~new
  watchOrder=.array~new
  self~replay

::method replay
  expose journalPath events order latches sequence registered watchOrder
  if stream(journalPath,'C','QUERY EXISTS')='' then return
  call stream journalPath,'C','OPEN READ'
  do while lines(journalPath)>0
    line=linein(journalPath)
    parse var line type '|' eventId '|' rest
    select
      when type='W' then do
        parse var rest testName '|' filePath '|' target '|' message '|' threshold
        if registered~hasIndex(eventId) then iterate
        watch=.ContinuationWatch~new(eventId,testName,filePath,target,message,threshold)
        registered[eventId]=watch
        watchOrder~append(eventId)
        latches[eventId]=.false
      end
      when type='E' then do
        parse var rest watchId '|' target '|' message
        if events~hasIndex(eventId) then iterate
        ev=.ContinuationEvent~new(eventId,watchId,target,message)
        events[eventId]=ev
        order~append(eventId)
        latches[watchId]=.true
        seqPart=eventId~substr(4)
        if datatype(seqPart,'W') then sequence=max(sequence,seqPart+1)
      end
      when type='S' then do
        if registered~hasIndex(eventId) then latches[eventId]=.false
      end
      when type='K' then do
        parse var rest owner '|' until
        if events~hasIndex(eventId) then events[eventId]~setLease(owner,until)
      end
      when type='R' then do
        if events~hasIndex(eventId) then events[eventId]~markReceived(rest)
      end
      when type='C' then do
        if events~hasIndex(eventId) then events[eventId]~markCompleted
      end
    end
  end
  call stream journalPath,'C','CLOSE'

::method appendRecord
  expose journalPath
  use strict arg record
  call stream journalPath,'C','OPEN WRITE APPEND'
  call lineout journalPath,record
  call stream journalPath,'C','CLOSE'

::method registeredWatches guarded
  expose registered watchOrder
  out=.array~new
  do id over watchOrder
    out~append(registered[id])
  end
  return out

::method registerWatch guarded
  expose registered watchOrder latches
  use strict arg watch
  id=watch~watchId
  if registered~hasIndex(id) then return .false
  self~appendRecord('W|'||id||'|'||watch~testName||'|'||watch~path||'|'||watch~target||'|'||watch~message||'|'||watch~threshold)
  registered[id]=watch
  watchOrder~append(id)
  latches[id]=.false
  return .true

::method hasWatch guarded
  expose registered
  use strict arg watchId
  return registered~hasIndex(watchId)

::method latched guarded
  expose latches
  use strict arg watchId
  if latches~hasIndex(watchId) then return latches[watchId]
  return .false

::method rearm guarded
  expose registered latches
  use strict arg watchId
  if \registered~hasIndex(watchId) then return .false
  if \latches[watchId] then return .false
  self~appendRecord('S|'||watchId||'|0')
  latches[watchId]=.false
  return .true

::method enqueue guarded
  expose events order latches sequence registered
  use strict arg watch
  if \registered~hasIndex(watch~watchId) then -
    raise syntax 93.900 array('Cannot enqueue an unregistered watch')
  id='EV-'||right(sequence,8,'0')
  ev=.ContinuationEvent~new(id,watch~watchId,watch~target,watch~message)
  /* Append first. Do not expose an event that is not in the journal. */
  self~appendRecord('E|'||id||'|'||watch~watchId||'|'||watch~target||'|'||watch~message)
  sequence+=1
  events[id]=ev
  order~append(id)
  latches[watch~watchId]=.true
  return ev

::method pending guarded
  expose events order
  use strict arg now=.nil
  if now==.nil then now=.ContinuationClock~now
  do id over order
    ev=events[id]
    if ev~deliverable(now) then return ev
  end
  return .nil

::method claim guarded
  expose events
  use strict arg eventId,owner,now,seconds=45
  if \events~hasIndex(eventId) then return .false
  if owner='' | pos('|',owner)>0 | pos('0A'x,owner)>0 | pos('09'x,owner)>0 then return .false
  if \datatype(seconds,'W') then return .false
  if seconds<1 | seconds>300 then return .false
  ev=events[eventId]
  if ev~completed then return .false
  if \ev~deliverable(now) then do
    if ev~leaseOwner<>owner then return .false
  end
  until=now+seconds
  self~appendRecord('K|'||eventId||'|'||owner||'|'||until)
  ev~setLease(owner,until)
  return .true

::method receive guarded
  expose events
  use strict arg eventId,owner,now
  if \events~hasIndex(eventId) then return .false
  ev=events[eventId]
  if \ev~owned(owner,now) then return .false
  if ev~receiptOwner<>owner then do
    self~appendRecord('R|'||eventId||'|'||owner)
    ev~markReceived(owner)
  end
  return .true

::method complete guarded
  expose events
  use strict arg eventId,owner,now
  if \events~hasIndex(eventId) then return .false
  ev=events[eventId]
  if ev~completed then return ev~leaseOwner==owner
  if \ev~owned(owner,now) | ev~receiptOwner<>owner then return .false
  self~appendRecord('C|'||eventId||'|1')
  ev~markCompleted
  return .true

::class ContinuationCoordinator public
::attribute store get

::method init
  expose store watches eventSource
  use strict arg journalPath,eventSource=.nil
  eventSource=eventSource
  store=.ContinuationStore~new(journalPath)
  watches=store~registeredWatches

::method addWatch guarded
  expose watches store
  use strict arg watch
  if store~registerWatch(watch) then watches~append(watch)
  return self

::method hasWatch
  expose store
  use strict arg id
  return store~hasWatch(id)

::method tick guarded
  expose watches store eventSource
  results=.array~new
  do watch over watches
    ev=watch~sample(store)
    if ev<>.nil then do
      results~append(ev)
      if eventSource<>.nil then eventSource~emit('CONTINUATION.FIRED',ev~wire)
    end
  end
  return results

::method next
  expose store
  use strict arg now=.nil
  if now==.nil then now=.ContinuationClock~now
  return store~pending(now)

::method claim
  expose store
  use strict arg eventId,owner,now=.nil,seconds=45
  if now==.nil then now=.ContinuationClock~now
  return store~claim(eventId,owner,now,seconds)

::method receive
  expose store
  use strict arg eventId,owner,now=.nil
  if now==.nil then now=.ContinuationClock~now
  return store~receive(eventId,owner,now)

::method complete
  expose store
  use strict arg eventId,owner,now=.nil
  if now==.nil then now=.ContinuationClock~now
  return store~complete(eventId,owner,now)

::method run unguarded
  do forever
    ignored=self~tick
    call SysSleep 1
  end
