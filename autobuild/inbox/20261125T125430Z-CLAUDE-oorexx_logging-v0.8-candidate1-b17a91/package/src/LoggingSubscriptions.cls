/* Architecture: Tom Dyer. Coding: ChatGPT. */
/* Host-owned subscription lanes. Each is a real LogService target with a
   dedicated reviewed LogRule and independent capacity. No scope escalation,
   implicit priority from payload, or changes to LoggingCore. Critical lanes
   never evict unacknowledged records. Loss is sticky, separately counted. */
::class PriorityLogTarget public
::method init
  expose name scopeObject generation capacity priority producerClass methodName points ruleId records seq acked offered lost enabled lastIngress receiverId attemptedIngress handler quarantined recoveredLoss down
  use strict arg name, scopeObject, generation, capacity, priority, producerClass, methodName, points, ruleId, handler
  if \capacity~datatype('W') | capacity<1 | capacity>65536 then raise syntax 93.900 array ('Invalid capacity')
  if priority\=='CRITICAL' & priority\=='OPERATIONS' & priority\=='DIAGNOSTIC' then raise syntax 93.900 array ('Invalid priority')
  scopeObject=.Log~normalizeScope(scopeObject)
  if scopeObject~domainId=='' then raise syntax 93.900 array ('Exact logging domain required')
  points=points~copy; records=.Directory~new
  seq=0; acked=0; offered=0; lost=0; enabled=.true; lastIngress=''; receiverId=''; attemptedIngress=''; quarantined=.false; recoveredLoss=0; down=.false
::attribute name get
::attribute scopeObject get
::attribute generation get
::attribute priority get
::attribute ruleId get
::attribute enabled get
::method bindReceiver
  expose receiverId
  use strict arg producer
  if receiverId\=='' then raise syntax 93.900 array ('Receiver already bound')
  receiverId=producer~identityHash~string
  return self
::method accept
  expose enabled records seq capacity priority acked offered lost scopeObject ruleId producerClass methodName points lastIngress receiverId attemptedIngress handler quarantined recoveredLoss down
  use strict arg event
  numeric digits 25
  if \enabled | \event~isA(.LogEvent) then return .false
  if \scopeObject~equivalent(event~deliveryScopeObject) | \scopeObject~equivalent(event~sourceScopeObject) then return .false
  if receiverId=='' | event~receiverIdentity\==receiverId then return .false
  if event~ruleId\==ruleId | event~receiverClass\==producerClass | event~methodName\==methodName then return .false
  if points~hasItem(event~point)=.false then return .false
  attemptedIngress=event~eventId
  if records~items>=capacity then do
    lost+=1; quarantined=.true; self~notify('LOGGING_LOSS','capacity exceeded')
    if priority=='CRITICAL' then return .false
    /* Evict the oldest retained event, not an acknowledged event. */
    records~remove(seq-capacity+1)
  end
  seq+=1; records[seq]=event; lastIngress=event~eventId
  return .true
::attribute producerClass get
::attribute lastIngress get
::attribute attemptedIngress get
::method accepted
  expose lastIngress priority lost enabled
  use strict arg ingress
  return enabled & lastIngress==ingress & (priority\=='CRITICAL' | lost=0)
::method noteMissing
  expose attemptedIngress lost quarantined
  use strict arg ingress
  numeric digits 25
  if attemptedIngress\==ingress then do; lost+=1; attemptedIngress=ingress; quarantined=.true; self~notify('LOGGING_LOSS','required delivery missing'); end
  return self
::method page
  expose records seq capacity generation acked offered lost enabled priority quarantined recoveredLoss
  use strict arg expectedGeneration, after, limit=128
  numeric digits 25
  if expectedGeneration\==generation then raise syntax 93.900 array ('Target incarnation changed')
  if \after~datatype('W') | after<0 | after>seq | \limit~datatype('W') | limit<1 | limit>1024 then raise syntax 93.900 array ('Invalid cursor or limit')
  first=max(acked+1,seq-records~items+1); next=max(after,first-1); rows=.Array~new
  do i=next+1 to min(seq,next+limit); rows~append(records[i]); next=i; end
  if after==acked then offered=max(offered,next)
  r=.Directory~new; r['GENERATION']=generation; r['NEXT']=next; r['LATEST']=seq; r['FIRST']=first
  r['GAP']=after<first-1 | lost>0; r['QUARANTINED']=quarantined; r['RECOVERED_LOSS']=recoveredLoss; r['LOST']=lost; r['ENABLED']=enabled; r['EVENTS']=rows
  r['ACKED']=acked; r['PRIORITY']=priority
  return r
::method read
  expose generation acked
  use strict arg limit=128
  return self~page(generation,acked,limit)
::method ack
  expose generation records seq acked offered
  use strict arg expectedGeneration, through
  numeric digits 25
  if expectedGeneration\==generation then raise syntax 93.900 array ('Target incarnation changed')
  if \through~datatype('W') | through<acked | through>offered then raise syntax 93.900 array ('Cannot acknowledge unseen events')
  do i over records~allIndexes
    if i<=through then records~remove(i)
  end
  acked=through
  return acked
::method pending
  expose records
  return records~items
::method status
  expose generation capacity priority records lost enabled acked seq quarantined recoveredLoss
  r=.Directory~new; r['GENERATION']=generation; r['CAPACITY']=capacity; r['PRIORITY']=priority
  r['QUARANTINED']=quarantined; r['RECOVERED_LOSS']=recoveredLoss; r['PENDING']=records~items; r['LOST']=lost; r['ACKED']=acked; r['LATEST']=seq; r['ENABLED']=enabled
  return r
::method enable
  /* LogService target enable is not evidence reconciliation. */
  expose enabled
  enabled=.true; return self
::method notify private
  expose handler name generation lost quarantined down
  use strict arg kind, reason
  if kind=='LOGGING_LANE_DOWN' then do
    quarantined=.true
    if down then return self
    down=.true
  end
  e=.Directory~new; e['KIND']=kind; e['LANE']=name; e['GENERATION']=generation; e['LOST']=lost; e['REASON']=reason
  handler~receive(e)
::method rearm
  expose handler quarantined lost recoveredLoss enabled records capacity down
  use strict arg authority, expectedLoss, reason
  if authority\==handler | expectedLoss\=lost | reason=='' | \enabled | records~items>=capacity then raise syntax 93.900 array ('Recovery refused')
  self~notify('LOGGING_REARM',reason)
  recoveredLoss=lost; quarantined=.false; down=.false
  return self
::method markDown
  use strict arg reason
  self~notify('LOGGING_LANE_DOWN',reason)
  return self
::method disable
  expose enabled
  enabled=.false; self~notify('LOGGING_LANE_DOWN','disabled'); return self

/* Registration is configuration-time, on a trusted host. Register before
   binding a producer; rule IDs and target names cannot replace existing ones.
   One producer instance per registered class per registry, one acknowledged consumer per lane.
   No automatic disabling of reviewed logging rules under pressure. */
::class LogSubscriptions public
::method init
  expose service scope lanes byKey bound budget reserved handler
  use strict arg service, scope, budget=4096, handler=.nil
  if handler==.nil then handler=.LogOperationalHandler~new
  if \service~isA(.LogService) then raise syntax 93.900 array ('LogService required')
  scope=.Log~normalizeScope(scope)
  if scope~domainId=='' then raise syntax 93.900 array ('Exact logging domain required')
  if \budget~datatype('W') | budget<1 | budget>65536 then raise syntax 93.900 array ('Invalid aggregate budget')
  lanes=.Directory~new; byKey=.Directory~new; bound=.Directory~new; reserved=0
::method register
  expose service scope lanes byKey bound budget reserved handler
  use strict arg name, generation, producerClass, methodName, points, priority, capacity
  if bound~items>0 then raise syntax 93.900 array ('Register before binding')
  if lanes~items>=64 then raise syntax 93.900 array ('Subscription limit')
  if \capacity~datatype('W') | capacity<1 | capacity>budget-reserved then raise syntax 93.900 array ('Subscription capacity budget exceeded')
  do v over .Array~of(name,generation)
    if \v~isA(.String) | v~length<1 | v~length>64 | v~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.')>0 then raise syntax 93.900 array ('Invalid name or generation')
  end
  methodName=methodName~translate; priority=priority~translate
  producerClass=producerClass~translate
  do v over .Array~of(producerClass,methodName)
    if v=='' | v~length>128 | v~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_')>0 then raise syntax 93.900 array ('Invalid producer selector')
  end
  if \points~isA(.Array) then raise syntax 93.900 array ('Explicit event kinds required')
  if points~items<1 | points~items>128 | points~size\=points~items then raise syntax 93.900 array ('Invalid event kinds')
  normalized=.Array~new
  do point over points
    if \point~isA(.String) | point~length<1 | point~length>64 then raise syntax 93.900 array ('Invalid event kind')
    point=point~translate
    if point~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_')>0 | normalized~hasItem(point) then raise syntax 93.900 array ('Invalid or duplicate event kind')
    normalized~append(point)
  end
  targetName='LS-'name; ruleId='LS-'name
  if service~target(targetName)\==.nil then raise syntax 93.900 array ('Target name already registered')
  do rule over service~rulesSnapshot
    if rule~ruleId~translate==ruleId~translate then raise syntax 93.900 array ('Rule name already registered')
  end
  t=.PriorityLogTarget~new(targetName,scope,generation,capacity,priority,producerClass,methodName,normalized,ruleId,handler)
  rule=.LogRule~new(ruleId,'subscriptions',producerClass,methodName,scope,scope,.Log~INFO,.nil,.Array~of(targetName),normalized)
  service~addTarget(t); service~addRule(rule)
  lanes[name]=t; reserved+=capacity
  do point over normalized
    key=producerClass'|'methodName'|'point
    if \byKey~hasIndex(key) then byKey[key]=.Array~new
    byKey[key]~append(t)
  end
  return t
::method bind
  expose service scope bound lanes
  use strict arg svc, s, producer
  cls=producer~class~id
  if svc\==service | \scope~equivalent(s) | bound~hasIndex(cls) then raise syntax 93.900 array ('Wrong or previously bound producer class')
  matched=.false
  do target over lanes~allItems; if target~producerClass==cls then do; target~bindReceiver(producer); matched=.true; end; end
  if \matched then raise syntax 93.900 array ('No registered producer class')
  bound[cls]=producer
  return self
::method wants
  expose byKey
  use strict arg producerClass, methodName, point
  return byKey~hasIndex(producerClass~translate'|'methodName~translate'|'point~translate)
::method publish
  expose byKey service scope bound
  use strict arg producer, methodName, point, payload, level=(.Log~INFO)
  if bound[producer~class~id]\==producer then return .false
  key=producer~class~id'|'methodName~translate'|'point~translate
  if \byKey~hasIndex(key) then return .false
  before=.Directory~new; attempts=.Directory~new
  do target over byKey[key]
    if service~target(target~name)\==target | \service~ruleOperational(target~ruleId) then target~markDown('logging route not operational')
    before[target~name]=target~lastIngress; attempts[target~name]=target~attemptedIngress
  end
  log=service~loggerFor(producer,methodName,.Array~new,scope)
  delivered=log~log(level,payload,point)
  any=.false; required=.true
  do target over byKey[key]
    accepted=service~target(target~name)==target & target~lastIngress\==before[target~name]
    if \accepted & target~attemptedIngress==attempts[target~name] then target~noteMissing(target~attemptedIngress||':missing:'||target~status['LOST'])
    if target~priority=='CRITICAL' & (\accepted | target~status['QUARANTINED']) then required=.false
    any=any | accepted
  end
  return delivered & any & required
::method pollState
  expose service lanes
  do target over lanes~allItems
    if service~target(target~name)\==target | \service~ruleOperational(target~ruleId) then target~markDown('logging route not operational')
  end
  return self
::method rearm
  expose service lanes handler
  use strict arg authority,name,expectedLoss,reason
  if authority\==handler | \lanes~hasIndex(name) then raise syntax 93.900 array ('Recovery authority refused')
  target=lanes[name]
  if service~target(target~name)\==target | \service~ruleOperational(target~ruleId) then raise syntax 93.900 array ('Route is not operational')
  return target~rearm(authority,expectedLoss,reason)
::method next
  expose lanes
  use strict arg limit=128
  self~pollState
  /* Strict priority; no cross-lane chronological ordering claim. */
  do priority over .Array~of('CRITICAL','OPERATIONS','DIAGNOSTIC')
    do name over lanes~allIndexes~sort
      t=lanes[name]
      if t~priority\==priority | t~pending=0 then iterate
      r=t~read(limit); r['SUBSCRIPTION']=name; return r
    end
  end
  r=.Directory~new; r['EVENTS']=.Array~new; r['SUBSCRIPTION']=''; return r
::method status
  expose lanes
  self~pollState
  r=.Directory~new
  do name over lanes~allIndexes; r[name]=lanes[name]~status; end
  return r

/* Out-of-band, in-process control evidence; a host can subclass RECEIVE to
   forward to its operational handler. No LogService call or failed lane. */
::class LogOperationalHandler public
::method init
  expose events dropped
  events=.Queue~new; dropped=0
::method receive
  expose events dropped
  use strict arg event
  if events~items>=1024 then do; events~pull; dropped+=1; end
  events~queue(event~copy)
  return self
::method events
  expose events
  rows=.Array~new
  do event over events~allItems; rows~append(event~copy); end
  return rows
::attribute dropped get
::requires 'LoggingCore.cls'
