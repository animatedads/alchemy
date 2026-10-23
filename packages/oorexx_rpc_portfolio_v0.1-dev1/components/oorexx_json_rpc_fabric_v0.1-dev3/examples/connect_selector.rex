/* Integration demonstration. REXX_PATH must point to the validated exact
 * Connect Selector source and this package's source directories.
 */
services=.JsonRpcMethodRegistry~new
services~register('catalog.lookup',.CatalogHandler~new)
selector=.ConnectSelector~new
selector~register('DIRECT',.ConnectCallAdapter~new(.JsonRpcDirectConnector~new(services),'DIRECT'))
selector~register('RPC',.ConnectCallAdapter~new(.JsonRpcClient~new(.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(services))),'RPC'))
params=.Array~of(.JsonString~new('example-7'))
do preference over .Array~of('DIRECT','RPC')
  intent=.ConnectIntent~new('catalog.lookup','request','immediate',preference)
  reply=selector~execute(intent,params)
  if \reply~ok then do
    say preference 'FAILED' reply~code
    exit 1
  end
  say preference reply~value
end
exit 0
::class CatalogHandler
::method invoke
  use strict arg methodName,params,context
  return .JsonString~new('found:'||params[1])
::requires 'JsonRpcFabric.cls'
::requires 'ConnectSelector.cls'
