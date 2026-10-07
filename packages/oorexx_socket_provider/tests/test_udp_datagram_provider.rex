call RxFuncAdd "SockLoadFuncs", "rxsock", "SockLoadFuncs"
call SockLoadFuncs
ap=.RegisteredSocketAddressProvider~new
listenerAddress=.SocketAddresses~udp('127.0.0.1',0,.false,'udp.listen')
ap~register('udp.listen',listenerAddress,'LISTENER')
provider=.SocketSelector~new(ap)
provider~registerBinding(.SocketTransportKind~UDP,.RxSockUdpBinding~new)
listener=provider~listener('udp.listen')
call assert listener<>.nil,'listener acquired'
call assert listener~localPort>0,'ephemeral local port assigned'
senderAddress=.SocketAddresses~udp('127.0.0.1',listener~localPort,.false,'udp.send')
sender=provider~senderAt(senderAddress)
call assert sender<>.nil,'sender acquired'
msg='udp-provider-dev10'
call assert sender~send(msg)=length(msg),'send exact bytes'
d=listener~recvFrom(65535,1)
call assert d<>.nil,'datagram received'
call assert d[1]=msg,'payload preserved'
call assert d[2]='127.0.0.1','source address retained'
call assert d[3]>0,'source port retained'
ignore=sender~close
ignore=listener~close
say 'PASS UDP SocketProvider datagram dev10'
exit 0
assert: procedure
  use strict arg ok, why
  if \ok then do; say 'FAIL' why; exit 1; end
  return
::requires 'SocketProvider.cls'
::requires 'RxSockUdpBinding.cls'
