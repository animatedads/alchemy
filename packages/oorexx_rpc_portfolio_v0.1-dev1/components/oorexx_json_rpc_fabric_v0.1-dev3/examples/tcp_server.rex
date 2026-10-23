/* Demonstration ONLY: loopback server; unauthenticated and single-threaded.
 * Requires Socket Provider v0.1-dev14 in REXX_PATH. Do not expose publicly.
 * Usage: rexx tcp_server.rex PORT [CONNECTION_COUNT]
 */
parse arg port count
if \datatype(port,'W') | port<1024 | port>65535 then do
  say 'usage: tcp_server.rex PORT [CONNECTION_COUNT]'; exit 2
end
if count=='' then count=3
if \datatype(count,'W') | count<1 | count>1000 then exit 2
addresses=.RegisteredSocketAddressProvider~new
addresses~register('rpc.demo',.SocketAddresses~tcp('127.0.0.1',port))
provider=.SocketProvider~new(addresses)
provider~registerBinding('TCP',.RxSockTcpBinding~new)
listener=provider~listener('rpc.demo',8)
if listener==.nil then exit 3
services=.JsonRpcMethodRegistry~new
services~register('demo.echo',.DemoEcho~new)
server=.JsonRpcSocketServer~new(.JsonRpcDispatcher~new(services))
do i=1 to count
  ok=server~serveOne(listener)
  if \ok then do
    ignore=listener~close
    exit 4
  end
end
ignore=listener~close
exit 0
::class DemoEcho
::method invoke
  use strict arg name, params, context
  return params
::requires 'JsonRpcSocketTransport.cls'
::requires 'SocketProvider.cls'
::requires 'RxSockSocketBinding.cls'
