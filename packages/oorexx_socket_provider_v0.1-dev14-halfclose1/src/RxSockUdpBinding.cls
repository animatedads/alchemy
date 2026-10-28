/* Merged at the dev11 collision reconciliation; retained unchanged by Socket Provider v0.1-dev12. */
/* RxSockUdpBinding.cls - UDP datagram family binding.
 * The provider owns socket acquisition; protocol packages own their wire format.
 */
::class RxSockUdpBinding public subclass SocketTransportBinding
::method listener
  use strict arg address, backlog=32
  if address~transport<>.SocketTransportKind~UDP then raise syntax 88.900 array("RxSock UDP binding requires UDP address")
  socket=SockSocket("AF_INET","SOCK_DGRAM",0)
  if socket<0 then return .nil
  local.!family="AF_INET"
  local.!addr=address~host
  local.!port=address~port
  if SockBind(socket,"local.!")<0 then do
    ignore=SockClose(socket)
    return .nil
  end
  if SockGetSockName(socket,"actual.!")<0 then do
    ignore=SockClose(socket)
    return .nil
  end
  return .ProviderDatagramEndpoint~new(socket,address,.SocketRole~LISTENER,"",0,actual.!addr,actual.!port)
::method sender
  use strict arg address
  if address~transport<>.SocketTransportKind~UDP then raise syntax 88.900 array("RxSock UDP binding requires UDP address")
  if address~port<1 then raise syntax 88.900 array("UDP sender requires a non-zero remote port")
  socket=SockSocket("AF_INET","SOCK_DGRAM",0)
  if socket<0 then return .nil
  local.!family="AF_INET"
  local.!addr="0.0.0.0"
  local.!port=0
  if SockBind(socket,"local.!")<0 then do
    ignore=SockClose(socket)
    return .nil
  end
  if SockGetSockName(socket,"actual.!")<0 then do
    ignore=SockClose(socket)
    return .nil
  end
  return .ProviderDatagramEndpoint~new(socket,address,.SocketRole~SENDER,address~host,address~port,actual.!addr,actual.!port)

::requires "SocketProvider.cls"
::requires "rxsock" LIBRARY
