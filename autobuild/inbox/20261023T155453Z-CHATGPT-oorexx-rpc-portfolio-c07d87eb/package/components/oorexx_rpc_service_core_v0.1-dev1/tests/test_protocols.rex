/* Optional integration regression, real SOAP and JSON-RPC envelopes. */
checks=0
registry=.RpcServiceRegistry~new
instance=.Catalog~new
unused=registry~registerMethod('catalog','echo',instance,'readItem')
dispatcher=.RpcServiceDispatcher~new(registry)
soap=.SoapRpcServer~new(dispatcher,'catalog','urn:alchemy:catalog:v1')
soapClient=.SoapRpcClient~new(.SoapLoopbackTransport~new(soap),'catalog','urn:alchemy:catalog:v1')
params=.directory~new
params['message']='named-object-method'
answer=soapClient~request('catalog.echo',params)
call check answer~ok & answer~value == 'named-object-method','SOAP dispatch to registered object/method'
jsonRegistry=.JsonRpcMethodRegistry~new
unused=jsonRegistry~register('catalog.echo',.RpcJsonServiceBridge~new(dispatcher,'catalog'))
jsonClient=.JsonRpcClient~new(.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(jsonRegistry)))
answer=jsonClient~request('catalog.echo',params)
call check answer~ok & answer~result == 'named-object-method','JSON-RPC dispatch to same object/method'
answer=jsonClient~request('catalog.private',params)
call check \answer~ok & answer~fault~code == -32601,'JSON-RPC cannot invoke unregistered methods'
answer=soapClient~request('catalog.private',params)
call check \answer~ok & answer~fault~message == 'Operation not found','SOAP cannot invoke unregistered methods'
call check instance~calls == 2,'identical instance receives both protocols'
say 'PASS' checks 'SOAP/JSON shared object registry checks'
exit 0
check:
  use strict arg expr,label
  if \expr then do
    say 'FAIL' label
    exit 1
  end
  checks += 1
return
::class Catalog
::attribute calls get
::method init
  expose calls
  calls=0
::method readItem
  expose calls
  use strict arg params,context
  calls+=1
  return params['message']
::method private
  return 'unpublished'
::requires 'SoapRpcBinding.cls'
::requires 'RpcJsonServiceBridge.cls'
