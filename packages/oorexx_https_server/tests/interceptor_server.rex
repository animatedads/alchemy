parse arg certificate privateKey port
config=.HttpsServerConfig~new
config~certificateFile=certificate
config~privateKeyFile=privateKey
config~port=port
config~bindAddress='127.0.0.1'
config~bridgeDirectory=directory()'/../bridge'
config~accessLog=.false

server=.HttpsServer~new(config)
outer=.OuterInterceptor~new
inner=.InnerInterceptor~new
handler=.PipelineHandler~new(server,outer)
server~interceptor(outer,'beforeRequest','afterResponse')
server~interceptor(inner,'beforeRequest','afterResponse')
server~route('GET','/context',handler,'context')
server~route('GET','/deny',handler,'shouldNotRun')
server~route('GET','/route-fail',handler,'routeFail')
server~route('GET','/before-fail',handler,'ok')
server~route('GET','/after-fail',handler,'ok')
server~route('GET','/late-register',handler,'lateRegister')
server~route('GET','/ok',handler,'ok')
server~serve
return

::class OuterInterceptor
::attribute denied get
::method init
  expose denied
  denied=0
::method beforeRequest
  expose denied
  use strict arg request, context
  before=context~get('order.before','')
  context~put('order.before',before'A')
  if request~path='/deny' then do
    denied=denied+1
    return .HttpResponse~text('denied',403)
  end
  return .nil
::method afterResponse
  use strict arg request, response, context
  after=context~get('order.after','')
  context~put('order.after',after'A')
  response~header('X-After-Order',context~get('order.after'))
  response~header('X-Request-Id',context~requestId)
  return .nil

::class InnerInterceptor
::method beforeRequest
  use strict arg request, context
  before=context~get('order.before','')
  context~put('order.before',before'B')
  if request~path='/before-fail' then raise syntax 40.900 array('intentional before failure')
  return .nil
::method afterResponse
  use strict arg request, response, context
  after=context~get('order.after','')
  context~put('order.after',after'B')
  if request~path='/after-fail' then raise syntax 40.900 array('intentional after failure')
  return .nil

::class PipelineHandler
::method init
  expose server outer
  use strict arg server, outer
::method context
  use strict arg request
  c=request~context
  text='request='c~requestId' before='c~get('order.before')' peer='c~peerAddress' tls='c~tlsProtocol' cipher='c~tlsCipher' generation='c~tlsGeneration
  return .HttpResponse~text(text)
::method ok
  use strict arg request
  return .HttpResponse~text('ok')
::method shouldNotRun
  use strict arg request
  return .HttpResponse~text('ROUTE-MUST-NOT-RUN',500)
::method routeFail
  use strict arg request
  raise syntax 40.900 array('intentional route failure')
::method lateRegister
  expose server outer
  use strict arg request
  signal on syntax name refused
  server~interceptor(outer,'beforeRequest','afterResponse')
  return .HttpResponse~text('late-registration-was-accepted',500)
refused:
  return .HttpResponse~text('immutable')

::requires '../rexx/https_server.cls'
