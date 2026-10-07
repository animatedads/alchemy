/* UnixSocketBinding.cls - AF_UNIX family binding */
::class RexxUnixSocketBinding public subclass SocketTransportBinding
::method listener
  use strict arg address, backlog=32
  if address~transport<>.SocketTransportKind~UNIX then raise syntax 88.900 array("Unix binding requires UNIX address")
  ignore=.UnixSocket~unlinkPath(address~path)
  socket=.UnixSocket~new("SOCK_STREAM")
  if socket~bind(.UnixAddress~pathname(address~path))<>0 then do; socket~close; return .nil; end
  if socket~listen(backlog)<>0 then do
    socket~close
    ignore=.UnixSocket~unlinkPath(address~path)
    return .nil
  end
  return .UnixProviderSocketListener~new(socket,address)
::method sender
  use strict arg address
  if address~transport<>.SocketTransportKind~UNIX then raise syntax 88.900 array("Unix binding requires UNIX address")
  socket=.UnixSocket~new("SOCK_STREAM")
  if socket~connect(.UnixAddress~pathname(address~path))<>0 then do; socket~close; return .nil; end
  return .ProviderSocketConnection~new(socket,address)

::class UnixProviderSocketListener public subclass ProviderSocketListener
::method close
  address=self~address
  rc=self~close:super
  ignore=.UnixSocket~unlinkPath(address~path)
  return rc
::requires "SocketProvider.cls"
::requires "unixsocket.cls"
