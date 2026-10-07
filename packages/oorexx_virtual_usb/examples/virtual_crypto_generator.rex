/* A virtual board/chip personality.  The application sees semantic requests, */
/* not USB descriptor handling or ioctl calls.                                */
def=.UsbDeviceDefinition~new(.UsbDeviceDescriptor~new(x2d('CAFE'),x2d('4001')))
def~string(1,'ooRexx Labs')~string(2,'Virtual Crypto Generator')~string(3,'PROTO-001')
cfg=.UsbConfigurationDefinition~new
cryptoDef=.UsbInterfaceDefinition~new('crypto',0,255,x2d('42'),1)
cryptoDef~addEndpoint(.UsbEndpointDefinition~new('randomIn',x2d('81'),'BULK',64))
cryptoDef~addEndpoint(.UsbEndpointDefinition~new('commandOut',x2d('01'),'BULK',64))
cfg~addInterface(cryptoDef)
def~addConfiguration(cfg)
def~controlMap~add(.UsbControlMapEntry~new('GET_RANDOM',x2d('C1'),1,.nil,0,255,'crypto'))

/* Use LinuxRawGadgetProvider on a Raw Gadget capable host.  The memory host */
/* makes this example runnable anywhere and behaves like a USB host.          */
provider=.VirtualUsbMemoryProvider~new
device=.VirtualUsbDevice~new('board:crypto-prototype',def,provider)

crypto=.CryptoPrototype~new
device~crypto~onRequest('GET_RANDOM',crypto,'randomRequested')
device~crypto~commandOut~on('data',crypto,'commandReceived')

device~present

/* Demonstration host transaction. */
r=provider~hostControl(.UsbControlRequest~new(x2d('C1'),1,0,0,16))
say 'virtual crypto response:' c2x(r~data)

::class CryptoPrototype
::method randomRequested
  use strict arg event
  tx=event~data
  /* Deterministic demonstration only.  A real implementation should obtain */
  /* bytes through the ooRexx Crypto capability / device implementation.     */
  bytes=''
  do i=1 to tx~request~length; bytes=bytes||d2c((i*37)//256); end
  tx~respond(bytes)
::method commandReceived
  use strict arg event
  say 'host command:' event~data

::requires 'VirtualUsbRuntime.cls'
