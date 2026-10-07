parse source . . me
root=filespec('location',me)||'..'
profile=.UsbDeviceProfileLoader~loadFile(root||'/maps/virtual_crypto_generator.json')
call ok profile~sourceId='board:crypto-prototype','profile source id'
call ok profile~definition~deviceDescriptor~vendorId=x2d('CAFE'),'profile VID'
call ok profile~definition~deviceDescriptor~productId=x2d('4001'),'profile PID'

fnDef=profile~definition~function('crypto')
call ok fnDef<>.nil,'semantic USB function loaded'
call ok fnDef~interfaces~items=1,'function interface count'
call ok fnDef~endpoint('randomIn')~address=x2d('81'),'function endpoint projection'
call ok fnDef~controlEntries~items=2,'function control map entries'

provider=.VirtualUsbMemoryProvider~new
device=.VirtualUsbDevice~fromProfile(profile,provider)
call ok device~crypto<>.nil,'UNKNOWN resolves semantic USB function'
call ok device~crypto~randomIn~address=x2d('81'),'UNKNOWN resolves endpoint through function'
call ok device~crypto~cryptoControl==device~interface('cryptoControl'),'function shares retained interface identity'
call ok device~crypto~randomIn==device~interface('cryptoControl')~randomIn,'function shares retained endpoint identity'
call ok device~crypto~get_random~name='GET_RANDOM','UNKNOWN resolves semantic control object'

responder=.Responder~new
device~crypto~get_random~on('request',responder,'provide','SYNC')
ignored=device~present
answer=provider~hostControl(.UsbControlRequest~new(x2d('C1'),1,0,0,4))
call ok answer~handled & \answer~stall,'profile vendor request handled'
call ok c2x(answer~data)='A0A1A2A3','profile semantic control dispatch'

say 'VIRTUAL USB PROFILE: OK'
exit 0

ok: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return

::class Responder
::method provide
  use strict arg event
  tx=event~data
  tx~respond('A0A1A2A3'x~left(tx~request~length))

::requires 'VirtualUsbRuntime.cls'
