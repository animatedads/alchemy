/* RxSockSocketBinding.cls - TCP family binding
 * v0.1-dev14-halfclose1: connections get an RxSockHalfCloser, so
 * ProviderSocketConnection~shutdownSend ends the send direction (FIN).
 */
::class RxSockTcpBinding public subclass SocketTransportBinding
::method listener
  use strict arg address, backlog=32
  if address~transport<>.SocketTransportKind~TCP then raise syntax 88.900 array("RxSock TCP binding requires TCP address")
  socket=.Socket~new()
  if socket=-1 then return .nil
  if socket~setOption("SO_REUSEADDR",1)=-1 then do; socket~close; return .nil; end
  inet=.InetAddress~new(address~host,address~port)
  if socket~bind(inet)=-1 then do; socket~close; return .nil; end
  if socket~listen(backlog)=-1 then do; socket~close; return .nil; end
  return .ProviderSocketListener~new(socket,address,.RxSockHalfCloser~new)
::method sender
  use strict arg address
  if address~transport<>.SocketTransportKind~TCP then raise syntax 88.900 array("RxSock TCP binding requires TCP address")
  socket=.Socket~new()
  if socket=-1 then return .nil
  inet=.InetAddress~new(address~host,address~port)
  if socket~connect(inet)=-1 then do; socket~close; return .nil; end
  return .ProviderSocketConnection~new(socket,address,.RxSockHalfCloser~new)

/* Half-close for an ooRexx .Socket: shutdown(fd, SHUT_WR) through the RxSock
 * function package that socket.cls already loads. No native code is added.
 * Assumption to qualify on ooRexx 5.3.0 r13196 (tests/test_rxsock_shutdown_route.rex):
 * the .Socket string value is its descriptor, and SockShutDown(fd, 1)
 * returns 0 on success. 1 is SHUT_WR on Linux. */
::class RxSockHalfCloser public
::constant SHUT_WR 1
::method shutdownSend
  use strict arg socket
  if socket=.nil then return .false
  descriptor=socket~string
  if \datatype(descriptor,"W") then return .false
  if descriptor<0 then return .false
  return SockShutDown(descriptor,self~SHUT_WR)=0

::requires "SocketProvider.cls"
::requires "socket.cls"
