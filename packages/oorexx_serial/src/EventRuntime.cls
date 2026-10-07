/*----------------------------------------------------------------------------*/
/* ooRexx Event Runtime v0.1-dev1                                             */
/* Typed events, registrations, subscriptions and triggers.                   */
/*----------------------------------------------------------------------------*/

::class EventRuntimeBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "event.runtime/0.1"

::class Event public
::attribute sequence get
::attribute type get
::attribute sourceId get
::attribute occurredAt get
::attribute data get
::attribute metadata get

::method init
  expose sequence type sourceId occurredAt data metadata
  use strict arg sequenceArg, typeArg, sourceIdArg, dataArg=.nil, metadataArg=.nil, occurredAtArg=""
  sequence=sequenceArg+0
  type=typeArg~string~upper
  sourceId=sourceIdArg~string
  occurredAt=occurredAtArg~string
  if occurredAt="" then occurredAt=date('S')||"T"||time('L')
  data=dataArg
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg~copy

::method metadataValue
  expose metadata
  use strict arg name, default=.nil
  key=name~string
  if metadata~hasIndex(key) then return metadata[key]
  return default

::method copyDetached
  expose sequence type sourceId occurredAt data metadata
  detached=data
  if data<>.nil then if data~hasMethod('COPYDETACHED') then detached=data~copyDetached
  return .Event~new(sequence,type,sourceId,detached,metadata,occurredAt)

::class EventFilter public
::attribute types get
::attribute sourceId get
::attribute predicate get

::method init
  expose types sourceId predicate
  use strict arg typesArg=.nil, sourceIdArg="", predicateArg=.nil
  types=.array~new
  if typesArg<>.nil then do
    if typesArg~isA(.array) then do t over typesArg; types~append(t~string~upper); end
    else types~append(typesArg~string~upper)
  end
  sourceId=sourceIdArg~string
  predicate=predicateArg

::method matches
  expose types sourceId predicate
  use strict arg event
  if event==.nil then return .false
  if types~items>0 then do
    matched=.false
    do t over types
      if event~type==t then do; matched=.true; leave; end
    end
    if \matched then return .false
  end
  if sourceId<>"" & event~sourceId<>sourceId then return .false
  if predicate<>.nil then do
    if \predicate~hasMethod('ACCEPTS') then return .false
    if \predicate~accepts(event) then return .false
  end
  return .true

::class EventRegistration public
::attribute registrationId get
::attribute kind get
::attribute target get
::attribute messageName get
::attribute filter get
::attribute delivery get
::attribute enabled
::attribute fireCount get
::attribute lastSequence get
::attribute lastEvent get
::attribute createdAt get

::method init
  expose registrationId kind target messageName filter delivery enabled fireCount lastSequence lastEvent createdAt
  use strict arg idArg, kindArg, targetArg, messageArg, filterArg=.nil, deliveryArg='SYNC'
  registrationId=idArg~string
  kind=kindArg~string~upper
  target=targetArg
  messageName=messageArg~string~upper
  if filterArg==.nil then filter=.EventFilter~new
  else filter=filterArg
  delivery=deliveryArg~string~upper
  if delivery<>"SYNC" & delivery<>"ASYNC" then raise syntax 93.900 array('delivery must be SYNC or ASYNC')
  enabled=.true
  fireCount=0
  lastSequence=0
  lastEvent=.nil
  createdAt=date('S')||"T"||time('L')

::method recordDelivery guarded
  expose fireCount lastSequence lastEvent
  use strict arg event
  fireCount+=1
  lastSequence=event~sequence
  lastEvent=event~copyDetached
  return fireCount

::method disable guarded
  expose enabled
  enabled=.false
  return self

::method enable guarded
  expose enabled
  enabled=.true
  return self

::method matches guarded
  expose enabled filter
  use strict arg event
  if \enabled then return .false
  return filter~matches(event)

::class EventDispatchResult public
::attribute event get
::attribute registrationIds get
::attribute messages get

::method init
  expose event registrationIds messages
  use strict arg eventArg
  event=eventArg~copyDetached
  registrationIds=.array~new
  messages=.array~new

::method addDelivery
  expose registrationIds messages
  use strict arg registrationId, message=.nil
  registrationIds~append(registrationId~string)
  if message<>.nil then messages~append(message)
  return self

::class EventDispatcher public
::method init
  expose registrations nextRegistration
  registrations=.directory~new
  nextRegistration=1

::method subscribe guarded
  use strict arg target, messageName, filter=.nil, delivery='SYNC'
  return self~register('SUBSCRIPTION',target,messageName,filter,delivery)

::method registerTrigger guarded
  use strict arg target, messageName, filter=.nil, delivery='ASYNC'
  return self~register('TRIGGER',target,messageName,filter,delivery)

::method register private
  expose registrations nextRegistration
  use strict arg kind,target,messageName,filter,delivery
  if target==.nil then raise syntax 93.900 array('event target is required')
  if \target~hasMethod(messageName~string) then raise syntax 93.900 array('event target does not implement '||messageName)
  id='EVENT-REG-'||nextRegistration
  nextRegistration+=1
  reg=.EventRegistration~new(id,kind,target,messageName,filter,delivery)
  registrations[id]=reg
  return reg

::method unregister guarded
  expose registrations
  use strict arg idOrRegistration
  if idOrRegistration~isA(.EventRegistration) then id=idOrRegistration~registrationId
  else id=idOrRegistration~string
  if \registrations~hasIndex(id) then return .false
  registrations~remove(id)
  return .true

::method registrations guarded
  expose registrations
  out=.array~new
  do id over registrations; out~append(registrations[id]); end
  return out

::method publish guarded
  expose registrations
  use strict arg event

  /* Snapshot the registrations while holding this object's guard, then release
     it before application code runs.  A callback may therefore register or
     unregister other handlers without deadlocking the dispatcher. */
  selected=.array~new
  do id over registrations
    reg=registrations[id]
    if reg~matches(event) then selected~append(reg)
  end
  guard off

  dispatchResult=.EventDispatchResult~new(event)
  do reg over selected
    reg~recordDelivery(event)
    args=.array~of(event~copyDetached)
    if reg~delivery=='ASYNC' then do
      /* Object~startWith() is asynchronous and returns the Message object. */
      msg=reg~target~startWith(reg~messageName,args)
      dispatchResult~addDelivery(reg~registrationId,msg)
    end
    else do
      /* Object~sendWith() is deliberately synchronous. */
      reg~target~sendWith(reg~messageName,args)
      dispatchResult~addDelivery(reg~registrationId)
    end
  end
  return dispatchResult

::class EventBinding public
::method init
  expose dispatcher filter
  use strict arg dispatcherArg, filterArg
  dispatcher=dispatcherArg
  filter=filterArg

::method notify
  expose dispatcher filter
  use strict arg target, messageName, delivery='SYNC'
  return dispatcher~subscribe(target,messageName,filter,delivery)

::method fire
  expose dispatcher filter
  use strict arg target, messageName, delivery='ASYNC'
  return dispatcher~registerTrigger(target,messageName,filter,delivery)

::class EventSource public
::attribute sourceId get
::attribute dispatcher get

::method init
  expose sourceId dispatcher nextSequence
  use strict arg sourceIdArg, dispatcherArg=.nil
  sourceId=sourceIdArg~string
  if dispatcherArg==.nil then dispatcher=.EventDispatcher~new
  else dispatcher=dispatcherArg
  nextSequence=1

::method when
  expose dispatcher
  use strict arg filter
  if filter==.nil then filter=.EventFilter~new
  return .EventBinding~new(dispatcher,filter)

::method on
  expose dispatcher sourceId
  use strict arg eventType,target,messageName,delivery='SYNC'
  filter=.EventFilter~new(eventType,sourceId)
  return dispatcher~subscribe(target,messageName,filter,delivery)

::method emit guarded
  expose sourceId dispatcher nextSequence
  use strict arg eventType,data=.nil,metadata=.nil
  event=.Event~new(nextSequence,eventType,sourceId,data,metadata)
  nextSequence+=1
  /* Do not hold the EventSource guard while arbitrary callbacks execute. */
  guard off
  return dispatcher~publish(event)
