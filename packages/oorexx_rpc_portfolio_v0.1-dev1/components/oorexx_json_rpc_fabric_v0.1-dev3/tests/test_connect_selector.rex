/* Contract test against actual ConnectSelector v0.1-dev1, not a mock selector.
 * No queue manager, JMS port, or remote machine is needed for this test.
 */
checks=0
registry=.JsonRpcMethodRegistry~new
registry~register('catalog.lookup',.LookupHandler~new)
registry~register('catalog.reject',.RejectHandler~new)
registry~register('catalog.notify',.NoticeHandler~new)
local=.JsonRpcDirectConnector~new(registry)
wire=.JsonRpcClient~new(.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(registry)))
selector=.ConnectSelector~new
selector~register('DIRECT',.ConnectCallAdapter~new(local,'DIRECT'))
selector~register('RPC',.ConnectCallAdapter~new(wire,'RPC'))
params=.Array~of(.JsonString~new('sku-7'))
intent=.ConnectIntent~new('catalog.lookup','request','immediate','AUTO')
selection=selector~select(intent)
call check selection~ok & selection~provider == 'DIRECT', 'AUTO chooses first eligible direct provider'
explain=selector~explain(intent)
call check explain['provider'] == 'DIRECT', 'explain returns chosen provider'
response=selector~execute(intent,params)
call check response~ok & response~value == 'found:sku-7', 'direct call returns handler result'
call check response~completed & \response~durable, 'direct result marked completed, not durable'
intent=.ConnectIntent~new('catalog.lookup','request','immediate','RPC')
selection=selector~select(intent)
call check selection~ok & selection~provider == 'RPC', 'explicit RPC selection'
response=selector~execute(intent,params)
call check response~ok & response~value == 'found:sku-7', 'RPC yields equivalent result'
call check response~completed & \response~durable, 'RPC reply completed, not durable'
response=selector~execute(.ConnectIntent~new('catalog.lookup','request','immediate','NO_SUCH_PROVIDER'),params)
call check \response~ok & response~code == 'UNREGISTERED', 'unknown preferred fails closed'
response=selector~execute(.ConnectIntent~new('catalog.lookup','enqueue','durable'),params)
call check \response~ok & response~code == 'NO_ELIGIBLE_PROVIDER', 'no simulated durable queue result'
response=selector~execute(.ConnectIntent~new('catalog.lookup','request','immediate','QUEUE'),params)
call check \response~ok & response~code == 'UNREGISTERED', 'request cannot become implicit queue job'
response=selector~execute(.ConnectIntent~new('catalog.reject','request','immediate','RPC'),params)
call check \response~ok & response~code == 'CALL_FAILED', 'RPC method fault remains failed call'
call check response~value~code == -32602, 'RPC fault code preserved'
response=selector~execute(.ConnectIntent~new('catalog.notify','notify','best_effort','RPC'))
call check response~ok & response~accepted & \response~completed & \response~durable, 'RPC notify accepted not completed'
response=selector~execute(.ConnectIntent~new('catalog.notify','notify','best_effort','DIRECT'))
call check response~ok & response~accepted & \response~completed, 'DIRECT notify acceptance not execution claim'
response=selector~execute(.ConnectIntent~new('catalog.reject','notify','best_effort','DIRECT'))
call check \response~ok & response~code == 'SEND_FAILED', 'direct fault notice not accepted'
/* A send throwing after its state is unknown must not reach ConnectSelector as an unhandled exception. */
broken=.JsonRpcClient~new(.ThrowingSendTransport~new)
selector~register('RPC',.ConnectCallAdapter~new(broken,'RPC'))
response=selector~execute(.ConnectIntent~new('catalog.notify','notify','immediate','RPC'))
call check \response~ok & response~code == 'SEND_FAILED', 'throwing transport maps to send failure'
/* Return to available RPC path. Never make a network error fail over to DIRECT. */
selector~register('RPC',.ConnectCallAdapter~new(.JsonRpcClient~new(.SilentTransport~new),'RPC'))
response=selector~execute(.ConnectIntent~new('catalog.lookup','request','immediate','RPC'),params)
call check \response~ok & response~code == 'CALL_FAILED', 'missing RPC result fails rather than fallback'
call check response~provider == 'RPC', 'RPC remains recorded as selected provider'
say 'PASS' checks 'ConnectSelector dev1 integration checks'
exit 0
check:
  use strict arg condition, name
  if \condition then do
    say 'FAIL' name
    exit 1
  end
  checks+=1
return
::class LookupHandler
::method invoke
  use strict arg methodName, params, context
  return .JsonString~new('found:'||params[1])
::class RejectHandler
::method invoke
  use strict arg methodName, params, context
  return .JsonRpcFault~new(-32602,'No such item')
::class NoticeHandler
::method invoke
  use strict arg methodName, params, context
  return .nil
::class ThrowingSendTransport
::method exchange
  use strict arg bytes
  return .nil
::method send
  use strict arg bytes
  raise syntax 93.900 additional('write channel disappeared')
::class SilentTransport
::method exchange
  use strict arg bytes
  return .nil
::method send
  use strict arg bytes
  return .true
::requires 'JsonRpcFabric.cls'
::requires 'ConnectSelector.cls'
