/*----------------------------------------------------------------------------*/
/* ooRexx Virtual USB v0.1-dev1 - USB semantic model and Chapter 9 codec.    */
/*----------------------------------------------------------------------------*/

::class VirtualUsbBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "virtual.usb/0.1"

::class UsbBinary public
::method u16le class
  use strict arg value
  return d2c(value,2)~reverse
::method u32le class
  use strict arg value
  return d2c(value,4)~reverse
::method fromU16le class
  use strict arg bytes
  if bytes~length<>2 then raise syntax 93.900 array('u16le requires 2 bytes')
  return c2d(bytes~reverse)
::method fromU32le class
  use strict arg bytes
  if bytes~length<>4 then raise syntax 93.900 array('u32le requires 4 bytes')
  return c2d(bytes~reverse)
::method clamp class
  use strict arg bytes, maximum
  if maximum<0 then return bytes
  return bytes~left(min(bytes~length,maximum))
::method asciiUtf16le class
  use strict arg text
  out=''
  do i=1 to text~length
    c=text~substr(i,1)
    code=c2d(c)
    if code>127 then raise syntax 93.900 array('dev1 USB string descriptors accept ASCII only')
    out=out||d2c(code)||'00'x
  end
  return out

::class UsbDeviceDescriptor public
::attribute bcdUSB
::attribute deviceClass
::attribute deviceSubClass
::attribute deviceProtocol
::attribute maxPacketSize0
::attribute vendorId
::attribute productId
::attribute bcdDevice
::attribute manufacturerIndex
::attribute productIndex
::attribute serialIndex
::attribute configurations

::method init
  expose bcdUSB deviceClass deviceSubClass deviceProtocol maxPacketSize0 vendorId productId bcdDevice manufacturerIndex productIndex serialIndex configurations
  use strict arg vendorIdArg, productIdArg, bcdUSBArg=512, bcdDeviceArg=256, classArg=0, subclassArg=0, protocolArg=0, maxPacketArg=64, manufacturerArg=1, productArg=2, serialArg=3, configsArg=1
  bcdUSB=bcdUSBArg; bcdDevice=bcdDeviceArg
  deviceClass=classArg; deviceSubClass=subclassArg; deviceProtocol=protocolArg
  maxPacketSize0=maxPacketArg; vendorId=vendorIdArg; productId=productIdArg
  manufacturerIndex=manufacturerArg; productIndex=productArg; serialIndex=serialArg; configurations=configsArg

::method encode
  expose bcdUSB deviceClass deviceSubClass deviceProtocol maxPacketSize0 vendorId productId bcdDevice manufacturerIndex productIndex serialIndex configurations
  return d2c(18)||d2c(1)||.UsbBinary~u16le(bcdUSB)||d2c(deviceClass)||d2c(deviceSubClass)||d2c(deviceProtocol)||d2c(maxPacketSize0)||.UsbBinary~u16le(vendorId)||.UsbBinary~u16le(productId)||.UsbBinary~u16le(bcdDevice)||d2c(manufacturerIndex)||d2c(productIndex)||d2c(serialIndex)||d2c(configurations)

::class UsbEndpointDefinition public
::attribute name get
::attribute address get
::attribute transferType get
::attribute maxPacketSize get
::attribute interval get

::method init
  expose name address transferType maxPacketSize interval
  use strict arg nameArg, addressArg, transferTypeArg='BULK', maxPacketArg=64, intervalArg=0
  name=nameArg~string
  address=addressArg+0
  transferType=transferTypeArg~string~upper
  maxPacketSize=maxPacketArg+0
  interval=intervalArg+0

::method direction
  expose address
  if bitand(d2c(address),"80"x)=="80"x then return 'IN'
  return 'OUT'

::method attributes
  expose transferType
  select
    when transferType='CONTROL' then return 0
    when transferType='ISOCHRONOUS' | transferType='ISO' then return 1
    when transferType='BULK' then return 2
    when transferType='INTERRUPT' | transferType='INT' then return 3
    otherwise raise syntax 93.900 array('unsupported USB transfer type '||transferType)
  end

::method encode
  expose address maxPacketSize interval
  return d2c(7)||d2c(5)||d2c(address)||d2c(self~attributes)||.UsbBinary~u16le(maxPacketSize)||d2c(interval)

::class UsbInterfaceDefinition public
::attribute name get
::attribute number get
::attribute alternateSetting get
::attribute interfaceClass get
::attribute interfaceSubClass get
::attribute interfaceProtocol get
::attribute stringIndex get
::attribute endpoints get

::method init
  expose name number alternateSetting interfaceClass interfaceSubClass interfaceProtocol stringIndex endpoints
  use strict arg nameArg, numberArg, classArg=255, subclassArg=0, protocolArg=0, alternateArg=0, stringArg=0
  name=nameArg~string
  number=numberArg+0; interfaceClass=classArg+0; interfaceSubClass=subclassArg+0; interfaceProtocol=protocolArg+0
  alternateSetting=alternateArg+0; stringIndex=stringArg+0
  endpoints=.array~new

::method addEndpoint
  expose endpoints
  use strict arg endpoint
  if \endpoint~isA(.UsbEndpointDefinition) then raise syntax 93.900 array('UsbEndpointDefinition required')
  endpoints~append(endpoint)
  return self

::method endpoint
  expose endpoints
  use strict arg nameOrAddress
  do ep over endpoints
    if nameOrAddress~string~caselessCompare(ep~name)=0 then return ep
    if nameOrAddress~datatype('W') & ep~address=nameOrAddress then return ep
  end
  return .nil

::method encode
  expose number alternateSetting interfaceClass interfaceSubClass interfaceProtocol stringIndex endpoints
  out=d2c(9)||d2c(4)||d2c(number)||d2c(alternateSetting)||d2c(endpoints~items)||d2c(interfaceClass)||d2c(interfaceSubClass)||d2c(interfaceProtocol)||d2c(stringIndex)
  do ep over endpoints; out=out||ep~encode; end
  return out

::class UsbConfigurationDefinition public
::attribute value get
::attribute name get
::attribute stringIndex get
::attribute attributes get
::attribute maxPowerMa get
::attribute interfaces get

::method init
  expose value name stringIndex attributes maxPowerMa interfaces
  use strict arg valueArg=1, nameArg='default', stringArg=0, attributesArg=128, maxPowerMaArg=100
  value=valueArg+0; name=nameArg~string; stringIndex=stringArg+0; attributes=attributesArg+0; maxPowerMa=maxPowerMaArg+0
  interfaces=.array~new

::method addInterface
  expose interfaces
  use strict arg interface
  if \interface~isA(.UsbInterfaceDefinition) then raise syntax 93.900 array('UsbInterfaceDefinition required')
  interfaces~append(interface)
  return self

::method interface
  expose interfaces
  use strict arg nameOrNumber
  do intf over interfaces
    if nameOrNumber~string~caselessCompare(intf~name)=0 then return intf
    if nameOrNumber~datatype('W') & intf~number=nameOrNumber then return intf
  end
  return .nil

::method encode
  expose value stringIndex attributes maxPowerMa interfaces
  body=''
  do intf over interfaces; body=body||intf~encode; end
  total=9+body~length
  maxPowerUnits=(maxPowerMa+1)%2
  head=d2c(9)||d2c(2)||.UsbBinary~u16le(total)||d2c(interfaces~items)||d2c(value)||d2c(stringIndex)||d2c(attributes)||d2c(maxPowerUnits)
  return head||body

::class UsbDeviceDefinition public
::attribute deviceDescriptor get
::attribute configurations get
::attribute strings get
::attribute controlMap get

::method init
  expose deviceDescriptor configurations strings controlMap
  use strict arg deviceDescriptorArg
  deviceDescriptor=deviceDescriptorArg
  configurations=.array~new
  strings=.directory~new
  controlMap=.UsbControlMap~new

::method string
  expose strings
  use strict arg index, text
  strings[index+0]=text~string
  return self

::method addConfiguration
  expose configurations
  use strict arg config
  configurations~append(config)
  return self

::method configuration
  expose configurations
  use strict arg value=1
  do cfg over configurations
    if cfg~value=value then return cfg
  end
  return .nil

::method descriptor
  expose deviceDescriptor configurations strings
  use strict arg descriptorType, descriptorIndex=0
  select
    when descriptorType=1 then return deviceDescriptor~encode
    when descriptorType=2 then do
      n=descriptorIndex+1
      if n<1 | n>configurations~items then return .nil
      return configurations[n]~encode
    end
    when descriptorType=3 then do
      if descriptorIndex=0 then return '04030904'x
      if \strings~hasIndex(descriptorIndex) then return .nil
      body=.UsbBinary~asciiUtf16le(strings[descriptorIndex])
      return d2c(body~length+2)||d2c(3)||body
    end
    otherwise return .nil
  end

::class UsbControlRequest public
::attribute requestType get
::attribute request get
::attribute value get
::attribute index get
::attribute length get

::method init
  expose requestType request value index length
  use strict arg requestTypeArg, requestArg, valueArg=0, indexArg=0, lengthArg=0
  requestType=requestTypeArg+0; request=requestArg+0; value=valueArg+0; index=indexArg+0; length=lengthArg+0

::method fromBytes class
  use strict arg bytes
  if bytes~length<>8 then raise syntax 93.900 array('USB control request must be 8 bytes')
  return .UsbControlRequest~new(c2d(bytes~substr(1,1)),c2d(bytes~substr(2,1)),.UsbBinary~fromU16le(bytes~substr(3,2)),.UsbBinary~fromU16le(bytes~substr(5,2)),.UsbBinary~fromU16le(bytes~substr(7,2)))

::method encode
  expose requestType request value index length
  return d2c(requestType)||d2c(request)||.UsbBinary~u16le(value)||.UsbBinary~u16le(index)||.UsbBinary~u16le(length)

::method direction
  expose requestType
  if bitand(d2c(requestType),"80"x)=="80"x then return 'IN'
  return 'OUT'
::method type
  expose requestType
  t=c2d(bitand(d2c(requestType),d2c(96)))
  select
    when t=0 then return 'STANDARD'
    when t=32 then return 'CLASS'
    when t=64 then return 'VENDOR'
    otherwise return 'RESERVED'
  end
::method recipient
  expose requestType
  return c2d(bitand(d2c(requestType),d2c(31)))

::class UsbControlTransaction public
::attribute request get
::attribute outData get
::attribute semanticName get
::attribute responded get
::attribute response get
::attribute stalled get

::method init
  expose request outData semanticName responded response stalled
  use strict arg requestArg, semanticArg, outDataArg=''
  request=requestArg; semanticName=semanticArg~string~upper; outData=outDataArg
  responded=.false; response=''; stalled=.false

::method respond guarded
  expose responded response stalled request
  use strict arg bytes=''
  response=.UsbBinary~clamp(bytes,request~length)
  responded=.true; stalled=.false
  return self

::method stall guarded
  expose responded response stalled
  responded=.true; response=''; stalled=.true
  return self

::class UsbControlMapEntry public
::attribute name get
::attribute requestType get
::attribute requestTypeMask get
::attribute request get
::attribute value get
::attribute index get
::attribute interfaceName get

::method init
  expose name requestType requestTypeMask request value index interfaceName
  use strict arg nameArg, requestTypeArg, requestArg, valueArg=.nil, indexArg=.nil, maskArg=255, interfaceNameArg=''
  name=nameArg~string~upper; requestType=requestTypeArg+0; request=requestArg+0; value=valueArg; index=indexArg; requestTypeMask=maskArg+0; interfaceName=interfaceNameArg~string

::method matches
  expose requestType requestTypeMask request value index
  use strict arg controlRequest
  leftMask=c2d(bitand(d2c(controlRequest~requestType),d2c(requestTypeMask)))
  rightMask=c2d(bitand(d2c(requestType),d2c(requestTypeMask)))
  if leftMask<>rightMask then return .false
  if controlRequest~request<>request then return .false
  if value<>.nil then if controlRequest~value<>value then return .false
  if index<>.nil then if controlRequest~index<>index then return .false
  return .true

::class UsbControlMap public
::method init
  expose entries
  entries=.array~new
::method add
  expose entries
  use strict arg entry
  entries~append(entry)
  return self
::method resolve
  expose entries
  use strict arg request
  do entry over entries
    if entry~matches(request) then return entry
  end
  return .nil

::class UsbControlResult public
::attribute handled get
::attribute data get
::attribute stall get
::attribute configureValue get
::attribute semanticName get

::method init
  expose handled data stall configureValue semanticName
  use strict arg handledArg=.false, dataArg='', stallArg=.false, configureArg=.nil, semanticArg=''
  handled=handledArg; data=dataArg; stall=stallArg; configureValue=configureArg; semanticName=semanticArg~string

::class UsbChapter9 public
::constant GET_STATUS 0
::constant CLEAR_FEATURE 1
::constant SET_FEATURE 3
::constant SET_ADDRESS 5
::constant GET_DESCRIPTOR 6
::constant GET_CONFIGURATION 8
::constant SET_CONFIGURATION 9
::constant GET_INTERFACE 10
::constant SET_INTERFACE 11

::method process class
  use strict arg device, request, outData=''
  if request~type<>'STANDARD' then return .UsbControlResult~new
  select
    when request~request=self~GET_DESCRIPTOR then do
      dtype=request~value % 256
      dindex=request~value // 256
      bytes=device~definition~descriptor(dtype,dindex)
      if bytes==.nil then return .UsbControlResult~new(.true,'',.true)
      return .UsbControlResult~new(.true,.UsbBinary~clamp(bytes,request~length))
    end
    when request~request=self~GET_CONFIGURATION then return .UsbControlResult~new(.true,d2c(device~configurationValue))
    when request~request=self~SET_CONFIGURATION then return .UsbControlResult~new(.true,'',.false,request~value)
    when request~request=self~GET_STATUS then return .UsbControlResult~new(.true,'0000'x)
    when request~request=self~SET_ADDRESS then return .UsbControlResult~new(.true,'')
    when request~request=self~GET_INTERFACE then return .UsbControlResult~new(.true,'00'x)
    when request~request=self~SET_INTERFACE then do
      if request~value=0 then return .UsbControlResult~new(.true,'')
      return .UsbControlResult~new(.true,'',.true)
    end
    otherwise return .UsbControlResult~new
  end
