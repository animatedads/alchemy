/* IMAP TCP/TLS transport adapter -- v0.1-dev2.
 *
 * IMAP is always the application protocol. Transport security is a separate,
 * explicit axis: PLAINTEXT, STARTTLS_REQUIRED, or IMPLICIT_TLS.  Human labels
 * such as "SSL" or "TLS" are deliberately rejected as ambiguous.
 *
 * This adapter reuses the already-qualified API Client OpenSSL/Foreign Runtime
 * TLS machinery. It is not an HTTP dependency at the protocol layer; a future
 * general oorexx_net_stream package can replace this adapter unchanged above.
 */

::class ImapSocketTransportConfig public
::attribute host
::attribute port
::attribute security
::attribute mode
::attribute bridgeDirectory
::attribute caFile
::attribute verifyPeer
::attribute readTimeout
::attribute writeTimeout
::attribute readChunkSize
::method init
  expose host port security mode bridgeDirectory caFile verifyPeer readTimeout writeTimeout readChunkSize
  host = ""; port = 0; security = ""; mode = ""; bridgeDirectory = ""; caFile = ""
  verifyPeer = .true; readTimeout = 30; writeTimeout = 30; readChunkSize = 16384
::method applyEndpoint
  expose host port security mode
  use strict arg endpoint
  endpoint~validate
  host = endpoint~host
  port = endpoint~port
  security = endpoint~security
  mode = ""
  return self
::method effectiveSecurity
  expose security mode
  if security~strip <> "" & mode~strip <> "" then do
    a = .ImapTransportSecurity~canonical(security)
    b = .ImapTransportSecurity~canonical(mode)
    if a <> b then raise syntax 88.900 array("IMAP_SECURITY_MODE_CONFLICT", security, mode)
    return a
  end
  if security~strip <> "" then return .ImapTransportSecurity~canonical(security)
  if mode~strip <> "" then return .ImapTransportSecurity~canonical(mode)
  return "IMPLICIT_TLS"
::method validate
  expose host port security mode bridgeDirectory verifyPeer readTimeout writeTimeout readChunkSize
  if host~strip = "" then raise syntax 88.900 array("IMAP host required")
  security = self~effectiveSecurity
  /* mode survives only as a compatibility mirror for dev1 callers. */
  mode = security
  if port = 0 then port = .ImapTransportSecurity~defaultPort(security)
  if port < 1 | port > 65535 then raise syntax 88.900 array("IMAP port invalid", port)
  if security <> "PLAINTEXT" & bridgeDirectory~strip = "" then raise syntax 88.900 array("OpenSSL bridgeDirectory required for IMAP TLS")
  if readTimeout <= 0 | writeTimeout <= 0 then raise syntax 88.900 array("IMAP transport timeout invalid")
  if readChunkSize < 256 then raise syntax 88.900 array("IMAP transport readChunkSize too small")
  return self

::class ImapSocketTransport public
::attribute encrypted get
::attribute security get
::attribute tlsProtocol get
::attribute tlsCipher get
::attribute lastError get
::method init
  expose config socket tlsContext tlsSession encrypted security tlsProtocol tlsCipher lastError closed
  use strict arg configArg
  config = configArg~validate
  security = config~security
  socket = .Socket~new("AF_INET", "SOCK_STREAM", "IPPROTO_TCP")
  address = .InetAddress~new(config~host, config~port)
  rc = socket~connect(address)
  if rc <> 0 then do; lastError = "connect errno=" || socket~errno; socket~close; raise syntax 88.900 array("IMAP_CONNECT_FAILED", lastError); end
  if socket~ioctl("FIONBIO", 1) == .nil then do; lastError = "nonblock errno=" || socket~errno; socket~close; raise syntax 88.900 array("IMAP_SOCKET_NONBLOCK_FAILED", lastError); end
  tlsContext = .nil; tlsSession = .nil; encrypted = .false; tlsProtocol = ""; tlsCipher = ""; lastError = ""; closed = .false
  if security = "IMPLICIT_TLS" then do
    if \self~startTls then do; self~close; raise syntax 88.900 array("IMAP_TLS_HANDSHAKE_FAILED", lastError); end
  end
::method requiresStartTls
  expose security
  return security = "STARTTLS_REQUIRED"
::method startTls
  expose config socket tlsContext tlsSession encrypted tlsProtocol tlsCipher lastError
  if encrypted then return .true
  httpConfig = .ApiHttpTransportConfig~new
  httpConfig~bridgeDirectory = config~bridgeDirectory
  httpConfig~caFile = config~caFile
  httpConfig~verifyPeer = config~verifyPeer
  httpConfig~readTimeout = config~readTimeout
  httpConfig~writeTimeout = config~writeTimeout
  httpConfig~readChunkSize = config~readChunkSize
  httpConfig~httpVersionPolicy = "HTTP1_ONLY"
  signal on syntax name tlsFailure
  tlsContext = .ApiTlsClientContext~new(httpConfig)
  tlsSession = .ApiTlsClientSession~new(tlsContext, socket, config~host, httpConfig)
  if \tlsSession~handshake then do; lastError = tlsSession~lastError; return .false; end
  encrypted = .true; tlsProtocol = tlsSession~protocol; tlsCipher = tlsSession~cipher
  signal off syntax
  return .true
tlsFailure:
  signal off syntax
  lastError = condition("D")
  return .false
::method read
  expose config socket tlsSession encrypted lastError
  use strict arg maximum = 0
  if encrypted then do
    value = tlsSession~read(maximum)
    if value == .nil then lastError = tlsSession~lastError
    return value
  end
  ask = maximum; if ask <= 0 | ask > config~readChunkSize then ask = config~readChunkSize
  reads = .array~of(socket); writes = .array~new; excepts = .array~of(socket)
  rc = socket~select(reads, writes, excepts, config~readTimeout)
  if rc == .nil then do; lastError = "socket select errno=" || socket~errno; return .nil; end
  if rc = 0 then do; lastError = "socket read timeout"; return .nil; end
  value = socket~recv(ask)
  if value == .nil then lastError = "socket recv errno=" || socket~errno
  return value
::method writeAll
  expose config socket tlsSession encrypted lastError
  use strict arg data
  if encrypted then do
    ok = tlsSession~writeAll(data)
    if \ok then lastError = tlsSession~lastError
    return ok
  end
  offset = 1
  do while offset <= data~length
    rc = socket~send(data~substr(offset))
    if rc > 0 then do; offset += rc; iterate; end
    writes = .array~of(socket); reads = .array~new; excepts = .array~of(socket)
    ready = socket~select(reads, writes, excepts, config~writeTimeout)
    if ready == .nil | ready = 0 then do; lastError = "socket write timeout/error errno=" || socket~errno; return .false; end
  end
  return .true
::method close
  expose socket tlsSession tlsContext closed
  if closed then return
  closed = .true
  if tlsSession <> .nil then do; tlsSession~close; tlsSession = .nil; end
  if tlsContext <> .nil then do; tlsContext~close; tlsContext = .nil; end
  if socket <> .nil then do; socket~close; socket = .nil; end
::method uninit
  self~close

::requires "ImapSession.cls"
::requires "ApiHttpTransport.cls"
::requires "socket.cls"
