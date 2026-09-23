/*----------------------------------------------------------------------------*/
/* ooRexx Bluetooth v0.1-dev1                                                 */
/* Provider-neutral Bluetooth object model with event-first application API.   */
/*----------------------------------------------------------------------------*/

::class BluetoothBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "bluetooth/0.1"
::constant PROFILE_SCHEMA "oorexx.bluetooth.profile/0.1"

::class BluetoothEvents public
::constant DEVICE_DISCOVERED "BLUETOOTH.DEVICE.DISCOVERED"
::constant DEVICE_LOST "BLUETOOTH.DEVICE.LOST"
::constant DEVICE_CONNECTED "BLUETOOTH.DEVICE.CONNECTED"
::constant DEVICE_DISCONNECTED "BLUETOOTH.DEVICE.DISCONNECTED"
::constant DEVICE_PAIRED "BLUETOOTH.DEVICE.PAIRED"
::constant RSSI_CHANGED "BLUETOOTH.RSSI.CHANGED"
::constant GATT_VALUE_CHANGED "BLUETOOTH.GATT.VALUE.CHANGED"
::constant GATT_SERVICES_CHANGED "BLUETOOTH.GATT.SERVICES.CHANGED"

::class BluetoothAddressEvidence public
::attribute address get
::attribute addressType get
::attribute observedAt get
::attribute source get

::method init
  expose address addressType observedAt source
  use strict arg addressArg,addressTypeArg="UNKNOWN",sourceArg=""
  address=addressArg~string~upper
  addressType=addressTypeArg~string~upper
  source=sourceArg~string
  observedAt=date('S')||"T"||time('L')

::method copyDetached
  expose address addressType source
  return .BluetoothAddressEvidence~new(address,addressType,source)

::class BluetoothIdentity public
::attribute key get
::attribute provider get
::attribute name
::attribute kind
::attribute address get
::attribute addressType get
::attribute properties get
::attribute addressEvidence get

::method init
  expose key provider name kind address addressType properties addressEvidence
  use strict arg keyArg,providerArg,nameArg="",kindArg="UNKNOWN",addressArg="",addressTypeArg="UNKNOWN",propertiesArg=.nil
  key=keyArg~string
  provider=providerArg~string
  name=nameArg~string
  kind=kindArg~string~upper
  address=addressArg~string~upper
  addressType=addressTypeArg~string~upper
  if propertiesArg==.nil then properties=.directory~new
  else properties=propertiesArg~copy
  addressEvidence=.array~new
  if address<>"" then addressEvidence~append(.BluetoothAddressEvidence~new(address,addressType,provider))

::method observeAddress guarded
  expose address addressType addressEvidence
  use strict arg addressArg,addressTypeArg="UNKNOWN",sourceArg=""
  address=addressArg~string~upper
  addressType=addressTypeArg~string~upper
  ev=.BluetoothAddressEvidence~new(address,addressType,sourceArg)
  addressEvidence~append(ev)
  return ev

::method property
  expose properties
  use strict arg nameArg,default=.nil
  name=nameArg~string
  if properties~hasIndex(name) then return properties[name]
  return default

::method copyDetached
  expose key provider name kind address addressType properties
  return .BluetoothIdentity~new(key,provider,name,kind,address,addressType,properties)

::class BluetoothProviderEvent public
::attribute type get
::attribute deviceKey get
::attribute identity get
::attribute serviceUuid get
::attribute characteristicUuid get
::attribute value get
::attribute metadata get

::method init
  expose type deviceKey identity serviceUuid characteristicUuid value metadata
  use strict arg typeArg,deviceKeyArg="",identityArg=.nil,serviceArg="",characteristicArg="",valueArg=.nil,metadataArg=.nil
  type=typeArg~string~upper
  deviceKey=deviceKeyArg~string
  identity=identityArg
  serviceUuid=serviceArg~string~lower
  characteristicUuid=characteristicArg~string~lower
  value=valueArg
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg~copy

::class BluetoothEventData public
::attribute device get
::attribute service get
::attribute characteristic get
::attribute value get
::attribute previousValue get
::attribute metadata get

::method init
  expose device service characteristic value previousValue metadata
  use strict arg deviceArg=.nil,serviceArg=.nil,characteristicArg=.nil,valueArg=.nil,previousArg=.nil,metadataArg=.nil
  device=deviceArg
  service=serviceArg
  characteristic=characteristicArg
  value=valueArg
  previousValue=previousArg
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg~copy

::class BluetoothProvider public mixinclass Object
::method providerId abstract
::method enumerateAdapters abstract
::method enumerateDevices abstract
::method startDiscovery abstract
::method stopDiscovery abstract
::method pollEvent abstract
::method connectDevice abstract
::method disconnectDevice abstract
::method pairDevice abstract
::method discoverServices abstract
::method readCharacteristic abstract
::method writeCharacteristic abstract
::method setCharacteristicNotify abstract

/*----------------------------------------------------------------------------*/
/* Semantic profile map.  UUIDs stay below the application-facing vocabulary. */
/*----------------------------------------------------------------------------*/
::class BluetoothProfileMap public
::method init
  expose serviceByName serviceNameByUuid characteristicByKey characteristicNameByKey
  serviceByName=.directory~new
  serviceNameByUuid=.directory~new
  characteristicByKey=.directory~new
  characteristicNameByKey=.directory~new

::method addService guarded
  expose serviceByName serviceNameByUuid
  use strict arg nameArg,uuidArg
  name=nameArg~string
  uuid=_btUuid(uuidArg)
  serviceByName[name~upper]=uuid
  serviceNameByUuid[uuid]=name
  return self

::method addCharacteristic guarded
  expose characteristicByKey characteristicNameByKey
  use strict arg serviceArg,nameArg,uuidArg
  serviceUuid=self~serviceUuid(serviceArg)
  if serviceUuid=="" then serviceUuid=_btUuid(serviceArg)
  name=nameArg~string
  uuid=_btUuid(uuidArg)
  key=serviceUuid||"|"||name~upper
  characteristicByKey[key]=uuid
  characteristicNameByKey[serviceUuid||"|"||uuid]=name
  return self

::method serviceUuid guarded
  expose serviceByName
  use strict arg nameOrUuid
  key=nameOrUuid~string
  if serviceByName~hasIndex(key~upper) then return serviceByName[key~upper]
  if _btLooksLikeUuid(key) then return _btUuid(key)
  return ""

::method serviceName guarded
  expose serviceNameByUuid
  use strict arg uuidArg
  uuid=_btUuid(uuidArg)
  if serviceNameByUuid~hasIndex(uuid) then return serviceNameByUuid[uuid]
  return uuid

::method characteristicUuid guarded
  expose characteristicByKey
  use strict arg serviceArg,nameOrUuid
  serviceUuid=self~serviceUuid(serviceArg)
  if serviceUuid=="" then serviceUuid=_btUuid(serviceArg)
  key=nameOrUuid~string
  mapKey=serviceUuid||"|"||key~upper
  if characteristicByKey~hasIndex(mapKey) then return characteristicByKey[mapKey]
  if _btLooksLikeUuid(key) then return _btUuid(key)
  return ""

::method standard class
  map=.BluetoothProfileMap~new
  map~addService('genericAccess','1800')
  map~addService('deviceInformation','180a')
  map~addService('batteryService','180f')
  map~addService('environmentalSensing','181a')
  map~addCharacteristic('batteryService','batteryLevel','2a19')
  map~addCharacteristic('environmentalSensing','temperature','2a6e')
  map~addCharacteristic('environmentalSensing','humidity','2a6f')
  map~addCharacteristic('deviceInformation','manufacturerName','2a29')
  map~addCharacteristic('deviceInformation','modelNumber','2a24')
  return map

::class BluetoothProfileMapLoader public
::method loadFile
  use strict arg path
  s=.stream~new(path)
  st=s~open('read')
  if st~left(6)<>"READY:" then return .nil
  text=s~charin(1,s~chars); s~close
  return self~loadText(text)

::method loadText
  use strict arg text
  doc=.json~fromJSON(text)
  if \fragmentHas(doc,'schema') then return .nil
  if doc['schema']<>.BluetoothBuild~PROFILE_SCHEMA then return .nil
  map=.BluetoothProfileMap~new
  if fragmentHas(doc,'services') then do service over doc['services']
    map~addService(service['name'],service['uuid'])
    if fragmentHas(service,'characteristics') then do characteristic over service['characteristics']
      map~addCharacteristic(service['name'],characteristic['name'],characteristic['uuid'])
    end
  end
  return map

/*----------------------------------------------------------------------------*/
/* Domain objects.                                                            */
/*----------------------------------------------------------------------------*/
::class BluetoothRuntime public
::attribute provider get
::attribute profileMap get
::attribute eventSource get

::method init
  expose provider profileMap eventSource devices adapters discoveryRunning
  use strict arg providerArg,profileMapArg=.nil
  provider=providerArg
  if profileMapArg==.nil then profileMap=.BluetoothProfileMap~standard
  else profileMap=profileMapArg
  eventSource=.EventSource~new('bluetooth:'||provider~providerId)
  devices=.directory~new
  adapters=.directory~new
  discoveryRunning=.false

::method adapters guarded
  expose provider adapters
  native=provider~enumerateAdapters
  do a over native; adapters[a~key]=a; end
  out=.array~new; do k over adapters; out~append(adapters[k]); end
  return out

::method devices guarded
  expose provider devices profileMap
  native=provider~enumerateDevices
  do identity over native
    key=identity~key
    if devices~hasIndex(key) then devices[key]~updateIdentity(identity)
    else devices[key]=.BluetoothDevice~new(self,identity,profileMap)
  end
  out=.array~new
  do key over devices; out~append(devices[key]); end
  return out

::method device guarded
  expose devices provider profileMap
  use strict arg keyArg
  key=keyArg~string
  if devices~hasIndex(key) then return devices[key]
  do identity over provider~enumerateDevices
    if identity~key==key then do
      dev=.BluetoothDevice~new(self,identity,profileMap)
      devices[key]=dev
      return dev
    end
  end
  return .nil

::method _deviceFromIdentity private
  expose devices profileMap
  use strict arg identity
  key=identity~key
  if devices~hasIndex(key) then do
    devices[key]~updateIdentity(identity)
    return devices[key]
  end
  dev=.BluetoothDevice~new(self,identity,profileMap)
  devices[key]=dev
  return dev

::method startDiscovery guarded
  expose provider discoveryRunning
  use strict arg adapterKey=""
  if discoveryRunning then return .true
  discoveryRunning=provider~startDiscovery(adapterKey)
  return discoveryRunning

::method stopDiscovery guarded
  expose provider discoveryRunning
  if \discoveryRunning then return .true
  rc=provider~stopDiscovery
  discoveryRunning=.false
  return rc

::method poll
  expose provider
  use strict arg timeoutMs=0
  ev=provider~pollEvent(timeoutMs)
  if ev==.nil then return .nil
  return self~acceptProviderEvent(ev)

::method acceptProviderEvent guarded
  expose eventSource devices
  use strict arg ev
  device=.nil; service=.nil; characteristic=.nil; previous=.nil
  if ev~identity<>.nil then device=self~_deviceFromIdentity(ev~identity)
  else if ev~deviceKey<>"" & devices~hasIndex(ev~deviceKey) then device=devices[ev~deviceKey]
  if device<>.nil then do
    select
      when ev~type==.BluetoothEvents~DEVICE_CONNECTED then device~setConnected(.true)
      when ev~type==.BluetoothEvents~DEVICE_DISCONNECTED then device~setConnected(.false)
      when ev~type==.BluetoothEvents~DEVICE_PAIRED then device~setPaired(.true)
      when ev~type==.BluetoothEvents~RSSI_CHANGED then device~setRssi(ev~value)
      otherwise nop
    end
    if ev~serviceUuid<>"" then service=device~service(ev~serviceUuid)
    if service<>.nil & ev~characteristicUuid<>"" then characteristic=service~characteristic(ev~characteristicUuid)
    if characteristic<>.nil & ev~type==.BluetoothEvents~GATT_VALUE_CHANGED then do
      previous=characteristic~cachedValue
      characteristic~acceptValue(ev~value)
    end
  end
  data=.BluetoothEventData~new(device,service,characteristic,ev~value,previous,ev~metadata)
  guard off
  result=eventSource~emit(ev~type,data,ev~metadata)
  if device<>.nil then device~emitLocal(ev~type,data,ev~metadata)
  if characteristic<>.nil then characteristic~emitLocal(ev~type,data,ev~metadata)
  return result

::method on
  expose eventSource
  use strict arg eventType,target,messageName,delivery='SYNC'
  return eventSource~on(eventType,target,messageName,delivery)

::method when
  expose eventSource
  use strict arg filter
  return eventSource~when(filter)

::class BluetoothAdapter public
::attribute key get
::attribute name get
::attribute powered
::attribute discoverable

::method init
  expose key name powered discoverable
  use strict arg keyArg,nameArg="",poweredArg=.false,discoverableArg=.false
  key=keyArg~string; name=nameArg~string; powered=poweredArg; discoverable=discoverableArg

::class BluetoothDevice public
::attribute runtime get
::attribute identity get
::attribute profileMap get
::attribute connected get
::attribute paired get
::attribute rssi get
::attribute eventSource get

::method init
  expose runtime identity profileMap connected paired rssi eventSource services
  use strict arg runtimeArg,identityArg,profileMapArg
  runtime=runtimeArg; identity=identityArg; profileMap=profileMapArg
  connected=.false; paired=.false; rssi=.nil
  eventSource=.EventSource~new('bluetooth:device:'||identity~key)
  services=.directory~new

::method updateIdentity guarded
  expose identity
  use strict arg identityArg
  identity=identityArg
  return self

::method key
  expose identity
  return identity~key

::method name
  expose identity
  return identity~name

::method address
  expose identity
  return identity~address

::method setConnected guarded
  expose connected
  use strict arg value
  connected=value
  return self

::method setPaired guarded
  expose paired
  use strict arg value
  paired=value
  return self

::method setRssi guarded
  expose rssi
  use strict arg value
  rssi=value
  return self

::method connect
  expose runtime identity
  return runtime~provider~connectDevice(identity~key)

::method disconnect
  expose runtime identity
  return runtime~provider~disconnectDevice(identity~key)

::method pair
  expose runtime identity
  return runtime~provider~pairDevice(identity~key)

::method discoverServices guarded
  expose runtime identity profileMap services
  defs=runtime~provider~discoverServices(identity~key)
  do def over defs
    uuid=_btUuid(def['uuid'])
    if \services~hasIndex(uuid) then services[uuid]=.GattService~new(self,uuid,profileMap)
    service=services[uuid]
    if fragmentHas(def,'characteristics') then do cdef over def['characteristics']
      service~adoptCharacteristic(cdef)
    end
  end
  return self~services

::method services guarded
  expose services
  out=.array~new; do uuid over services; out~append(services[uuid]); end
  return out

::method service guarded
  expose services profileMap
  use strict arg nameOrUuid
  uuid=profileMap~serviceUuid(nameOrUuid)
  if uuid=="" then uuid=_btUuid(nameOrUuid)
  if \services~hasIndex(uuid) then self~discoverServices
  if services~hasIndex(uuid) then return services[uuid]
  return .nil

::method unknown
  expose profileMap
  use strict arg messageName,args
  if args~items==0 then do
    uuid=profileMap~serviceUuid(messageName)
    if uuid<>"" then return self~service(uuid)
  end
  return .nil

::method on
  expose eventSource
  use strict arg eventType,target,messageName,delivery='SYNC'
  return eventSource~on(eventType,target,messageName,delivery)

::method when
  expose eventSource
  use strict arg filter
  return eventSource~when(filter)

::method emitLocal
  expose eventSource
  use strict arg eventType,data=.nil,metadata=.nil
  return eventSource~emit(eventType,data,metadata)

::class GattService public
::attribute device get
::attribute uuid get
::attribute profileMap get

::method init
  expose device uuid profileMap characteristics
  use strict arg deviceArg,uuidArg,profileMapArg
  device=deviceArg; uuid=_btUuid(uuidArg); profileMap=profileMapArg
  characteristics=.directory~new

::method adoptCharacteristic guarded
  expose characteristics device uuid
  use strict arg def
  cuuid=_btUuid(def['uuid'])
  if \characteristics~hasIndex(cuuid) then characteristics[cuuid]=.GattCharacteristic~new(self,cuuid,def)
  return characteristics[cuuid]

::method characteristic guarded
  expose characteristics profileMap uuid device
  use strict arg nameOrUuid
  cuuid=profileMap~characteristicUuid(uuid,nameOrUuid)
  if cuuid=="" then cuuid=_btUuid(nameOrUuid)
  if \characteristics~hasIndex(cuuid) then device~discoverServices
  if characteristics~hasIndex(cuuid) then return characteristics[cuuid]
  return .nil

::method characteristics guarded
  expose characteristics
  out=.array~new; do u over characteristics; out~append(characteristics[u]); end
  return out

::method unknown
  expose profileMap uuid
  use strict arg messageName,args
  if args~items==0 then do
    cuuid=profileMap~characteristicUuid(uuid,messageName)
    if cuuid<>"" then return self~characteristic(cuuid)
  end
  return .nil

::class GattCharacteristic public
::attribute service get
::attribute uuid get
::attribute properties get
::attribute cachedValue get
::attribute eventSource get

::method init
  expose service uuid properties cachedValue eventSource notifying
  use strict arg serviceArg,uuidArg,definitionArg=.nil
  service=serviceArg; uuid=_btUuid(uuidArg); cachedValue=.nil; notifying=.false
  properties=.directory~new
  if definitionArg<>.nil then do
    if fragmentHas(definitionArg,'properties') then do p over definitionArg['properties']; properties[p~string~upper]=.true; end
  end
  eventSource=.EventSource~new('bluetooth:gatt:'||service~device~key||':'||service~uuid||':'||uuid)

::method read
  expose service uuid cachedValue
  runtime=service~device~runtime
  value=runtime~provider~readCharacteristic(service~device~key,service~uuid,uuid)
  cachedValue=value
  return value

::method write
  expose service uuid
  use strict arg value
  return service~device~runtime~provider~writeCharacteristic(service~device~key,service~uuid,uuid,value)

::method notify guarded
  expose service uuid notifying
  use strict arg state=.true
  ok=service~device~runtime~provider~setCharacteristicNotify(service~device~key,service~uuid,uuid,state)
  if ok then notifying=state
  return ok

::method acceptValue guarded
  expose cachedValue
  use strict arg value
  old=cachedValue; cachedValue=value
  return old

::method on
  expose eventSource
  use strict arg eventType,target,messageName,delivery='SYNC'
  return eventSource~on(eventType,target,messageName,delivery)

::method when
  expose eventSource
  use strict arg filter
  return eventSource~when(filter)

::method emitLocal
  expose eventSource
  use strict arg eventType,data=.nil,metadata=.nil
  return eventSource~emit(eventType,data,metadata)

::class GattDescriptor public
::attribute characteristic get
::attribute uuid get
::method init
  expose characteristic uuid
  use strict arg characteristicArg,uuidArg
  characteristic=characteristicArg; uuid=_btUuid(uuidArg)

::class RfcommService public
::attribute device get
::attribute channel get
::attribute name get
::method init
  expose device channel name
  use strict arg deviceArg,channelArg,nameArg=""
  device=deviceArg; channel=channelArg+0; name=nameArg~string

/*----------------------------------------------------------------------------*/
/* In-memory provider used for deterministic qualification and API examples.   */
/*----------------------------------------------------------------------------*/
::class BluetoothMemoryProvider public inherit BluetoothProvider
::method init
  expose adapters devices serviceDefs queue connected paired values notifications discovery
  adapters=.directory~new; devices=.directory~new; serviceDefs=.directory~new; queue=.queue~new
  connected=.directory~new; paired=.directory~new; values=.directory~new; notifications=.directory~new; discovery=.false

::method providerId
  return 'memory-bluetooth'

::method addAdapter guarded
  expose adapters
  use strict arg adapter
  adapters[adapter~key]=adapter
  return self

::method addDevice guarded
  expose devices
  use strict arg identity
  devices[identity~key]=identity
  return self

::method defineServices guarded
  expose serviceDefs
  use strict arg deviceKey,defs
  serviceDefs[deviceKey~string]=defs
  return self

::method enumerateAdapters guarded
  expose adapters
  out=.array~new; do k over adapters; out~append(adapters[k]); end
  return out

::method enumerateDevices guarded
  expose devices
  out=.array~new; do k over devices; out~append(devices[k]); end
  return out

::method startDiscovery guarded
  expose discovery
  use strict arg adapterKey=""
  discovery=.true
  return .true

::method stopDiscovery guarded
  expose discovery
  discovery=.false
  return .true

::method pollEvent guarded
  expose queue
  use strict arg timeoutMs=0
  if queue~items==0 then return .nil
  return queue~pull

::method inject guarded
  expose queue
  use strict arg event
  queue~queue(event)
  return event

::method connectDevice guarded
  expose connected devices queue
  use strict arg key
  if \devices~hasIndex(key) then return .false
  connected[key]=.true
  queue~queue(.BluetoothProviderEvent~new(.BluetoothEvents~DEVICE_CONNECTED,key,devices[key]))
  return .true

::method disconnectDevice guarded
  expose connected devices queue
  use strict arg key
  if \devices~hasIndex(key) then return .false
  connected[key]=.false
  queue~queue(.BluetoothProviderEvent~new(.BluetoothEvents~DEVICE_DISCONNECTED,key,devices[key]))
  return .true

::method pairDevice guarded
  expose paired devices queue
  use strict arg key
  if \devices~hasIndex(key) then return .false
  paired[key]=.true
  queue~queue(.BluetoothProviderEvent~new(.BluetoothEvents~DEVICE_PAIRED,key,devices[key]))
  return .true

::method discoverServices guarded
  expose serviceDefs
  use strict arg key
  if serviceDefs~hasIndex(key) then return serviceDefs[key]
  return .array~new

::method _valueKey private
  use strict arg deviceKey,serviceUuid,charUuid
  return deviceKey~string||'|'||_btUuid(serviceUuid)||'|'||_btUuid(charUuid)

::method readCharacteristic guarded
  expose values
  use strict arg deviceKey,serviceUuid,charUuid
  key=self~_valueKey(deviceKey,serviceUuid,charUuid)
  if values~hasIndex(key) then return values[key]
  return .nil

::method writeCharacteristic guarded
  expose values
  use strict arg deviceKey,serviceUuid,charUuid,value
  values[self~_valueKey(deviceKey,serviceUuid,charUuid)]=value
  return .true

::method setCharacteristicNotify guarded
  expose notifications
  use strict arg deviceKey,serviceUuid,charUuid,state
  notifications[self~_valueKey(deviceKey,serviceUuid,charUuid)]=state
  return .true

::method injectValue guarded
  expose values devices queue notifications
  use strict arg deviceKey,serviceUuid,charUuid,value
  key=self~_valueKey(deviceKey,serviceUuid,charUuid)
  values[key]=value
  if \devices~hasIndex(deviceKey) then return .false
  queue~queue(.BluetoothProviderEvent~new(.BluetoothEvents~GATT_VALUE_CHANGED,deviceKey,devices[deviceKey],serviceUuid,charUuid,value))
  return .true

::routine fragmentHas
  use strict arg obj,key
  return obj~hasIndex(key~string)

::routine _btUuid public
  use strict arg value
  s=value~string~lower~space(0)
  s=changestr('-',s,'')
  if s~length==4 then return '0000'||s||'00001000800000805f9b34fb'
  if s~length==8 then return s||'00001000800000805f9b34fb'
  return s

::routine _btLooksLikeUuid public
  use strict arg value
  s=value~string~space(0)
  if s~length==4 | s~length==8 | s~length==32 | s~length==36 then return .true
  return .false

::requires 'EventRuntime.cls'
::requires 'json.cls'
