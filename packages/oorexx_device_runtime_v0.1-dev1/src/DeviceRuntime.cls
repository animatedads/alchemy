/*----------------------------------------------------------------------------*/
/* ooRexx Device Runtime v0.1-dev1                                            */
/* Provider-neutral device identity, events, subscriptions and triggers.      */
/*----------------------------------------------------------------------------*/

::class DeviceRuntimeBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "device.runtime/0.1"

::class DeviceIdentity public
::attribute key get
::attribute provider get
::attribute subsystem get
::attribute sysname get
::attribute syspath get
::attribute devnode get
::attribute devtype get
::attribute properties get

::method init
  expose key provider subsystem sysname syspath devnode devtype properties
  use strict arg keyArg, providerArg, subsystemArg="", sysnameArg="", syspathArg="", devnodeArg="", devtypeArg="", propertiesArg=.nil
  key=keyArg~string
  provider=providerArg~string
  subsystem=subsystemArg~string
  sysname=sysnameArg~string
  syspath=syspathArg~string
  devnode=devnodeArg~string
  devtype=devtypeArg~string
  if propertiesArg==.nil then properties=.directory~new
  else properties=propertiesArg~copy

::method property
  expose properties
  use strict arg name, default=.nil
  if properties~hasIndex(name~string) then return properties[name~string]
  return default

::method copyDetached
  expose key provider subsystem sysname syspath devnode devtype properties
  return .DeviceIdentity~new(key,provider,subsystem,sysname,syspath,devnode,devtype,properties)

::method string
  expose key subsystem sysname devnode
  text=subsystem||":"||sysname
  if devnode<>"" then text=text||" "||devnode
  if key<>"" then text=text||" ["||key||"]"
  return text


::class DeviceEvent public
::attribute sequence get
::attribute kind get
::attribute device get
::attribute provider get
::attribute observedAt get
::attribute metadata get

::method init
  expose sequence kind device provider observedAt metadata
  use strict arg sequenceArg, kindArg, deviceArg, providerArg="", observedAtArg="", metadataArg=.nil
  sequence=sequenceArg+0
  kind=kindArg~string~upper
  device=deviceArg
  provider=providerArg~string
  observedAt=observedAtArg~string
  if observedAt="" then observedAt=date('S')||"T"||time('L')
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg~copy

::method copyDetached
  expose sequence kind device provider observedAt metadata
  d=.nil
  if device<>.nil then d=device~copyDetached
  return .DeviceEvent~new(sequence,kind,d,provider,observedAt,metadata)

::method string
  expose sequence kind device provider observedAt
  if device==.nil then return sequence kind provider observedAt
  return sequence kind device~string observedAt


::class DeviceEventFilter public
::attribute kinds get
::attribute subsystem get
::attribute provider get
::attribute propertyName get
::attribute propertyValue get

::method init
  expose kinds subsystem provider propertyName propertyValue
  use strict arg kindsArg=.nil, subsystemArg="", providerArg="", propertyNameArg="", propertyValueArg=.nil
  kinds=.array~new
  if kindsArg<>.nil then do
    if kindsArg~isA(.array) then do k over kindsArg; kinds~append(k~string~upper); end
    else kinds~append(kindsArg~string~upper)
  end
  subsystem=subsystemArg~string~upper
  provider=providerArg~string~upper
  propertyName=propertyNameArg~string
  propertyValue=propertyValueArg

::method matches
  expose kinds subsystem provider propertyName propertyValue
  use strict arg event
  if event==.nil then return .false
  if kinds~items>0 then do
    found=.false
    do k over kinds
      if event~kind==k then do; found=.true; leave; end
    end
    if \found then return .false
  end
  if provider<>"" & event~provider~upper<>provider then return .false
  d=event~device
  if subsystem<>"" then do
    if d==.nil then return .false
    if d~subsystem~upper<>subsystem then return .false
  end
  if propertyName<>"" then do
    if d==.nil then return .false
    actual=d~property(propertyName,.nil)
    if actual==.nil then return .false
    if propertyValue<>.nil & actual~string<>propertyValue~string then return .false
  end
  return .true


::class DeviceSubscription public
::attribute subscriptionId get
::attribute filter get
::attribute observer get
::attribute active

::method init
  expose subscriptionId filter observer active
  use strict arg idArg, observerArg, filterArg=.nil
  subscriptionId=idArg~string
  observer=observerArg
  if filterArg==.nil then filter=.DeviceEventFilter~new
  else filter=filterArg
  active=.true

::method cancel
  expose active
  active=.false
  return .true


::class DeviceTrigger public
::attribute triggerId get
::attribute filter get
::attribute action get
::attribute enabled
::attribute fireCount get

::method init
  expose triggerId filter action enabled fireCount
  use strict arg idArg, actionArg, filterArg=.nil
  triggerId=idArg~string
  action=actionArg
  if filterArg==.nil then filter=.DeviceEventFilter~new
  else filter=filterArg
  enabled=.true
  fireCount=0

::method matches
  expose enabled filter
  use strict arg event
  if \enabled then return .false
  return filter~matches(event)

::method fire
  expose action fireCount
  use strict arg event
  if action==.nil then return .false
  if \action~hasMethod('ONDEVICETRIGGER') then return .false
  action~onDeviceTrigger(self,event)
  fireCount+=1
  return .true


::class DeviceEventBus public
::method init
  expose subscriptions triggers nextSubscription
  subscriptions=.directory~new
  triggers=.directory~new
  nextSubscription=1

::method subscribe
  expose subscriptions nextSubscription
  use strict arg observer, filter=.nil
  if observer==.nil | \observer~hasMethod('ONDEVICEEVENT') then raise syntax 93.900 array('observer must implement ONDEVICEEVENT')
  id='DEVICE-SUB-'||nextSubscription
  nextSubscription+=1
  sub=.DeviceSubscription~new(id,observer,filter)
  subscriptions[id]=sub
  return sub

::method unsubscribe
  expose subscriptions
  use strict arg idOrSubscription
  if idOrSubscription~isA(.DeviceSubscription) then id=idOrSubscription~subscriptionId
  else id=idOrSubscription~string
  if \subscriptions~hasIndex(id) then return .false
  subscriptions[id]~cancel
  subscriptions~remove(id)
  return .true

::method registerTrigger
  expose triggers
  use strict arg trigger
  if trigger==.nil then raise syntax 93.900 array('trigger is required')
  triggers[trigger~triggerId]=trigger
  return trigger

::method removeTrigger
  expose triggers
  use strict arg triggerId
  id=triggerId~string
  if \triggers~hasIndex(id) then return .false
  triggers~remove(id)
  return .true

::method publish
  expose subscriptions triggers
  use strict arg event
  fired=.array~new
  do id over subscriptions
    sub=subscriptions[id]
    if sub~active & sub~filter~matches(event) then sub~observer~onDeviceEvent(event~copyDetached)
  end
  do id over triggers
    trigger=triggers[id]
    if trigger~matches(event) then do
      if trigger~fire(event~copyDetached) then fired~append(trigger~triggerId)
    end
  end
  return fired


::class DeviceProvider public mixinclass Object
::method providerId abstract
::method enumerate abstract
::method start abstract
::method pollEvent abstract
::method stop abstract


/* Detached snapshot implementing the read-only snapshot side of Observation. */
::class DeviceMonitorSnapshot public
::attribute generation get
::attribute terminalType get
::attribute event get
::attribute visibleText get
::attribute contentDigest get

::method init
  expose generation terminalType event visibleText contentDigest
  use strict arg generationArg, eventArg
  generation=generationArg+0
  terminalType='DEVICE_EVENT'
  event=eventArg~copyDetached
  d=event~device
  if d==.nil then visibleText=event~kind||' provider='||event~provider
  else do
    visibleText=event~kind||' subsystem='||d~subsystem||' sysname='||d~sysname
    if d~devnode<>'' then visibleText=visibleText||' devnode='||d~devnode
    visibleText=visibleText||' syspath='||d~syspath
  end
  /* Observation uses equality, not cryptographic trust, for contentDigest. */
  contentDigest=generation||'|'||visibleText

::method copyDetached
  expose generation event
  return .DeviceMonitorSnapshot~new(generation,event)


/* DeviceMonitor is deliberately Observation-compatible by duck typing. */
::class DeviceMonitor public
::attribute sessionId get
::attribute terminalType get
::attribute deviceName get
::attribute provider get
::attribute eventBus get
::attribute generation get

::method init
  expose sessionId terminalType deviceName provider eventBus generation snapshots retention started
  use strict arg providerArg, sessionIdArg='DEVICE-MONITOR', retentionArg=256
  provider=providerArg
  sessionId=sessionIdArg~string
  terminalType='DEVICE_EVENT'
  deviceName=provider~providerId
  eventBus=.DeviceEventBus~new
  generation=0
  snapshots=.array~new
  retention=retentionArg+0
  if retention<1 then retention=1
  started=.false

::method enumerate
  expose provider
  use strict arg subsystem=''
  return provider~enumerate(subsystem)

::method start
  expose provider started
  use strict arg subsystem=''
  if started then return .true
  started=provider~start(subsystem)
  return started

::method stop
  expose provider started
  if \started then return .true
  rc=provider~stop
  started=.false
  return rc

::method poll
  expose provider eventBus generation snapshots retention started
  use strict arg timeoutMs=0
  if \started then do
    if \self~start then return .nil
  end
  event=provider~pollEvent(timeoutMs)
  if event==.nil then return .nil
  generation+=1
  runtimeEvent=.DeviceEvent~new(generation,event~kind,event~device,event~provider,event~observedAt,event~metadata)
  snap=.DeviceMonitorSnapshot~new(generation,runtimeEvent)
  snapshots~append(snap)
  do while snapshots~items>retention; snapshots~remove(1); end
  eventBus~publish(runtimeEvent)
  return runtimeEvent~copyDetached

::method snapshot
  expose snapshots
  if snapshots~items=0 then return .nil
  return snapshots[snapshots~items]~copyDetached

::method current
  return self~snapshot

::method back
  expose snapshots
  use strict arg distance=1
  index=snapshots~items-(distance+0)
  if index<1 then return .nil
  return snapshots[index]~copyDetached

::method history
  expose snapshots
  out=.array~new
  do snap over snapshots; out~append(snap~copyDetached); end
  return out

::method knownStateStatus
  if self~snapshot==.nil then return 'EMPTY'
  return 'CURRENT'

::method knownStateId
  snap=self~snapshot
  if snap==.nil then return ''
  if snap~event~device==.nil then return snap~event~provider
  return snap~event~device~key

::method knownStateGeneration
  expose generation
  return generation

::method knownStateHistory
  return self~history
