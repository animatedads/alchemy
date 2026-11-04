/* ooRexx IMAP server/client Socket Provider bridge v0.1-dev13.
 *
 * Socket Provider owns address resolution and native socket acquisition.
 * IMAP owns line/literal framing and protocol state.  This adapter deliberately
 * does not infer TLS from a TCP endpoint or bypass the selected socket family.
 */
::class ImapSocketProviderBuild public
::constant API "imap.socket.provider.binding/0.1"

::class ImapSocketStreamTransport public
::method init
  expose endpoint buffer closed
  use strict arg endpointArg
  if endpointArg == .nil then raise syntax 88.900 array("IMAP_SOCKET_ENDPOINT_REQUIRED")
  if \endpointArg~hasMethod("RECV") then raise syntax 88.900 array("IMAP_SOCKET_ENDPOINT_RECV_REQUIRED")
  if \endpointArg~hasMethod("SENDALL") then raise syntax 88.900 array("IMAP_SOCKET_ENDPOINT_SENDALL_REQUIRED")
  endpoint = endpointArg
  buffer = ""
  closed = .false
::method endpoint
  expose endpoint
  return endpoint
::method readLine
  expose endpoint buffer closed
  numeric digits 30
  use strict arg maximumBytes = 1048576
  limit = .ImapNumber~whole(maximumBytes,"IMAP_SOCKET_MAX_LINE",1)
  if closed then return .nil
  crlf = '0d0a'x
  do forever
    p = buffer~pos(crlf)
    if p > 0 then do
      if p - 1 > limit then raise syntax 88.900 array("IMAP_SERVER_LINE_TOO_LARGE",p - 1,limit)
      line = buffer~left(p - 1)
      buffer = buffer~substr(p + 2)
      return line
    end
    if buffer~length > limit then raise syntax 88.900 array("IMAP_SERVER_LINE_TOO_LARGE",buffer~length,limit)
    chunk = endpoint~recv(16384)
    if chunk == .nil then do; closed = .true; return .nil; end
    if chunk = "" then do; closed = .true; return .nil; end
    buffer = buffer || chunk
  end
::method readExact
  expose endpoint buffer closed
  numeric digits 30
  use strict arg byteCountArg
  wanted = .ImapNumber~whole(byteCountArg,"IMAP_SOCKET_READ_EXACT",0,2147483648)
  if closed then return .nil
  do while buffer~length < wanted
    chunk = endpoint~recv(16384)
    if chunk == .nil then do; closed = .true; return .nil; end
    if chunk = "" then do; closed = .true; return .nil; end
    buffer = buffer || chunk
  end
  bytes = buffer~left(wanted)
  buffer = buffer~substr(wanted + 1)
  return bytes
::method supportsReadiness
  expose endpoint buffer
  if buffer~pos('0d0a'x) > 0 then return .true
  if endpoint~hasMethod("WAITREADY") then return .true
  if endpoint~hasMethod("RAW") then do
    raw = endpoint~raw
    if raw <> .nil then do
      if raw~hasMethod("SELECT") then return .true
    end
  end
  return .false
::method waitReadable
  expose endpoint buffer closed
  use strict arg timeoutSeconds = 1
  if closed then return -1
  if buffer~pos('0d0a'x) > 0 then return 1
  if endpoint~hasMethod("WAITREADY") then do
    ready = endpoint~waitReady(timeoutSeconds)
    if ready == .true then return 1
    if ready == .false then return 0
    return ready
  end
  if \endpoint~hasMethod("RAW") then return -2
  raw = endpoint~raw
  if raw == .nil then return -2
  if \raw~hasMethod("SELECT") then return -2
  reads = .array~of(raw)
  writes = .array~new
  excepts = .array~new
  return raw~select(reads, writes, excepts, timeoutSeconds)
::method writeAll
  expose endpoint closed
  use strict arg bytes
  if closed then return .false
  count = endpoint~sendAll(bytes)
  if count == .nil then return .false
  if datatype(count,"W") then return count = bytes~length
  return count <> .false
::method close
  expose endpoint closed
  if closed then return .true
  ignore = endpoint~close
  closed = .true
  return .true

::class ImapSocketProviderServer public
::method init
  expose socketProvider logicalName backlog observer
  numeric digits 30
  use strict arg socketProviderArg, logicalNameArg, backlogArg = 32, observerArg = .nil
  if socketProviderArg == .nil then raise syntax 88.900 array("IMAP_SOCKET_PROVIDER_REQUIRED")
  socketProvider = socketProviderArg
  observer = observerArg
  logicalName = logicalNameArg~string~strip
  if logicalName = "" then raise syntax 88.900 array("IMAP_SOCKET_LOGICAL_NAME_REQUIRED")
  backlog = .ImapNumber~whole(backlogArg,"IMAP_SOCKET_BACKLOG",1,65535)
::method listener
  expose socketProvider logicalName backlog
  return socketProvider~listener(logicalName,backlog)
::method serveOne
  expose socketProvider logicalName backlog observer
  use strict arg session
  listener = socketProvider~listener(logicalName,backlog)
  if listener == .nil then return .ImapServerResult~failure("IMAP_SOCKET_LISTENER_UNAVAILABLE")
  connection = listener~accept
  if connection == .nil then do
    ignore = listener~close
    return .ImapServerResult~failure("IMAP_SOCKET_ACCEPT_FAILED")
  end
  transport = .ImapSocketStreamTransport~new(connection)
  endpoint = .ImapServerEndpoint~new(session,100000,1048576,observer)
  served = endpoint~serve(transport)
  ignore = transport~close
  ignore = listener~close
  return served

::requires "ImapServer.cls"
::requires "SocketProvider.cls"
