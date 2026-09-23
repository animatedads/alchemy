provider=.SerialMemoryProvider~new
runtime=.SerialRuntime~new(provider)
port=runtime~open('MEM:FRAME',.SerialConfiguration~new(115200))
collector=.FrameCollector~new
lines=port~framed(.SerialLineFramer~new,'lines')
lines~on('FRAME',collector,'frame')
provider~inject('MEM:FRAME','alpha'||'0D0A'x||'be')
ignored=port~poll
provider~inject('MEM:FRAME','ta'||'0A'x)
ignored=port~poll
call assert collector~frames~items=2,'line frame count'
call assert collector~frames[1]='alpha','line frame 1'
call assert collector~frames[2]='beta','line frame 2'

fixed=.SerialFixedLengthFramer~new(3)
f=fixed~feed('0102030405'x)
call assert f~items=1 & f[1]='010203'x,'fixed frame first'
f=fixed~feed('06'x)
call assert f~items=1 & f[1]='040506'x,'fixed frame carry'

lp=.SerialLengthPrefixedFramer~new(2,'BIG')
f=lp~feed('000548656c'x)
call assert f~items=0,'length prefix partial'
f=lp~feed('6c6f0003aabbcc'x)
call assert f~items=2,'length prefix count'
call assert f[1]='Hello' & f[2]='aabbcc'x,'length prefix payloads'
port~close
say 'SERIAL FRAMING: OK'
exit 0
assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  return
::class FrameCollector
::attribute frames get
::method init
  expose frames
  frames=.array~new
::method frame
  expose frames
  use strict arg event
  frames~append(event~data~bytes)
::requires 'SerialFraming.cls'
