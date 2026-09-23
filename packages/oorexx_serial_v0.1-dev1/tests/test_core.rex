cfg=.SerialConfiguration~new(115200,8,'none',1,'none')
call assert cfg~string='115200 8N1 flow=NONE','configuration string'
call assert cfg~withParity('odd')~parity='ODD','configuration copy parity'
id=.SerialPortIdentity~new('test:one','memory-serial','MEM:1','test port')
provider=.SerialMemoryProvider~new
runtime=.SerialRuntime~new(provider)
port=runtime~open(id,cfg)
call assert port<>.nil & port~isOpen,'memory port open'
call assert port~baud=115200,'baud projection'
call assert port~parity='NONE','parity projection'
port~baud=57600
call assert port~baud=57600,'baud setter applied'
port~parity='EVEN'
call assert port~parity='EVEN','parity setter applied'
port~dtr=.true
port~rts=.true
call assert port~lastLineState~dtr & port~lastLineState~rts,'line controls reflected by provider'
port~close
call assert \port~isOpen,'close state'
say 'SERIAL CORE: OK'
exit 0
assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  return
::requires 'SerialRuntime.cls'
