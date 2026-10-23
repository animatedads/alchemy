/* Explicit optional JSON-RPC adapter for same RpcServiceDispatcher.
 * Requires JSON-RPC Fabric; SOAP core never imports JSON-RPC.
 */
::class RpcJsonServiceBridge public
::method init
  expose dispatcher service
  use strict arg dispatcher, service
::method invoke
  expose dispatcher service
  use strict arg qualifiedName, params, context
  prefix=service || '.'
  if qualifiedName~left(prefix~length) \== prefix then return .JsonRpcFault~new(-32601,'Method not found')
  op=qualifiedName~substr(prefix~length+1)
  answer=dispatcher~invoke(service,op,params,context)
  if answer~ok then return answer~value
  select
    when answer~fault~code=='NOT_FOUND' then return .JsonRpcFault~new(-32601,'Method not found')
    when answer~fault~code=='INVALID_ARGUMENT' then return .JsonRpcFault~new(-32602,answer~fault~message)
    otherwise return .JsonRpcFault~new(-32603,'Internal error')
  end

::requires 'RpcServiceCore.cls'
::requires 'JsonRpcFabric.cls'
