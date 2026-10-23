/* JSON-RPC 2.0 newline-delimited stdin/stdout server example.
 * Each line is one JSON document. No embedded raw LF is permitted.
 * stdout is reserved for JSON. This demo is NOT a network listener.
 */
registry=.JsonRpcMethodRegistry~new
registry~register('system.ping',.PingHandler~new)
registry~register('math.sum',.SumHandler~new)
dispatcher=.JsonRpcDispatcher~new(registry)
do while lines() > 0
  frame=linein()
  if frame~length > 0 then do
    response=dispatcher~handleText(frame)
    if response \== .nil then say response
  end
end
exit 0

::class PingHandler
::method invoke
  use strict arg methodName, params, context
  return .JsonString~new('pong')

::class SumHandler
::method invoke
  use strict arg methodName, params, context
  if \params~isA(.Array) then return .JsonRpcFault~new(-32602,'Invalid params')
  result=0
  do n over params
    if \datatype(n,'N') then return .JsonRpcFault~new(-32602,'Invalid params')
    result=result+n
  end
  return result

::requires 'JsonRpcFabric.cls'
