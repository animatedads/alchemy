/* The USB personality is data; the application supplies only behaviour. */
parse source . . me
root=filespec('location',me)||'..'

profile=.UsbDeviceProfileLoader~loadFile(root||'/maps/virtual_crypto_generator.json')
provider=.VirtualUsbMemoryProvider~new
device=.VirtualUsbDevice~fromProfile(profile,provider)
crypto=.CryptoPrototype~new

device~crypto~get_random~on('request',crypto,'randomRequested','SYNC')
device~crypto~commandOut~on('data',crypto,'commandReceived','SYNC')
ignored=device~present

/* Deterministic development-host probe. */
answer=provider~hostControl(.UsbControlRequest~new(x2d('C1'),1,0,0,16))
say 'GET_RANDOM(16):' c2x(answer~data)
ignored=provider~hostOut(x2d('01'),'RESEED:development')
say 'last command:' crypto~lastCommand
exit 0

::class CryptoPrototype
::attribute lastCommand get
::method init
  expose nextByte lastCommand
  nextByte=x2d('25'); lastCommand=''
::method randomRequested
  expose nextByte
  use strict arg event
  tx=event~data
  bytes=''
  do i=1 to tx~request~length
    bytes=bytes||d2c(nextByte)
    nextByte=(nextByte+37)//256
  end
  tx~respond(bytes)
::method commandReceived
  expose lastCommand
  use strict arg event
  lastCommand=event~data

::requires 'VirtualUsbRuntime.cls'
