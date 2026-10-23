/* Portable simulated Socket Provider fragmentation and negative cases. */
checks=0
registry=.JsonRpcMethodRegistry~new
registry~register('demo.echo',.EchoHandler~new)
dispatcher=.JsonRpcDispatcher~new(registry)
provider=.MockProvider~new(dispatcher)
transport=.JsonRpcSocketTransport~new(provider,'test-service')
client=.JsonRpcClient~new(transport)
response=client~request('demo.echo',.array~of(.JsonString~new('008'),23))
call check response~ok, 'fragmented socket round-trip'
call check response~result[1]~isA(.JsonString), 'socket string typed'
call check response~result[1]=='008', 'socket string fidelity'
call check response~result[2]==23, 'socket numeric fidelity'
call check provider~last~closed, 'request socket closed'
call check client~notify('demo.echo'), 'socket send notification'
call check provider~last~closed, 'notification socket closed'
call check provider~last~outbound=='', 'notification no response frame'
call check provider~opens==2, 'distinct connections, no pooling'

frame=.JsonRpcLengthFrame~new(64)
probe=.Probe~new
call check probe~rejectHeader(frame,'FFFFFFFF'), 'oversize rejected at header'
call check probe~rejectHeader(frame,'00ZZ0001'), 'non-hex header rejected'
call check probe~rejectHeader(frame,'00000000'), 'zero length rejected'
call check probe~rejectHeader(frame,'00000005ab'), 'truncated body rejected'
call check probe~rejectHeader(frame,'0000'), 'truncated header rejected'
call check probe~rejectWrite(frame,'x'~copies(65)), 'oversize sender rejected'
call check probe~rejectWrite(frame,''), 'empty sender rejected'
call check frame~read(.MockReadEndpoint~new('00000003abc'))=='abc', 'valid fragmented raw frame'

/* Limit mismatch surfaces as an explicit error, never as a silent retry. */
limited=.JsonRpcClient~new(.JsonRpcSocketTransport~new(provider,'test-service',16))
response=limited~request('demo.echo')
call check \response~ok, 'frame exceeds bound returns transport fault'
call check provider~last~closed, 'failed write closes endpoint'

/* Missing address must fail closed. */
missing=.JsonRpcClient~new(.JsonRpcSocketTransport~new(.AbsentProvider~new,'missing'))
response=missing~request('demo.echo')
call check \response~ok, 'missing service is not a success'

say 'PASS' checks 'socket framing/provider mock checks'
exit 0

check:
  use strict arg condition, name
  if \condition then do
    say 'FAIL' name
    exit 1
  end
  checks=checks+1
return

::class EchoHandler
::method invoke
  use strict arg name, params, context
  return params

::class MockProvider
::method init
  expose dispatcher last opens
  use strict arg dispatcher
  opens=0
::attribute last get
::attribute opens get
::method sender
  expose dispatcher last opens
  use strict arg name
  if name\=='test-service' then return .nil
  opens+=1
  last=.MockSocketEndpoint~new(dispatcher)
  return last

::class AbsentProvider
::method sender
  use strict arg name
  return .nil

::class MockSocketEndpoint
::method init
  expose dispatcher outbound closed
  use strict arg dispatcher
  outbound=''; closed=.false
::attribute outbound get
::attribute closed get
::method sendAll
  expose dispatcher outbound
  use strict arg bytes
  n=x2d(substr(bytes,1,8))
  body=substr(bytes,9)
  if n<>body~length then return -1
  reply=dispatcher~handleText(body)
  if reply\==.nil then outbound=right(d2x(reply~length),8,'0')||reply
  return bytes~length
::method recv
  expose outbound
  use strict arg maximum
  if outbound=='' then return ''
  piece=left(outbound,1)
  outbound=substr(outbound,2)
  return piece
::method close
  expose closed
  closed=.true
  return 0

::class MockReadEndpoint
::method init
  expose data
  use strict arg data
::method recv
  expose data
  use strict arg maximum
  if data=='' then return ''
  piece=left(data,1)
  data=substr(data,2)
  return piece

::class Probe
::method rejectHeader
  use strict arg frame, incoming
  signal on syntax name caught
  reply=frame~read(.MockReadEndpoint~new(incoming))
  signal off syntax
  return .false
caught:
  signal off syntax
  return .true
::method rejectWrite
  use strict arg frame, payload
  signal on syntax name caught
  sent=frame~write(.MockReadEndpoint~new(''),payload)
  signal off syntax
  return .false
caught:
  signal off syntax
  return .true

::requires 'JsonRpcSocketTransport.cls'
