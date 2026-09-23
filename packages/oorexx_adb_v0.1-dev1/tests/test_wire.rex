
numeric digits 20
p=.AdbPacket~new('CNXN',x2d('01000001'),1048576,'host::features=shell_v2;')
wire=p~encode(.false)
call assert length(wire)=24+p~payload~length,'wire length'
q=.AdbPacketCodec~decode(wire,.false)
call assert q~command='CNXN','command'
call assert q~arg0=x2d('01000001'),'arg0'
call assert q~arg1=1048576,'arg1'
call assert q~payload=p~payload,'payload'
call assert q~validMagic,'magic'

legacy=.AdbPacket~new('WRTE',1,2,'abc')
q=.AdbPacketCodec~decode(legacy~encode(.true),.true)
call assert q~validChecksum,'checksum'
call assert .AdbProtocol~commandValue('CNXN')=x2d('4E584E43'),'CNXN numeric value'
say 'ADB WIRE: OK'
exit 0

assert: procedure
  use strict arg ok,label
  if \ok then do; say 'FAIL' label; exit 1; end
return

::requires "AdbWire.cls"
