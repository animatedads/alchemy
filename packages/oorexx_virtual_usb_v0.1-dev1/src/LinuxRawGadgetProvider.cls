/*----------------------------------------------------------------------------*/
/* Linux Raw Gadget provider for ooRexx Virtual USB v0.1-dev1.                */
/* Uses /dev/raw-gadget through Foreign Runtime.                               */
/*----------------------------------------------------------------------------*/

::class LinuxRawGadgetNative private
::method lib class unguarded
  expose bridge lib
  if symbol('lib')<>'VAR' then do
    bridge=value('OOREXX_VUSB_RAW_GADGET_BRIDGE',,'ENVIRONMENT')
    if bridge='' then do
      parse source . . sourceFile
      bridge=filespec('location',sourceFile)||'../bridge/linux-raw-gadget.bridge.json'
    end
    lib=.foreign~load(bridge)
    info=.foreign~runtimeInfo
    if \lib~abiQualified | lib~abiProfile<>info~abiProfile then raise syntax 40.900 array('raw-gadget bridge is not ABI-qualified for '||info~abiProfile)
  end
  return lib

::class LinuxRawGadgetProvider public subclass VirtualUsbProvider
::attribute path get
::attribute driverName get
::attribute deviceName get
::attribute speed get
::attribute handle get
::attribute device get
::attribute endpointHandles get

::method init
  expose path driverName deviceName speed handle device endpointHandles
  use strict arg driverNameArg='dummy_udc', deviceNameArg='dummy_udc.0', speedArg='HIGH', pathArg='/dev/raw-gadget'
  path=pathArg~string; driverName=driverNameArg~string; deviceName=deviceNameArg~string; speed=speedArg~string~upper
  handle=.nil; device=.nil; endpointHandles=.directory~new

::method providerId
  return 'linux-raw-gadget'

::method bridgeInfo
  lib=.LinuxRawGadgetNative~lib
  info=.directory~new
  info['abiQualified']=lib~abiQualified
  info['abiProfile']=lib~abiProfile
  info['ioctlInit']=lib~constant('USB_RAW_IOCTL_INIT')~value
  return info

::method available
  expose path
  return sysFileExists(path)

::method present
  expose path driverName deviceName speed handle device
  use strict arg deviceArg
  lib=.LinuxRawGadgetNative~lib
  result=lib~posix_open(path,lib~constant('O_RDWR')~value,0)
  if result~isA(.ForeignResult) then handle=result~returnValue
  else handle=result
  if handle==.nil then return .false
  if handle~isA(.ForeignHandle) then nop
  else return .false

  init=.foreign~buffer(257)
  init~putBytes(0,self~_zpad(driverName,128))
  init~putBytes(128,self~_zpad(deviceName,128))
  if speed='FULL' then speedCode=lib~constant('USB_SPEED_FULL')~value
  else speedCode=lib~constant('USB_SPEED_HIGH')~value
  init~putBytes(256,d2c(speedCode))
  rc=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_INIT')~value,init)
  init~close
  if rc~returnValue<0 then do; self~close; return .false; end
  rc=lib~posix_ioctl_scalar(handle,lib~constant('USB_RAW_IOCTL_RUN')~value,0)
  if rc~returnValue<0 then do; self~close; return .false; end
  device=deviceArg
  return .true

::method _zpad private
  use strict arg text,size
  bytes=text~string
  if bytes~length>=size then raise syntax 93.900 array('native name too long')
  return bytes||copies('00'x,size-bytes~length)

::method fetchEvent
  expose handle device
  use strict arg dataCapacity=64
  if handle==.nil then return .nil
  lib=.LinuxRawGadgetNative~lib
  buf=.foreign~buffer(8+dataCapacity)
  buf~putBytes(0,'00000000'x)
  buf~putBytes(4,.UsbBinary~u32le(dataCapacity))
  r=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_EVENT_FETCH')~value,buf)
  if r~returnValue<0 then do; buf~close; return .nil; end
  kind=.UsbBinary~fromU32le(buf~getBytes(0,4))
  actual=.UsbBinary~fromU32le(buf~getBytes(4,4))
  data=''; if actual>0 then data=buf~getBytes(8,actual)
  buf~close
  return .LinuxRawGadgetEvent~new(kind,data)

::method processOne
  expose device
  event=self~fetchEvent(64)
  if event==.nil then return .nil
  lib=.LinuxRawGadgetNative~lib
  select
    when event~kind=lib~constant('USB_RAW_EVENT_CONNECT')~value then device~_providerEvent('CONNECT')
    when event~kind=lib~constant('USB_RAW_EVENT_SUSPEND')~value then device~_providerEvent('SUSPEND')
    when event~kind=lib~constant('USB_RAW_EVENT_RESUME')~value then device~_providerEvent('RESUME')
    when event~kind=lib~constant('USB_RAW_EVENT_RESET')~value then device~_providerEvent('RESET')
    when event~kind=lib~constant('USB_RAW_EVENT_DISCONNECT')~value then device~_providerEvent('DISCONNECT')
    when event~kind=lib~constant('USB_RAW_EVENT_CONTROL')~value then return self~_processControl(event~data)
    otherwise nop
  end
  return event

::method _processControl private
  expose handle device
  use strict arg setupBytes
  if setupBytes~length<8 then return .nil
  lib=.LinuxRawGadgetNative~lib
  request=.UsbControlRequest~fromBytes(setupBytes~left(8))
  outData=''
  if request~direction='OUT' & request~length>0 then outData=self~_ep0Read(request~length)
  result=device~handleControl(request,outData)
  if result~stall then do
    ignored=lib~posix_ioctl_scalar(handle,lib~constant('USB_RAW_IOCTL_EP0_STALL')~value,0)
    return result
  end
  if request~direction='IN' then ignored=self~_ep0Write(result~data)
  else ignored=self~_ep0Write('')
  if result~configureValue<>.nil then self~_configure(result~configureValue)
  return result

::method _ep0Write private
  expose handle
  use strict arg bytes
  lib=.LinuxRawGadgetNative~lib
  buf=self~_ioBuffer(0,bytes~length,bytes)
  r=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_EP0_WRITE')~value,buf)
  buf~close
  return r~returnValue

::method _ep0Read private
  expose handle
  use strict arg count
  lib=.LinuxRawGadgetNative~lib
  buf=self~_ioBuffer(0,count)
  r=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_EP0_READ')~value,buf)
  if r~returnValue>0 then data=buf~getBytes(8,r~returnValue); else data=''
  buf~close
  return data

::method _ioBuffer private
  use strict arg epHandle,count,bytes=''
  buf=.foreign~buffer(8+count)
  buf~putBytes(0,.UsbBinary~u16le(epHandle))
  buf~putBytes(2,'0000'x)
  buf~putBytes(4,.UsbBinary~u32le(count))
  if bytes~length>0 then buf~putBytes(8,bytes~left(count))
  return buf

::method _configure private
  expose device endpointHandles handle
  use strict arg configValue
  cfg=device~definition~configuration(configValue)
  if cfg==.nil then return .false
  lib=.LinuxRawGadgetNative~lib
  endpointHandles=.directory~new
  do intfDef over cfg~interfaces
    do epDef over intfDef~endpoints
      desc=.foreign~buffer(9)
      desc~putBytes(0,epDef~encode||'0000'x)
      r=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_EP_ENABLE')~value,desc)
      desc~close
      if r~returnValue<0 then return .false
      endpointHandles[epDef~address]=r~returnValue
    end
  end
  r=lib~posix_ioctl_scalar(handle,lib~constant('USB_RAW_IOCTL_CONFIGURE')~value,0)
  return r~returnValue>=0

::method writeEndpoint
  expose endpointHandles handle
  use strict arg endpoint,bytes
  if \endpointHandles~hasIndex(endpoint~address) then raise syntax 93.900 array('endpoint is not enabled')
  lib=.LinuxRawGadgetNative~lib
  epHandle=endpointHandles[endpoint~address]
  buf=self~_ioBuffer(epHandle,bytes~length,bytes)
  r=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_EP_WRITE')~value,buf)
  buf~close
  return r~returnValue

::method readEndpointOnce
  expose endpointHandles handle device
  use strict arg endpoint,maxBytes=4096
  if endpoint~direction<>'OUT' then raise syntax 93.900 array('readEndpointOnce requires OUT endpoint')
  if \endpointHandles~hasIndex(endpoint~address) then raise syntax 93.900 array('endpoint is not enabled')
  lib=.LinuxRawGadgetNative~lib
  epHandle=endpointHandles[endpoint~address]
  buf=self~_ioBuffer(epHandle,maxBytes)
  r=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_EP_READ')~value,buf)
  if r~returnValue>0 then data=buf~getBytes(8,r~returnValue); else data=''
  buf~close
  if data~length>0 then endpoint~_receive(data)
  return data

::method close
  expose handle endpointHandles device
  if handle<>.nil then if handle~isA(.ForeignHandle) then if \handle~closed then handle~close
  handle=.nil; endpointHandles=.directory~new; device=.nil
  return .true

::class LinuxRawGadgetEvent public
::attribute kind get
::attribute data get
::method init
  expose kind data
  use strict arg kindArg,dataArg=''
  kind=kindArg+0; data=dataArg

::requires 'VirtualUsbRuntime.cls'
::requires 'foreign.cls'
