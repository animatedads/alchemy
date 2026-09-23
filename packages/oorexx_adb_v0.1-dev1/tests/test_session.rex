
t=.AdbMemoryTransport~new
s=.AdbSession~new(t,.nil,'adb:test')
o=.Observer~new
s~on(.AdbEvents~CONNECTED,o,'connected')
call assert s~connect,'connect'
call assert t~written~items=1,'CNXN sent'
first=.AdbPacketCodec~decode(t~written[1],.false)
call assert first~command='CNXN','first command'

t~enqueuePacket(.AdbPacket~new('CNXN',.AdbProtocol~VERSION,1048576,'device::ro.product.model=Pixel-Test;features=shell_v2,cmd;'),.false)
call assert s~pump,'pump cnxn'
call assert s~state='ONLINE','online'
call assert s~banner~property('ro.product.model')='Pixel-Test','banner model'
call assert s~banner~hasFeature('shell_v2'),'feature'
call assert o~connections=1,'connection event'

stream=s~shell('echo hello')
call assert stream~state='OPENING','stream opening'
open=.AdbPacketCodec~decode(t~written[t~written~items],.false)
call assert open~command='OPEN','OPEN sent'
local=open~arg0
s~processPacket(.AdbPacket~new('OKAY',77,local,''))
call assert stream~state='OPEN','stream open'
call assert stream~remoteId=77,'remote id'
s~processPacket(.AdbPacket~new('WRTE',77,local,'68656C6C6F0A'x))
call assert stream~buffer='68656C6C6F0A'x,'stream data'
ack=.AdbPacketCodec~decode(t~written[t~written~items],.false)
call assert ack~command='OKAY','WRTE ack'
s~processPacket(.AdbPacket~new('CLSE',77,local,''))
call assert stream~state='CLOSED','stream closed'
say 'ADB SESSION: OK'
exit 0

assert: procedure
  use strict arg ok,label
  if \ok then do; say 'FAIL' label; exit 1; end
return

::class Observer
::attribute connections
::method init; expose connections; connections=0
::method connected; expose connections; use strict arg event; connections+=1

::requires "AdbRuntime.cls"
