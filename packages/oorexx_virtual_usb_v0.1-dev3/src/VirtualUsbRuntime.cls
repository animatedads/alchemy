/*----------------------------------------------------------------------------*/
/* ooRexx Virtual USB v0.1-dev3 - device-side runtime and event model.        */
/*----------------------------------------------------------------------------*/

::class VirtualUsbEvents public
::constant CONNECTED 'USB.DEVICE.CONNECTED'
::constant DISCONNECTED 'USB.DEVICE.DISCONNECTED'
::constant RESET 'USB.DEVICE.RESET'
::constant SUSPENDED 'USB.DEVICE.SUSPENDED'
::constant RESUMED 'USB.DEVICE.RESUMED'
::constant CONFIGURED 'USB.DEVICE.CONFIGURED'
::constant CONTROL 'USB.CONTROL.REQUEST'
::constant ENDPOINT_DATA 'USB.ENDPOINT.DATA'
::constant ENDPOINT_WRITE 'USB.ENDPOINT.WRITE'

::class VirtualUsbEndpoint public subclass EventSource
::attribute definition get
::attribute device get
::attribute provider get

::method init
  expose definition device provider
  use strict arg deviceArg, definitionArg, providerArg
  device=deviceArg; definition=definitionArg; provider=providerArg
  self~init:super(device~sourceId||':ep:'||definition~name)

::method name
  expose definition
  return definition~name
::method address
  expose definition
  return definition~address
::method direction
  expose definition
  return definition~direction

::method write
  expose definition provider
  use strict arg bytes
  if definition~direction<>'IN' then raise syntax 93.900 array('write is valid only on an IN endpoint')
  count=provider~writeEndpoint(self,bytes)
  self~emit(.VirtualUsbEvents~ENDPOINT_WRITE,bytes)
  return count

::method _receive
  expose definition
  use strict arg bytes
  if definition~direction<>'OUT' then raise syntax 93.900 array('host OUT data can only arrive on an OUT endpoint')
  return self~emit(.VirtualUsbEvents~ENDPOINT_DATA,bytes)

::method on
  use strict arg eventType,target,messageName,delivery='SYNC'
  name=eventType~string~upper
  if name='DATA' | name='RECEIVED' then name=.VirtualUsbEvents~ENDPOINT_DATA
  if name='WRITE' | name='WRITTEN' then name=.VirtualUsbEvents~ENDPOINT_WRITE
  return self~on:super(name,target,messageName,delivery)

::class VirtualUsbInterface public
::attribute definition get
::attribute device get
::attribute endpoints get

::method init
  expose definition device endpoints
  use strict arg deviceArg, definitionArg, providerArg
  device=deviceArg; definition=definitionArg; endpoints=.directory~new
  do epDef over definition~endpoints
    endpoints[epDef~name~upper]=.VirtualUsbEndpoint~new(device,epDef,providerArg)
  end

::method endpoint
  expose endpoints definition
  use strict arg nameOrAddress
  key=nameOrAddress~string~upper
  if endpoints~hasIndex(key) then return endpoints[key]
  do name over endpoints
    ep=endpoints[name]
    if nameOrAddress~datatype('W') & ep~address=nameOrAddress then return ep
  end
  return .nil

::method unknown
  use strict arg messageName, arguments
  if arguments~items<>0 then forward class (super)
  ep=self~endpoint(messageName)
  if ep<>.nil then return ep
  forward class (super)

::method onRequest
  expose device definition
  use strict arg requestName,target,messageName,delivery='SYNC'
  return device~onControl(definition~name,requestName,target,messageName,delivery)

::class VirtualUsbControl public
::attribute definition get
::attribute function get
::attribute device get

::method init
  expose definition function device
  use strict arg deviceArg, functionArg, definitionArg
  device=deviceArg; function=functionArg; definition=definitionArg

::method name
  expose definition
  return definition~name

::method on
  expose device function definition
  use strict arg eventType,target,messageName,delivery='SYNC'
  kind=eventType~string~upper
  if kind<>'REQUEST' & kind<>'REQUESTED' & kind<>'CONTROL' then raise syntax 93.900 array('virtual USB control supports REQUEST events')
  return device~onFunctionControl(function~name,definition~name,target,messageName,delivery)

::method when
  expose device function definition
  use strict arg eventType='REQUEST'
  kind=eventType~string~upper
  if kind<>'REQUEST' & kind<>'REQUESTED' & kind<>'CONTROL' then raise syntax 93.900 array('virtual USB control supports REQUEST events')
  filter=.EventFilter~new('USB.CONTROL.'||function~name~upper||'.'||definition~name,device~sourceId)
  return device~when(filter)

::class VirtualUsbFunction public
::attribute definition get
::attribute device get
::attribute interfaces get
::attribute controls get

::method init
  expose definition device interfaces controls
  use strict arg deviceArg, definitionArg, providerArg, interfaceRegistry=.nil
  device=deviceArg; definition=definitionArg; interfaces=.directory~new; controls=.directory~new
  do intfDef over definition~interfaces
    key=intfDef~name~upper
    if interfaceRegistry<>.nil & interfaceRegistry~hasIndex(key) then interfaces[key]=interfaceRegistry[key]
    else do
      obj=.VirtualUsbInterface~new(device,intfDef,providerArg)
      interfaces[key]=obj
      if interfaceRegistry<>.nil then interfaceRegistry[key]=obj
    end
  end
  do entry over definition~controlEntries
    controls[entry~name~upper]=.VirtualUsbControl~new(device,self,entry)
  end

::method name
  expose definition
  return definition~name

::method control
  expose controls
  use strict arg name
  key=name~string~upper
  if controls~hasIndex(key) then return controls[key]
  return .nil

::method interface
  expose interfaces
  use strict arg nameOrNumber
  key=nameOrNumber~string~upper
  if interfaces~hasIndex(key) then return interfaces[key]
  found=.nil
  do name over interfaces
    intf=interfaces[name]
    if nameOrNumber~datatype('W') & intf~definition~number=nameOrNumber then do
      if found<>.nil & found<>intf then return .nil
      found=intf
    end
  end
  return found

::method endpoint
  expose interfaces
  use strict arg nameOrAddress
  found=.nil
  do name over interfaces
    ep=interfaces[name]~endpoint(nameOrAddress)
    if ep<>.nil then do
      if found<>.nil & found<>ep then return .nil
      found=ep
    end
  end
  return found

::method unknown
  use strict arg messageName, arguments
  if arguments~items<>0 then forward class (super)
  ctl=self~control(messageName)
  if ctl<>.nil then return ctl
  ep=self~endpoint(messageName)
  if ep<>.nil then return ep
  intf=self~interface(messageName)
  if intf<>.nil then return intf
  forward class (super)

::method onRequest
  expose device definition
  use strict arg requestName,target,messageName,delivery='SYNC'
  return device~onFunctionControl(definition~name,requestName,target,messageName,delivery)

::class VirtualUsbProvider public
::method providerId
  return 'abstract'
::method present
  use strict arg device
  raise syntax 93.900 array('VirtualUsbProvider PRESENT not implemented')
::method close
  return .true
::method writeEndpoint
  use strict arg endpoint, bytes
  raise syntax 93.900 array('VirtualUsbProvider WRITEENDPOINT not implemented')

::class VirtualUsbDevice public subclass EventSource
::attribute definition get
::attribute provider get
::attribute interfaces get
::attribute functions get
::attribute configurationValue get
::attribute connected get

::method init
  expose definition provider interfaces functions configurationValue connected
  use strict arg sourceIdArg, definitionArg, providerArg
  self~init:super(sourceIdArg)
  definition=definitionArg; provider=providerArg; interfaces=.directory~new; functions=.directory~new
  configurationValue=0; connected=.false

  /* Runtime interface identity is unique.  Functions are semantic groupings
     over those retained interface objects, not a second object hierarchy. */
  cfg=definition~configuration(1)
  if cfg<>.nil then do intfDef over cfg~interfaces
    key=intfDef~name~upper
    if \interfaces~hasIndex(key) then interfaces[key]=.VirtualUsbInterface~new(self,intfDef,provider)
  end
  do fnKey over definition~functions
    fnDef=definition~functions[fnKey]
    functions[fnKey]=.VirtualUsbFunction~new(self,fnDef,provider,interfaces)
  end

::method fromProfile class
  use strict arg profile, provider
  if \profile~isA(.UsbDeviceProfile) then raise syntax 93.900 array('UsbDeviceProfile required')
  return self~new(profile~sourceId,profile~definition,provider)

::method present
  expose provider
  return provider~present(self)

::method function
  expose functions
  use strict arg name
  key=name~string~upper
  if functions~hasIndex(key) then return functions[key]
  return .nil

::method interface
  expose interfaces
  use strict arg nameOrNumber
  key=nameOrNumber~string~upper
  if interfaces~hasIndex(key) then return interfaces[key]
  do name over interfaces
    obj=interfaces[name]
    if nameOrNumber~datatype('W') & obj~definition~number=nameOrNumber then return obj
  end
  return .nil

::method endpoint
  expose functions interfaces
  use strict arg address
  found=.nil
  do name over functions
    ep=functions[name]~endpoint(address)
    if ep<>.nil then do
      if found<>.nil & found<>ep then return .nil
      found=ep
    end
  end
  if found<>.nil then return found
  do name over interfaces
    ep=interfaces[name]~endpoint(address)
    if ep<>.nil then return ep
  end
  return .nil

::method unknown
  use strict arg messageName, arguments
  if arguments~items<>0 then forward class (super)
  fn=self~function(messageName)
  if fn<>.nil then return fn
  intf=self~interface(messageName)
  if intf<>.nil then return intf
  forward class (super)

::method onControl
  use strict arg interfaceName, requestName,target,messageName,delivery='SYNC'
  if interfaceName='' then eventName='USB.CONTROL.'||requestName~string~upper
  else eventName='USB.CONTROL.'||interfaceName~string~upper||'.'||requestName~string~upper
  return self~on(eventName,target,messageName,delivery)

::method onFunctionControl
  use strict arg functionName, requestName,target,messageName,delivery='SYNC'
  eventName='USB.CONTROL.'||functionName~string~upper||'.'||requestName~string~upper
  return self~on(eventName,target,messageName,delivery)

::method handleControl
  expose definition
  use strict arg request, outData=''
  std=.UsbChapter9~process(self,request,outData)
  if std~handled then return std

  entry=definition~controlMap~resolve(request)
  if entry==.nil then do
    tx=.UsbControlTransaction~new(request,'UNMAPPED',outData)
    self~emit(.VirtualUsbEvents~CONTROL,tx)
    if tx~responded then return .UsbControlResult~new(.true,tx~response,tx~stalled,.nil,'UNMAPPED')
    return .UsbControlResult~new(.false,'',.true)
  end

  if entry~functionName<>'' then eventName='USB.CONTROL.'||entry~functionName~upper||'.'||entry~name
  else if entry~interfaceName='' then eventName='USB.CONTROL.'||entry~name
  else eventName='USB.CONTROL.'||entry~interfaceName~upper||'.'||entry~name
  tx=.UsbControlTransaction~new(request,entry~name,outData)
  self~emit(eventName,tx)
  if \tx~responded then return .UsbControlResult~new(.true,'',.true,.nil,entry~name)
  return .UsbControlResult~new(.true,tx~response,tx~stalled,.nil,entry~name)

::method _setConnected
  expose connected
  use strict arg state
  state=state==.true
  if connected=state then return self
  connected=state
  if state then self~emit(.VirtualUsbEvents~CONNECTED,self)
  else self~emit(.VirtualUsbEvents~DISCONNECTED,self)
  return self

::method _providerConfigured
  expose configurationValue
  use strict arg value
  value=value+0
  if configurationValue=value then return self
  configurationValue=value
  self~emit(.VirtualUsbEvents~CONFIGURED,configurationValue)
  return self

::method _setConfigured
  use strict arg value
  return self~_providerConfigured(value)

::method _providerEvent
  use strict arg kind
  kind=kind~string~upper
  select
    when kind='CONNECT' then self~_setConnected(.true)
    when kind='DISCONNECT' then do
      self~_providerConfigured(0)
      self~_setConnected(.false)
    end
    when kind='RESET' then do
      self~_providerConfigured(0)
      self~emit(.VirtualUsbEvents~RESET,self)
    end
    when kind='SUSPEND' then self~emit(.VirtualUsbEvents~SUSPENDED,self)
    when kind='RESUME' then self~emit(.VirtualUsbEvents~RESUMED,self)
    otherwise nop
  end
  return self

::class VirtualUsbMemoryProvider public subclass VirtualUsbProvider
::attribute device get
::attribute writes get

::method init
  expose device writes
  device=.nil; writes=.array~new
::method providerId
  return 'memory-host'
::method present
  expose device
  use strict arg deviceArg
  device=deviceArg
  device~_providerEvent('CONNECT')
  return .true
::method hostControl
  expose device
  use strict arg request,outData=''
  if device==.nil then raise syntax 93.900 array('no virtual USB device is presented')
  controlResult=device~handleControl(request,outData)
  if controlResult~configureValue<>.nil & \controlResult~stall then device~_providerConfigured(controlResult~configureValue)
  return controlResult
::method hostOut
  expose device
  use strict arg endpointAddress,bytes
  ep=device~endpoint(endpointAddress)
  if ep==.nil then raise syntax 93.900 array('unknown endpoint')
  return ep~_receive(bytes)
::method writeEndpoint
  expose writes
  use strict arg endpoint,bytes
  item=.directory~new
  item['endpoint']=endpoint~address; item['bytes']=bytes
  writes~append(item)
  return bytes~length
::method lastWrite
  expose writes
  if writes~items=0 then return .nil
  return writes[writes~items]

::requires 'UsbModel.cls'
::requires 'UsbDeviceProfiles.cls'
::requires 'EventRuntime.cls'
