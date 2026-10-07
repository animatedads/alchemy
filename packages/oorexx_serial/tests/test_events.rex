provider=.SerialMemoryProvider~new
runtime=.SerialRuntime~new(provider)
port=runtime~open('MEM:EVENTS')
collector=.Collector~new
port~on('DATA',collector,'data')
port~on('CTS',collector,'cts')
provider~inject('MEM:EVENTS','00ff10'x)
bytes=port~poll
call assert bytes='00ff10'x,'binary data read'
call assert collector~dataCount=1 & collector~last='00ff10'x,'data event'
provider~setObservedLine('MEM:EVENTS','CTS',.true)
ignored=port~poll
call assert collector~ctsCount=1,'CTS change event'
call assert collector~ctsValue=.true,'CTS value'
port~write('a100b2'x)
call assert provider~takeWritten('MEM:EVENTS')='a100b2'x,'binary write'
port~close
say 'SERIAL EVENTS: OK'
exit 0
assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  return
::class Collector
::attribute dataCount get
::attribute ctsCount get
::attribute last get
::attribute ctsValue get
::method init
  expose dataCount ctsCount last ctsValue
  dataCount=0; ctsCount=0; last=''; ctsValue=.nil
::method data
  expose dataCount last
  use strict arg event
  dataCount+=1; last=event~data~bytes
::method cts
  expose ctsCount ctsValue
  use strict arg event
  ctsCount+=1; ctsValue=event~data~value
::requires 'SerialRuntime.cls'
