checks=0
registry=.RpcServiceRegistry~new
registry~register('catalog','echo',.Echo~new)
dispatcher=.RpcServiceDispatcher~new(registry)
soap=.SoapRpcServer~new(dispatcher,'catalog','urn:alchemy:catalog:v1')
args=.directory~new
args['message']='one source of truth'
soapClient=.SoapRpcClient~new(.SoapLoopbackTransport~new(soap),'catalog','urn:alchemy:catalog:v1')
answer=soapClient~request('catalog.echo',args)
call check answer~ok & answer~value==args['message'],'SOAP shared handler'
jsonRegistry=.JsonRpcMethodRegistry~new
jsonRegistry~register('catalog.echo',.RpcJsonServiceBridge~new(dispatcher,'catalog'))
json=.JsonRpcClient~new(.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(jsonRegistry)))
answer=json~request('catalog.echo',args)
call check answer~ok & answer~result==args['message'],'JSON shared handler'
policy=.ConnectRoutePolicy~new
policy~allow('catalog.echo','REQUEST','RPC','SOAPDEST')
connect=.ConnectSelector~new(policy)
connect~register('RPC',.SoapConnectAdapter~new(soapClient,'SOAPDEST'),'SOAPDEST')
intent=.ConnectIntent~new('catalog.echo','REQUEST','IMMEDIATE','RPC','SOAPDEST')
answer=connect~execute(intent,args)
call check answer~ok & answer~value==args['message'],'ConnectSelector SOAP RPC request'
intent=.ConnectIntent~new('catalog.echo','NOTIFY','IMMEDIATE','RPC','SOAPDEST')
answer=connect~execute(intent,args)
call check \answer~ok,'SOAP notification rejected by ConnectSelector'
intent=.ConnectIntent~new('catalog.echo','ENQUEUE','DURABLE','RPC','SOAPDEST')
answer=connect~execute(intent,args)
call check \answer~ok,'SOAP durability not fabricated'
intent=.ConnectIntent~new('catalog.echo','REQUEST','IMMEDIATE','RPC','OTHER')
answer=connect~execute(intent,args)
call check \answer~ok,'ConnectSelector destination binding'
say 'PASS' checks 'shared dispatch/selector checks'
exit 0
check:
  use strict arg condition,name
  if \condition then do
    say 'FAIL' name
    exit 1
  end
  checks += 1
return
::class Echo
::method invoke
  use strict arg op,params,ctx
  return params['message']
::requires 'SoapRpcBinding.cls'
::requires 'SoapConnectAdapter.cls'
::requires 'RpcJsonServiceBridge.cls'
