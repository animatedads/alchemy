/* Behavioral tests, deliberately executed with the supplied ooRexx debug runtime. */
checks=0
registry=.JsonRpcMethodRegistry~new
registry~register('demo.echo',.EchoHandler~new)
registry~register('demo.fail',.FailureHandler~new)
server=.JsonRpcDispatcher~new(registry)
transport=.JsonRpcLoopbackTransport~new(server)
client=.JsonRpcClient~new(transport)
params=.Array~of(.JsonString~new('123'), 42)
rpcResult=client~request('demo.echo', params)
call check rpcResult~ok, 'success status'
call check rpcResult~result~isA(.Array), 'rpcResult array'
call check rpcResult~result[1] == '123', 'string value retained'
call check rpcResult~result[1]~isA(.JsonString), 'numeric string not coerced'
call check rpcResult~result[2] == 42, 'numeric rpcResult retained'
rpcResult=client~request('unlisted.method')
call check \rpcResult~ok & rpcResult~fault~code == -32601, 'method allowlist'
rpcResult=client~request('demo.fail')
call check \rpcResult~ok & rpcResult~fault~code == -32602, 'application error'
rpcResult=client~request('demo.echo', .directory~new)
call check rpcResult~ok, 'object params'
call check server~handleText('{bad json')~pos('"code":-32700') > 0, 'parse error'
call check server~handleText('{"jsonrpc":"2.0","id":5,"method":7}')~pos('"code":-32600') > 0, 'invalid request'
call check server~handleText('{"jsonrpc":"2.0","method":"demo.echo"}') == .nil, 'notification has no response'
call check server~handleText('[{"jsonrpc":"2.0","method":"demo.echo"}]') == .nil, 'notification batch has no response'
batch=server~handleText('[{"jsonrpc":"2.0","id":"1","method":"demo.echo"},{"jsonrpc":"2.0","method":"demo.echo"},0]')
batchObj=.json~fromJSON(batch)
call check batchObj~isA(.Array) & batchObj~items == 2, 'mixed batch excludes notification'
call check .json~fromJSON(server~handleText('[]'))~isA(.Directory), 'empty batch yields one error object'
rpcResult=server~handleText('{"jsonrpc":"2.0","id":"007","method":"demo.echo"}')
call check .json~fromJSON(rpcResult)['id']~isA(.JsonString), 'string ID type preserved'
call check rpcResult~pos('"007"') > 0, 'string ID leading zeros preserved'
rpcResult=server~handleText('{"jsonrpc":"2.0","id":false,"method":"demo.echo"}')
call check rpcResult~pos('"code":-32600') > 0, 'boolean ID rejected'
rpcResult=server~handleText('{"jsonrpc":"2.0","id":null,"method":"demo.echo"}')
call check rpcResult~pos('"result"') > 0, 'null ID valid though discouraged'
rpcResult=server~handleText('{"jsonrpc":"2.0","id":12,"method":"demo.echo","params":1}')
call check rpcResult~pos('"code":-32600') > 0, 'invalid params structure'
small=.JsonRpcDispatcher~new(registry,.JsonRpcCodec~new(80))
call check small~handleText('x'~copies(81))~pos('"code":-32700') > 0, 'size limit parser protection'
connectors=.JsonRpcConnectorRegistry~new
connectors~register('jsonrpc',client)
rpcResult=connectors~request('jsonrpc','demo.echo')
call check rpcResult~ok, 'named connector'
rpcResult=connectors~request('missing','demo.echo')
call check \rpcResult~ok, 'unknown connector failure is explicit'
call check connectors~notify('jsonrpc','demo.echo'), 'notification dispatch'
registry~register('demo.bug',.BugHandler~new)
rpcResult=server~handleText('{"jsonrpc":"2.0","method":"demo.bug","id":56}')
call check rpcResult~pos('"code":-32603') > 0, 'handler exception masked'
rpcResult=server~handleText('{"jsonrpc":"1.0","method":"demo.echo","id":56}')
call check rpcResult~pos('"code":-32600') > 0, 'JSON-RPC version strict'
rpcResult=server~handleText('{"jsonrpc":"2.0","method":"rpc.system","id":56}')
call check rpcResult~pos('"code":-32601') > 0, 'reserved rpc namespace'
rpcResult=server~handleText('[true, null]')
call check .json~fromJSON(rpcResult)~items == 2, 'invalid batch members get responses'
rpcResult=server~handleText('{"jsonrpc":"2.0","method":"demo.echo","id":123}')
call check .json~fromJSON(rpcResult)['id'] == 123, 'numeric ID echoed'
rpcResult=server~handleText('{"jsonrpc":"2.0","method":"demo.echo","id":"x","params":{"yes":true,"none":null}}')
call check rpcResult~pos('"yes":true') > 0, 'JSON boolean preserved'
call check rpcResult~pos('"none":null') > 0, 'JSON null preserved'
badClient=.JsonRpcClient~new(.BadErrorTransport~new)
rpcResult=badClient~request('demo.echo')
call check \rpcResult~ok & rpcResult~fault~message == 'Invalid remote response', 'reject string error code'
badClient=.JsonRpcClient~new(.BadIdTransport~new)
rpcResult=badClient~request('demo.echo')
call check \rpcResult~ok & rpcResult~fault~message == 'Invalid remote response', 'reject response ID mismatch'
direct=.JsonRpcDirectConnector~new(registry)
connectors~register('local',direct)
rpcResult=connectors~request('local','demo.echo',.Array~of(4,5))
call check rpcResult~ok & rpcResult~result~items == 2, 'native direct connector'
rpcResult=connectors~request('local','demo.fail')
call check \rpcResult~ok & rpcResult~fault~code == -32602, 'native direct error'
call check connectors~notify('local','demo.echo'), 'native direct notification'
sendFailure=.JsonRpcClient~new(.FalseSendTransport~new)
call check \sendFailure~notify('demo.echo'), 'notification send failure not misreported as success'
say 'PASS' checks 'JSON-RPC Fabric checks' 
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
  use strict arg methodName, params, context
  return params
::class BadErrorTransport
::method exchange
  use strict arg jsonText
  return '{"jsonrpc":"2.0","id":"r1","error":{"code":"-32601","message":"oops"}}'
::method send
  use strict arg jsonText
  return .true
::class FalseSendTransport
::method exchange
  use strict arg jsonText
  return .nil
::method send
  use strict arg jsonText
  return .false
::class BadIdTransport
::method exchange
  use strict arg jsonText
  return '{"jsonrpc":"2.0","id":"other","result":1}'
::method send
  use strict arg jsonText
  return .true
::class BugHandler
::method invoke
  raise syntax 93.900 additional('sensitive internal failure')
::class FailureHandler
::method invoke
  use strict arg methodName, params, context
  return .JsonRpcFault~new(-32602,'Invalid params')
::requires 'JsonRpcFabric.cls'
::requires 'JsonRpcLegacyConnectorRegistry.cls'
