pty=.foreign~load('bridge/linux-pty-test.bridge.json')
r=pty~openpty(.foreign~out,.foreign~out,.nil,.nil,.nil)
if r~returnValue<>0 then do; say 'SERIAL POSIX PTY: SKIP openpty failed errno='r~errno; exit 0; end
master=r~out('master'); slave=r~out('slave')
nameResult=pty~ttyname(slave)
if nameResult~isA(.ForeignResult) then slaveName=nameResult~returnValue; else slaveName=nameResult
if slaveName==.nil | slaveName='' then do; say 'SERIAL POSIX PTY: SKIP ttyname unavailable'; master~close; slave~close; exit 0; end
provider=.LinuxPosixSerialProvider~new
bridge=provider~bridgeInfo
call assert bridge['abiQualified'],'ABI qualified'
call assert bridge['termiosSize']=60,'termios size'
runtime=.SerialRuntime~new(provider)
port=runtime~open(slaveName,.SerialConfiguration~new(115200,8,'NONE',1,'NONE'))
call assert port<>.nil,'open PTY slave as serial'

payload='00610062ff00010203'x
wr=pty~write(master,payload,payload~length)
call assert wr~returnValue=payload~length,'write master'
received=port~poll(1000,64)
call assert received=payload,'native serial read exact binary'

reply='dead00beef'x
n=port~write(reply)
call assert n=reply~length,'native serial write count'
buf=.foreign~buffer(64)
rr=pty~read(master,buf,64)
call assert rr~returnValue=reply~length,'master read count'
call assert buf~getBytes(0,reply~length)=reply,'native serial write exact binary'
buf~close

port~baud=57600
call assert port~baud=57600,'live reconfigure baud'
call assert port~sendBreak(0),'send break PTY'
port~close
master~close; slave~close; pty~close
say 'SERIAL POSIX PTY: OK path='slaveName
exit 0
assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  return
::requires 'LinuxPosixSerialProvider.cls'
::requires 'foreign.cls'
