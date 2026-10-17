parse arg peer connector
if peer='' | connector='' then do
  say 'FAIL: usage test_socket_selector_xtp.rex PEER XTP_CONNECT'
  exit 2
end
addresses=.RegisteredSocketAddressProvider~new
addresses~register('fabric.control',.SocketAddresses~xtp(peer))
sockets=.SocketSelector~new(addresses)
sockets~registerBinding('XTP',.RexxXtpSocketBinding~new(.XtpSocketBackend~new(connector)))
ep=sockets~sender('fabric.control')
if ep=.nil then do; say 'FAIL: no XTP endpoint'; exit 3; end
if ep~address~transport<>.SocketTransportKind~XTP then do; say 'FAIL: wrong transport'; exit 4; end
payload='SocketSelector -> XTP'
n=ep~send(payload)
if n<>length(payload) then do; say 'FAIL: XTP send rc='n; exit 5; end
say 'PASS SocketSelector XTP real send bytes='n
exit 0
::requires "XtpSocketProvider.cls"
