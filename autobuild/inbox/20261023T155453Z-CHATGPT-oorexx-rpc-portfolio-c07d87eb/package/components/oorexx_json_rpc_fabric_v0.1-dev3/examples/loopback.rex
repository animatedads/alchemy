/* Two explicitly selected connectors, one service contract. */
services=.JsonRpcMethodRegistry~new
services~register('greeting.hello',.GreetingHandler~new)
client=.JsonRpcClient~new(.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(services)))
connectors=.JsonRpcConnectorRegistry~new
connectors~register('jsonrpc',client)
connectors~register('local',.JsonRpcDirectConnector~new(services))
args=.Array~of(.JsonString~new('Ada'))
do choice over .Array~of('local','jsonrpc')
  reply=connectors~request(choice,'greeting.hello',args)
  if reply~ok then say choice || ':' reply~result
  else say choice || ':FAILED' reply~fault~code
end
exit 0

::class GreetingHandler
::method invoke
  use strict arg name, params, context
  if \params~isA(.Array) | params~items \== 1 then return .JsonRpcFault~new(-32602,'Invalid params')
  return .JsonString~new('Hello, ' || params[1])
::requires 'JsonRpcFabric.cls'
