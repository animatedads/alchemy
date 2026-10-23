/* Actual TCP, Socket Provider dev14 with runtime socket.cls. No raw socket calls. */
checks=0
port=39483
addresses=.RegisteredSocketAddressProvider~new
addresses~register('rpc.test',.SocketAddresses~tcp('127.0.0.1',port))
provider=.SocketProvider~new(addresses)
provider~registerBinding('TCP',.RxSockTcpBinding~new)
listener=provider~listener('rpc.test',8)
if listener==.nil then do
  say 'FAIL cannot bind TCP listener at port' port
  exit 1
end
registry=.JsonRpcMethodRegistry~new
registry~register('service.echo',.EchoHandler~new)
dispatcher=.JsonRpcDispatcher~new(registry)
server=.JsonRpcSocketServer~new(dispatcher)
worker=.RpcWorker~new
worker~run(server,listener,3)
call SysSleep .1
client=.JsonRpcClient~new(.JsonRpcSocketTransport~new(provider,'rpc.test'))
answer=client~request('service.echo',.array~of(.JsonString~new('tcp'),17))
call check answer~ok, 'live TCP RPC request success'
call check answer~result[1]=='tcp', 'live TCP returned string'
call check answer~result[2]==17, 'live TCP returned number'
call check client~notify('service.echo'), 'live TCP notification sent'
answer=client~request('service.echo',.array~of(99))
call check answer~ok & answer~result[1]==99, 'second TCP RPC request success'
call check worker~processed==3, 'server accepted three independent TCP connections'
say 'PASS' checks 'live TCP Socket Provider checks'
exit 0

check:
  use strict arg ok, description
  if \ok then do
    say 'FAIL' description
    exit 1
  end
  checks=checks+1
return

::class EchoHandler
::method invoke
  use strict arg name, params, context
  return params

::class RpcWorker
::method init
  expose processed
  processed=0
::attribute processed get
::method run
  expose processed
  use strict arg server, listener, howMany
  reply
  do i=1 to howMany
    ok=server~serveOne(listener)
    if ok then processed+=1
  end
  ignore=listener~close
  return

::requires 'JsonRpcSocketTransport.cls'
::requires 'SocketProvider.cls'
::requires 'RxSockSocketBinding.cls'
