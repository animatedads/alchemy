/*----------------------------------------------------------------------------*/
/* Linux Raw Gadget provider for ooRexx Virtual USB v0.1-dev9.                */
/* Uses /dev/raw-gadget through Foreign Runtime.                               */
/*                                                                            */
/* Raw Gadget control/event fetches and endpoint transfers are blocking.      */
/* The provider therefore keeps the control event loop on one ooRexx activity */
/* and starts one reader activity for each enabled OUT endpoint.               */
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
::attribute endpointWorkers get
::attribute running get
::attribute readerEpoch get
::attribute lastEventError get
::attribute lastEndpointErrors get
::attribute lastPresentationError get

::method init
  expose path driverName deviceName speed handle device endpointHandles endpointWorkers running readerEpoch lastEventError lastEndpointErrors lastPresentationError
  use strict arg driverNameArg='dummy_udc', deviceNameArg='dummy_udc.0', speedArg='HIGH', pathArg='/dev/raw-gadget'
  path=pathArg~string; driverName=driverNameArg~string; deviceName=deviceNameArg~string; speed=speedArg~string~upper
  handle=.nil; device=.nil
  endpointHandles=.directory~new; endpointWorkers=.directory~new
  running=.false; readerEpoch=0
  lastEventError=.nil; lastEndpointErrors=.directory~new; lastPresentationError=.nil

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
  expose path driverName deviceName speed handle device running lastEventError lastEndpointErrors lastPresentationError
  use strict arg deviceArg
  lib=.LinuxRawGadgetNative~lib
  lastPresentationError=.nil
  openRc=lib~posix_open(path,lib~constant('O_RDWR')~value,0)
  if openRc~isA(.ForeignResult) then handle=openRc~returnValue
  else handle=openRc
  if handle==.nil then do
    self~_rememberPresentationError('OPEN',openRc)
    return .false
  end
  if \handle~isA(.ForeignHandle) then do
    self~_rememberPresentationError('OPEN',openRc)
    handle=.nil
    return .false
  end

  init=.foreign~buffer(257)
  init~putBytes(0,self~_zpad(driverName,128))
  init~putBytes(128,self~_zpad(deviceName,128))
  if speed='FULL' then speedCode=lib~constant('USB_SPEED_FULL')~value
  else speedCode=lib~constant('USB_SPEED_HIGH')~value
  init~putBytes(256,d2c(speedCode))
  rc=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_INIT')~value,init)
  init~close
  if rc~returnValue<0 then do
    self~_rememberPresentationError('INIT',rc)
    self~close
    return .false
  end
  rc=lib~posix_ioctl_scalar(handle,lib~constant('USB_RAW_IOCTL_RUN')~value,0)
  if rc~returnValue<0 then do
    self~_rememberPresentationError('RUN',rc)
    self~close
    return .false
  end
  device=deviceArg
  running=.true
  lastEventError=.nil; lastEndpointErrors=.directory~new
  return .true

::method _rememberPresentationError private
  expose lastPresentationError
  use strict arg operation,nativeRc=.nil
  err=.directory~new
  err['operation']=operation~string
  err['errno']=0
  err['message']='native operation failed'
  err['returnValue']=.nil
  if nativeRc<>.nil then do
    if nativeRc~isA(.ForeignResult) then do
      err['returnValue']=nativeRc~returnValue
      err['errno']=nativeRc~errno
      err['message']=nativeRc~errorMessage
    end
    else err['returnValue']=nativeRc
  end
  lastPresentationError=err
  return err

::method run unguarded
  expose handle running lastEventError
  if handle==.nil then raise syntax 93.900 array('raw-gadget device is not presented')
  running=.true
  do while running
    if handle==.nil then leave
    item=self~processOne
    if item==.nil then do
      if handle<>.nil then do
        /* fetchEvent recorded the concrete errno/message. */
        if lastEventError==.nil then do
          lastEventError=.directory~new
          lastEventError['operation']='EVENT_FETCH'
          lastEventError['errno']=0
          lastEventError['message']='event fetch ended without an error result'
        end
      end
      leave
    end
  end
  running=.false
  return lastEventError==.nil

::method _zpad private
  use strict arg text,size
  bytes=text~string
  if bytes~length>=size then raise syntax 93.900 array('native name too long')
  return bytes||copies('00'x,size-bytes~length)

::method fetchEvent unguarded
  expose handle lastEventError
  use strict arg dataCapacity=64
  if handle==.nil then return .nil
  lib=.LinuxRawGadgetNative~lib
  buf=.foreign~buffer(8+dataCapacity)
  buf~putBytes(0,'00000000'x)
  buf~putBytes(4,.UsbBinary~u32le(dataCapacity))
  r=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_EVENT_FETCH')~value,buf)
  if r~returnValue<0 then do
    lastEventError=.directory~new
    lastEventError['operation']='EVENT_FETCH'
    lastEventError['errno']=r~errno
    lastEventError['message']=r~errorMessage
    buf~close
    return .nil
  end
  lastEventError=.nil
  kind=.UsbBinary~fromU32le(buf~getBytes(0,4))
  actual=.UsbBinary~fromU32le(buf~getBytes(4,4))
  data=''; if actual>0 then data=buf~getBytes(8,actual)
  buf~close
  return .LinuxRawGadgetEvent~new(kind,data)

::method processOne unguarded
  expose device
  event=self~fetchEvent(64)
  if event==.nil then return .nil
  lib=.LinuxRawGadgetNative~lib
  select
    when event~kind=lib~constant('USB_RAW_EVENT_CONNECT')~value then device~_providerEvent('CONNECT')
    when event~kind=lib~constant('USB_RAW_EVENT_SUSPEND')~value then device~_providerEvent('SUSPEND')
    when event~kind=lib~constant('USB_RAW_EVENT_RESUME')~value then device~_providerEvent('RESUME')
    when event~kind=lib~constant('USB_RAW_EVENT_RESET')~value then do
      self~_retireReaders
      ignored=self~_disableEndpoints
      device~_providerEvent('RESET')
    end
    when event~kind=lib~constant('USB_RAW_EVENT_DISCONNECT')~value then do
      self~_retireReaders
      ignored=self~_disableEndpoints
      device~_providerEvent('DISCONNECT')
    end
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
  self~_traceControl('SETUP',request)

  /* Raw Gadget's EP0 ioctl follows USB transfer direction: EP0_WRITE is the
     response path for IN requests, while EP0_READ is the response path for
     OUT requests.  For an OUT request with a data stage, receive that stage
     before dispatching it to the semantic device.  That EP0_READ is the one
     response ioctl for the control transfer; do not follow it with EP0_WRITE. */
  outData=''; outTransferCompleted=.false
  if request~direction='OUT' & request~length>0 then do
    outData=self~_ep0Read(request~length)
    outTransferCompleted=.true
  end
  controlResult=device~handleControl(request,outData)
  if controlResult~stall then do
    self~_traceControl('STALL',request)
    ignored=lib~posix_ioctl_scalar(handle,lib~constant('USB_RAW_IOCTL_EP0_STALL')~value,0)
    return controlResult
  end

  configuredValue=.nil
  if controlResult~configureValue<>.nil then do
    configuredValue=controlResult~configureValue
    if \self~_configure(configuredValue) then do
      self~_trace('CONFIGURE failed value='||configuredValue)
      ignored=lib~posix_ioctl_scalar(handle,lib~constant('USB_RAW_IOCTL_EP0_STALL')~value,0)
      return .UsbControlResult~new(.true,'',.true)
    end
    device~_providerConfigured(configuredValue)
  end

  if request~direction='IN' then do
    ignored=self~_ep0Write(controlResult~data)
    self~_traceControl('EP0_WRITE rc='||ignored,request)
  end
  else if \outTransferCompleted then do
    /* Zero-length OUT requests (notably SET_CONFIGURATION and SET_IDLE) still
       require an EP0_READ(0) response.  Using EP0_WRITE here leaves the host
       with a device descriptor but prevents configuration/interface binding. */
    ignored=self~_ep0Read(0)
    self~_traceControl('EP0_READ rc='||ignored,request)
  end
  else self~_traceControl('EP0_READ data-stage complete',request)

  /* Endpoint readers start only after the SET_CONFIGURATION status stage has
     completed.  The host can now submit interrupt/bulk OUT transfers. */
  if configuredValue<>.nil then if configuredValue>0 then self~_startOutReaders(configuredValue)
  return controlResult

::method _trace private
  use strict arg text
  enabled=value('OOREXX_VUSB_TRACE',,'ENVIRONMENT')
  traceFile=value('OOREXX_VUSB_TRACE_FILE',,'ENVIRONMENT')
  if (enabled='' | enabled='0') & traceFile='' then return .false
  line='RAWGADGET TRACE:' text
  if traceFile<>'' then do
    call lineout traceFile,line
    call stream traceFile,'C','CLOSE'
  end
  if enabled<>'' & enabled<>'0' then say line
  return .true

::method _traceControl private
  use strict arg phase,request
  return self~_trace(phase||' dir='||request~direction||' type='||request~type||' recipient='||request~recipient||' request='||request~request||' value='||request~value||' index='||request~index||' length='||request~length)

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
  expose device endpointHandles handle lastEndpointErrors
  use strict arg configValue
  lib=.LinuxRawGadgetNative~lib

  /* A new configuration is a new endpoint-reader generation. */
  self~_retireReaders

  /* Reconfiguration owns the kernel endpoint handles.  Semantic endpoint
     objects survive it; only their provider binding changes. */
  self~_disableEndpoints
  if configValue=0 then return .true

  cfg=device~definition~configuration(configValue)
  if cfg==.nil then return .false
  endpointHandles=.directory~new
  lastEndpointErrors=.directory~new
  do intfDef over cfg~interfaces
    do epDef over intfDef~endpoints
      desc=.foreign~buffer(9)
      desc~putBytes(0,epDef~encode||'0000'x)
      r=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_EP_ENABLE')~value,desc)
      desc~close
      if r~returnValue<0 then do
        self~_trace('EP_ENABLE failed address='||epDef~address||' errno='||r~errno||' '||r~errorMessage)
        self~_disableEndpoints
        return .false
      end
      self~_trace('EP_ENABLE address='||epDef~address||' handle='||r~returnValue)
      endpointHandles[epDef~address]=r~returnValue
    end
  end
  r=lib~posix_ioctl_scalar(handle,lib~constant('USB_RAW_IOCTL_CONFIGURE')~value,0)
  if r~returnValue<0 then do
    self~_trace('CONFIGURE ioctl failed errno='||r~errno||' '||r~errorMessage)
    self~_disableEndpoints
    return .false
  end
  self~_trace('CONFIGURE ioctl OK value='||configValue)
  return .true

::method _startOutReaders private
  expose device endpointWorkers readerEpoch
  use strict arg configValue
  cfg=device~definition~configuration(configValue)
  if cfg==.nil then return 0
  epoch=readerEpoch
  endpointWorkers=.directory~new
  started=0
  do intfDef over cfg~interfaces
    do epDef over intfDef~endpoints
      if epDef~direction='OUT' then do
        endpoint=device~endpoint(epDef~address)
        if endpoint<>.nil then do
          worker=.LinuxRawGadgetEndpointReader~new(self,endpoint,epoch,epDef~maxPacketSize)
          message=worker~start('run')
          state=.directory~new
          state['worker']=worker
          state['message']=message
          state['epoch']=epoch
          endpointWorkers[epDef~address]=state
          started+=1
        end
      end
    end
  end
  return started

::method _retireReaders private
  expose readerEpoch endpointWorkers
  readerEpoch+=1
  endpointWorkers=.directory~new
  return readerEpoch

::method readerCurrent unguarded
  expose running readerEpoch endpointHandles handle
  use strict arg epoch,address
  if \running then return .false
  if handle==.nil then return .false
  if epoch<>readerEpoch then return .false
  return endpointHandles~hasIndex(address)

::method _disableEndpoints private
  expose endpointHandles handle
  if endpointHandles==.nil then return .true
  lib=.LinuxRawGadgetNative~lib
  ok=.true
  do address over endpointHandles
    epHandle=endpointHandles[address]
    r=lib~posix_ioctl_scalar(handle,lib~constant('USB_RAW_IOCTL_EP_DISABLE')~value,epHandle)
    if r~returnValue<0 then ok=.false
  end
  endpointHandles=.directory~new
  return ok

::method writeEndpoint unguarded
  expose endpointHandles handle lastEndpointErrors
  use strict arg endpoint,bytes
  if \endpointHandles~hasIndex(endpoint~address) then raise syntax 93.900 array('endpoint is not enabled')
  lib=.LinuxRawGadgetNative~lib
  epHandle=endpointHandles[endpoint~address]
  buf=self~_ioBuffer(epHandle,bytes~length,bytes)
  r=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_EP_WRITE')~value,buf)
  buf~close
  if r~returnValue<0 then do
    err=.directory~new
    err['operation']='EP_WRITE'; err['errno']=r~errno; err['message']=r~errorMessage
    lastEndpointErrors[endpoint~address]=err
  end
  return r~returnValue

::method readEndpointOnce unguarded
  expose endpointHandles handle device lastEndpointErrors
  use strict arg endpoint,maxBytes=4096
  if endpoint~direction<>'OUT' then raise syntax 93.900 array('readEndpointOnce requires OUT endpoint')
  if \endpointHandles~hasIndex(endpoint~address) then return .nil
  lib=.LinuxRawGadgetNative~lib
  epHandle=endpointHandles[endpoint~address]
  buf=self~_ioBuffer(epHandle,maxBytes)
  r=lib~posix_ioctl(handle,lib~constant('USB_RAW_IOCTL_EP_READ')~value,buf)
  if r~returnValue<0 then do
    err=.directory~new
    err['operation']='EP_READ'; err['errno']=r~errno; err['message']=r~errorMessage
    lastEndpointErrors[endpoint~address]=err
    buf~close
    return .nil
  end
  if r~returnValue>0 then data=buf~getBytes(8,r~returnValue); else data=''
  buf~close
  if lastEndpointErrors~hasIndex(endpoint~address) then lastEndpointErrors~remove(endpoint~address)
  if data~length>0 then endpoint~_receive(data)
  return data

::method close
  expose handle endpointHandles device running lastEventError
  running=.false
  self~_retireReaders
  if handle<>.nil then do
    if endpointHandles<>.nil then if endpointHandles~items>0 then ignored=self~_disableEndpoints
    if handle~isA(.ForeignHandle) then if \handle~closed then handle~close
  end
  handle=.nil; endpointHandles=.directory~new; device=.nil
  return .true

::class LinuxRawGadgetEndpointReader private
::method init
  expose provider endpoint epoch maxBytes
  use strict arg providerArg,endpointArg,epochArg,maxBytesArg=4096
  provider=providerArg; endpoint=endpointArg; epoch=epochArg+0; maxBytes=maxBytesArg+0

::method run unguarded
  expose provider endpoint epoch maxBytes
  do while provider~readerCurrent(epoch,endpoint~address)
    data=provider~readEndpointOnce(endpoint,maxBytes)
    if data==.nil then leave
  end
  return

::class LinuxRawGadgetEvent public
::attribute kind get
::attribute data get
::method init
  expose kind data
  use strict arg kindArg,dataArg=''
  kind=kindArg+0; data=dataArg

::requires 'VirtualUsbRuntime.cls'
::requires 'foreign.cls'
