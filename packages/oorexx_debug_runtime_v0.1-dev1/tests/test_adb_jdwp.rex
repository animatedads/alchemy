parse source . . here
call directory filespec('L',here)

adb=.FakeAdbSession~new
transport=.AdbJdwpTransport~new(adb,4321)
if \transport~open then call fail 'open failed'
if adb~destination<>'jdwp:4321' then call fail 'ADB service projection wrong'
/* Fake the stream as already write-ready and echo handshake via callback. */
if \transport~write(.JdwpProtocol~HANDSHAKE) then call fail 'write failed'
if adb~stream~lastWrite<>.JdwpProtocol~HANDSHAKE then call fail 'handshake not sent over ADB stream'
adb~stream~emitData(.JdwpProtocol~HANDSHAKE)
if transport~read(.JdwpProtocol~HANDSHAKE~length)<>.JdwpProtocol~HANDSHAKE then call fail 'ADB stream data not projected into JDWP transport'

say 'DEBUG ADB -> JDWP TRANSPORT SEAM: OK'
exit 0
fail: procedure
  parse arg m; say 'FAIL:' m; exit 1

::class FakeAdbSession
::attribute destination get
::attribute stream get
::method init
  expose destination stream
  destination=''; stream=.FakeAdbStream~new
::method openService
  expose destination stream
  use strict arg dest
  destination=dest; return stream
::method pump
  use strict arg timeout=0
  return .false

::class FakeAdbStream subclass EventSource
::attribute lastWrite get
::method init
  expose lastWrite
  self~init:super('fake-adb-stream'); lastWrite=''
::method write
  expose lastWrite
  use strict arg bytes
  lastWrite=bytes; return .true
::method emitData
  use strict arg bytes
  return self~emit('ADB.STREAM.DATA',.FakeData~new(bytes))

::class FakeData
::attribute data get
::method init
  expose data
  use strict arg bytes
  data=bytes
::method copyDetached
  expose data
  return .FakeData~new(data)

::requires "EventRuntime.cls"
::requires "AdbJdwp.cls"
