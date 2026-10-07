/* RxSockSocketBinding.cls - TCP family binding */
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
  return .ProviderSocketListener~new(socket,address)
::method sender
  use strict arg address
  if address~transport<>.SocketTransportKind~TCP then raise syntax 88.900 array("RxSock TCP binding requires TCP address")
  socket=.Socket~new()
  if socket=-1 then return .nil
  inet=.InetAddress~new(address~host,address~port)
  if socket~connect(inet)=-1 then do; socket~close; return .nil; end
  return .ProviderSocketConnection~new(socket,address)
::requires "SocketProvider.cls"
::requires "socket.cls"
