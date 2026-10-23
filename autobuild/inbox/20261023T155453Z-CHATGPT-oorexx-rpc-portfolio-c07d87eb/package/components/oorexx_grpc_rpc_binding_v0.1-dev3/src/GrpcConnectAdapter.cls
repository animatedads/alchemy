/* Optional gRPC connector for existing ConnectSelector v0.1-dev2.
 * Constructor injects a unary transport/client; no HTTP/2 implementation here.
 * ConnectSelector, not this adapter, selects RPC vs Direct vs Queue.
 */
::class GrpcConnectAdapter public
::method init
  expose client destination
  use strict arg client, destination = ''
  if \client~hasMethod('request') then raise syntax 93.900 additional('gRPC client requires request(operation,payload)')
  destination=destination~string~translate
::method supports
  expose destination
  use strict arg intent
  return intent~mode=='REQUEST' & intent~requirement\=='DURABLE' & intent~destination~string~translate==destination
::method execute
  expose client
  use strict arg intent,payload=.nil
  if \self~supports(intent) then return .ConnectResult~failure('RPC','UNSUPPORTED','gRPC adapter supports only immediate request/reply')
  reply=client~request(intent~operation,payload)
  if \reply~ok then return .ConnectResult~failure('RPC','CALL_FAILED','gRPC call did not complete',reply)
  return .ConnectResult~success('RPC',reply~value,.true,.true,.false)
::requires 'ConnectSelector.cls'
