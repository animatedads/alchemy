/* Demonstration only; same framing and Socket Provider v0.1-dev14. */
parse arg port
if \datatype(port,'W') | port<1024 | port>65535 then exit 2
addresses=.RegisteredSocketAddressProvider~new
addresses~register('rpc.demo',.SocketAddresses~tcp('127.0.0.1',port))
provider=.SocketProvider~new(addresses)
provider~registerBinding('TCP',.RxSockTcpBinding~new)
client=.JsonRpcClient~new(.JsonRpcSocketTransport~new(provider,'rpc.demo'))
response=client~request('demo.echo',.array~of(.JsonString~new('process'),2))
if \response~ok then exit 3
if response~result[1]<>'process' | response~result[2]<>2 then exit 4
sent=client~notify('demo.echo',.array~of(15))
if \sent then exit 5
response=client~request('demo.echo',.array~of(6))
if \response~ok then exit 6
if response~result[1]<>6 then exit 7
say 'PASS cross-process TCP request/notification/reply'
exit 0
::requires 'JsonRpcSocketTransport.cls'
::requires 'SocketProvider.cls'
::requires 'RxSockSocketBinding.cls'
