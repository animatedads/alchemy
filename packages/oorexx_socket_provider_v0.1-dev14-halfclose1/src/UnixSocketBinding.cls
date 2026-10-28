/* UnixSocketBinding.cls - AF_UNIX family binding
 * v0.1-dev14-halfclose1: connections get a UnixHalfCloser, so
 * ProviderSocketConnection~shutdownSend ends the send direction.
 */
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
  return .UnixProviderSocketListener~new(socket,address,.UnixHalfCloser~new)
::method sender
  use strict arg address
  if address~transport<>.SocketTransportKind~UNIX then raise syntax 88.900 array("Unix binding requires UNIX address")
  socket=.UnixSocket~new("SOCK_STREAM")
  if socket~connect(.UnixAddress~pathname(address~path))<>0 then do; socket~close; return .nil; end
  return .ProviderSocketConnection~new(socket,address,.UnixHalfCloser~new)

::class UnixProviderSocketListener public subclass ProviderSocketListener
::method close
  address=self~address
  rc=self~close:super
  ignore=.UnixSocket~unlinkPath(address~path)
  return rc

/* Half-close for ooRexx Unix Socket v0.6: UnixSocket~shutdown(SHUT_WR)
 * (unixsocket.cls, method shutdown). SHUT_WR is 1 on Linux
 * (bridge/libc-af-unix.bridge.json); unixsocket.cls keeps its constant
 * routine private, so the value is stated here. */
::class UnixHalfCloser public
::constant SHUT_WR 1
::method shutdownSend
  use strict arg socket
  if socket=.nil then return .false
  if \socket~hasMethod("SHUTDOWN") then return .false
  return socket~shutdown(self~SHUT_WR)=0

::requires "SocketProvider.cls"
::requires "unixsocket.cls"
