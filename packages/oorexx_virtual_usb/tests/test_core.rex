parse source . . me
root=filespec('location',me)||'..'

def=.UsbDeviceDefinition~new(.UsbDeviceDescriptor~new(x2d('CAFE'),x2d('4001')))
def~string(1,'ooRexx Labs')~string(2,'Virtual Crypto Generator')~string(3,'DEV0001')
cfg=.UsbConfigurationDefinition~new(1,'default',0,128,100)
crypto=.UsbInterfaceDefinition~new('crypto',0,255,x2d('42'),1)
crypto~addEndpoint(.UsbEndpointDefinition~new('randomIn',x2d('81'),'BULK',64))
crypto~addEndpoint(.UsbEndpointDefinition~new('commandOut',x2d('01'),'BULK',64))
cfg~addInterface(crypto)
def~addConfiguration(cfg)
def~controlMap~add(.UsbControlMapEntry~new('GET_RANDOM',x2d('C1'),1,.nil,0,255,'crypto'))

provider=.VirtualUsbMemoryProvider~new
device=.VirtualUsbDevice~new('usb:virtual-crypto',def,provider)
responder=.EntropyResponder~new
device~crypto~onRequest('GET_RANDOM',responder,'provide','SYNC')
collector=.Collector~new
device~crypto~commandOut~on('data',collector,'received','SYNC')

call ok device~present, 'present memory device'
call ok device~connected, 'provider observation marks connected'

/* Host enumeration request. */
r=.UsbControlRequest~new(x2d('80'),6,x2d('0100'),0,18)
answer=provider~hostControl(r)
call ok answer~handled & \answer~stall, 'GET_DESCRIPTOR device handled'
call ok answer~data~length=18, 'device descriptor length'
call ok c2x(answer~data~substr(9,2))='FECA', 'VID is little endian'
call ok c2x(answer~data~substr(11,2))='0140', 'PID is little endian'

/* Host configures the device. */
r=.UsbControlRequest~new(x2d('00'),9,1,0,0)
answer=provider~hostControl(r)
call ok answer~handled & device~configurationValue=1, 'SET_CONFIGURATION updates observed device state'

/* Vendor interface request becomes a semantic registered event. */
r=.UsbControlRequest~new(x2d('C1'),1,0,0,8)
answer=provider~hostControl(r)
call ok answer~handled & \answer~stall, 'mapped vendor control request handled'
call ok answer~semanticName='GET_RANDOM', 'semantic request name retained'
call ok c2x(answer~data)='0001020304050607', 'handler supplied response bytes'
call ok responder~calls=1, 'registered request handler fired once'

/* Bulk OUT becomes endpoint data event. */
ignored=provider~hostOut(x2d('01'),'seed:hello')
call ok collector~data='seed:hello', 'OUT endpoint data delivered as event'

/* Bulk IN is a device-side write, not a host-side application detail. */
count=device~crypto~randomIn~write('ABCD')
last=provider~lastWrite
call ok count=4 & last['endpoint']=x2d('81') & last['bytes']='ABCD', 'IN endpoint write reaches provider'

say 'VIRTUAL USB CORE: OK'
exit 0

ok: procedure
  use arg condition,label
  if \condition then do
    say 'FAIL:' label
    exit 1
  end
  return

::class EntropyResponder
::attribute calls get
::method init
  expose calls
  calls=0
::method provide
  expose calls
  use strict arg event
  calls+=1
  tx=event~data
  bytes=''
  do i=0 to tx~request~length-1
    bytes=bytes||d2c(i//256)
  end
  tx~respond(bytes)

::class Collector
::attribute data get
::method init
  expose data
  data=''
::method received
  expose data
  use strict arg event
  data=event~data

::requires 'VirtualUsbRuntime.cls'
