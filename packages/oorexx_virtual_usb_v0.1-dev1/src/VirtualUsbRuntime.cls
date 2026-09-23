/*----------------------------------------------------------------------------*/
/* ooRexx Virtual USB v0.1-dev1 - device-side runtime and event model.        */
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
::attribute configurationValue get
::attribute connected get

::method init
  expose definition provider interfaces configurationValue connected
  use strict arg sourceIdArg, definitionArg, providerArg
  self~init:super(sourceIdArg)
  definition=definitionArg; provider=providerArg; interfaces=.directory~new
  configurationValue=0; connected=.false
  cfg=definition~configuration(1)
  if cfg<>.nil then do intfDef over cfg~interfaces
    interfaces[intfDef~name~upper]=.VirtualUsbInterface~new(self,intfDef,provider)
  end

::method present
  expose provider
  return provider~present(self)

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
  expose interfaces
  use strict arg address
  do name over interfaces
    ep=interfaces[name]~endpoint(address)
    if ep<>.nil then return ep
  end
  return .nil

::method unknown
  use strict arg messageName, arguments
  if arguments~items<>0 then forward class (super)
  intf=self~interface(messageName)
  if intf<>.nil then return intf
  forward class (super)

::method onControl
  use strict arg interfaceName, requestName,target,messageName,delivery='SYNC'
  if interfaceName='' then eventName='USB.CONTROL.'||requestName~string~upper
  else eventName='USB.CONTROL.'||interfaceName~string~upper||'.'||requestName~string~upper
  return self~on(eventName,target,messageName,delivery)

::method handleControl
  expose definition
  use strict arg request, outData=''
  std=.UsbChapter9~process(self,request,outData)
  if std~handled then do
    if std~configureValue<>.nil & \std~stall then self~_setConfigured(std~configureValue)
    return std
  end

  entry=definition~controlMap~resolve(request)
  if entry==.nil then do
    tx=.UsbControlTransaction~new(request,'UNMAPPED',outData)
    self~emit(.VirtualUsbEvents~CONTROL,tx)
    if tx~responded then return .UsbControlResult~new(.true,tx~response,tx~stalled,.nil,'UNMAPPED')
    return .UsbControlResult~new(.false,'',.true)
  end

  if entry~interfaceName='' then eventName='USB.CONTROL.'||entry~name
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

::method _setConfigured
  expose configurationValue
  use strict arg value
  configurationValue=value+0
  self~emit(.VirtualUsbEvents~CONFIGURED,configurationValue)
  return self

::method _providerEvent
  use strict arg kind
  kind=kind~string~upper
  select
    when kind='CONNECT' then self~_setConnected(.true)
    when kind='DISCONNECT' then self~_setConnected(.false)
    when kind='RESET' then self~emit(.VirtualUsbEvents~RESET,self)
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
  return device~handleControl(request,outData)
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
::requires 'EventRuntime.cls'
