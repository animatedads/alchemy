/*
 * TerminalBrokerSocket.cls - authenticated local socket host for the
 * serialized TerminalSessionBroker protocol, v0.17.
 *
 * ooRexx r13196 RxSock supports AF_INET but not AF_UNIX.  This adapter does
 * not fake Unix-domain socket semantics through a helper process.  Instead it
 * provides an actual ooRexx-owned listener which is hard-bound to 127.0.0.1
 * and adds explicit mutual HMAC authentication and per-connection replay
 * protection before any request reaches TerminalBrokerProtocolEndpoint.
 *
 * The transport principal is established by the socket handshake.  It is
 * then passed separately to endpoint~handleFrame(principal, frame); a broker
 * JSON request can never assert or replace that identity.
 *
 * Security properties:
 *   - listener bind address is fixed to IPv4 loopback;
 *   - no default long-lived authentication key exists;
 *   - configured peer keys never have getters and are never Alchemy state;
 *   - fresh 256-bit client/server nonces bind each authenticated connection;
 *   - every broker request and response is HMAC-SHA-512 authenticated;
 *   - strictly increasing sequence numbers reject same-connection replay;
 *   - HMAC comparisons use CryptoUtils~secureEquals();
 *   - endpoint bearer tokens, WLU handles and terminal secret rules remain
 *     above/below this transport exactly as defined by v0.15;
 *   - the host never owns or closes TerminalSessionBrokerProtocolEndpoint;
 *     socket lifecycle and terminal lifecycle remain separate.
 *
 * This layer authenticates and integrity-protects local IPC; it is not a
 * confidentiality layer.  Remote NONDISPLAY input is still forbidden by the
 * endpoint.  A future AF_UNIX/TLS adapter can implement the same host contract
 * without changing terminal ownership semantics.
 */

::class TerminalBrokerSocketBuild public
::constant RELEASE "0.17"
::constant PROTOCOL "terminal.broker.socket/0.1"
::constant BIND_HOST "127.0.0.1"
::constant DEFAULT_RECORD_LIMIT 262144
::constant DEFAULT_REQUEST_LIMIT 256


::class TerminalBrokerSocketAuthority
::method init
  nop


::class TerminalBrokerSocketNonceSource public
::method nextNonceHex
  use strict arg
  randomStream = .stream~new("/dev/urandom")
  signal on notready name randomFailure
  bytes = randomStream~charIn(, 32)
  signal off notready
  ignore = randomStream~close
  if bytes~length \= 32 then raise syntax 88.900 array("Terminal broker socket nonce source returned the wrong byte count")
  return c2x(bytes)~lower
randomFailure:
  signal off notready
  ignore = randomStream~close
  raise syntax 88.900 array("Terminal broker socket nonce source is unavailable")


::class TerminalBrokerSocketFramer public
::attribute maxRecordBytes get

::method init
  expose maxRecordBytes
  use strict arg maxRecordBytesArg = 262144
  if \datatype(maxRecordBytesArg, "W") then raise syntax 88.900 array("Terminal broker socket record limit must be a positive whole number")
  if maxRecordBytesArg < 256 then raise syntax 88.900 array("Terminal broker socket record limit must be at least 256")
  if maxRecordBytesArg > 67108864 then raise syntax 88.900 array("Terminal broker socket record limit must not exceed 67108864")
  maxRecordBytes = maxRecordBytesArg

::method sendRecord public unguarded
  expose maxRecordBytes
  use strict arg connection, payloadArg
  payload = payloadArg~string
  if payload~length > maxRecordBytes then return .TerminalResult~failure("BROKER_SOCKET_RECORD_TOO_LARGE", payload~length)
  if payload~length > 4294967295 then return .TerminalResult~failure("BROKER_SOCKET_RECORD_TOO_LARGE", payload~length)
  header = right(d2x(payload~length), 8, "0")~upper
  written = self~writeAll(connection, header || payload)
  if \written~ok then return written
  return .TerminalResult~success(payload~length)

::method receiveRecord public unguarded
  expose maxRecordBytes
  use strict arg connection
  headerResult = self~readExact(connection, 8)
  if \headerResult~ok then return headerResult
  header = headerResult~value
  if verify(header~upper, "0123456789ABCDEF") \= 0 then return .TerminalResult~failure("BROKER_SOCKET_HEADER_INVALID", "record header must contain eight hexadecimal digits")
  signal on syntax name invalidHeader
  payloadLength = x2d(header)
  signal off syntax
  if payloadLength > maxRecordBytes then return .TerminalResult~failure("BROKER_SOCKET_RECORD_TOO_LARGE", payloadLength)
  if payloadLength = 0 then return .TerminalResult~success("")
  return self~readExact(connection, payloadLength)
invalidHeader:
  signal off syntax
  return .TerminalResult~failure("BROKER_SOCKET_HEADER_INVALID", "record length could not be decoded")

::method writeAll private unguarded
  use strict arg connection, bytesArg
  bytes = bytesArg~string
  offset = 1
  do while offset <= bytes~length
    signal on notready name writeFailure
    written = connection~charOut(bytes~substr(offset))
    signal off notready
    if \datatype(written, "W") then return .TerminalResult~failure("BROKER_SOCKET_WRITE_FAILED", connection~description)
    if written <= 0 then return .TerminalResult~failure("BROKER_SOCKET_WRITE_FAILED", connection~description)
    offset += written
  end
  return .TerminalResult~success(bytes~length)
writeFailure:
  signal off notready
  return .TerminalResult~failure("BROKER_SOCKET_WRITE_FAILED", connection~description)

::method readExact private unguarded
  use strict arg connection, byteCount
  if byteCount = 0 then return .TerminalResult~success("")
  signal on notready name readFailure
  bytes = connection~charIn(, byteCount)
  signal off notready
  if bytes~length \= byteCount then return .TerminalResult~failure("BROKER_SOCKET_EOF", "wanted=" || byteCount || ";got=" || bytes~length)
  return .TerminalResult~success(bytes)
readFailure:
  signal off notready
  return .TerminalResult~failure("BROKER_SOCKET_READ_FAILED", connection~description)


::class TerminalBrokerSocketProtocol public

::method helloText class
  use strict arg principal, keyId, clientNonce
  return .TerminalBrokerSocketBuild~PROTOCOL || "0"x || "HELLO" || "0"x || principal || "0"x || keyId || "0"x || clientNonce

::method challengeText class
  use strict arg principal, keyId, clientNonce, serverNonce
  return .TerminalBrokerSocketBuild~PROTOCOL || "0"x || "CHALLENGE" || "0"x || principal || "0"x || keyId || "0"x || clientNonce || "0"x || serverNonce

::method requestText class
  use strict arg principal, keyId, clientNonce, serverNonce, sequence, brokerFrame
  return .TerminalBrokerSocketBuild~PROTOCOL || "0"x || "REQUEST" || "0"x || principal || "0"x || keyId || "0"x || clientNonce || "0"x || serverNonce || "0"x || sequence || "0"x || brokerFrame

::method responseText class
  use strict arg principal, keyId, clientNonce, serverNonce, sequence, brokerFrame
  return .TerminalBrokerSocketBuild~PROTOCOL || "0"x || "RESPONSE" || "0"x || principal || "0"x || keyId || "0"x || clientNonce || "0"x || serverNonce || "0"x || sequence || "0"x || brokerFrame

::method byeText class
  use strict arg principal, keyId, clientNonce, serverNonce, sequence
  return .TerminalBrokerSocketBuild~PROTOCOL || "0"x || "BYE" || "0"x || principal || "0"x || keyId || "0"x || clientNonce || "0"x || serverNonce || "0"x || sequence

::method byeAckText class
  use strict arg principal, keyId, clientNonce, serverNonce, sequence
  return .TerminalBrokerSocketBuild~PROTOCOL || "0"x || "BYE_ACK" || "0"x || principal || "0"x || keyId || "0"x || clientNonce || "0"x || serverNonce || "0"x || sequence


/* Holds one configured authentication secret.  It is deliberately not an
 * AlchemyObject and has no key getter.  Only the exact listener authority
 * object can use the retained key. */
::class TerminalBrokerSocketPeer
::attribute principal get
::attribute keyId get

::method init
  expose principal keyId keyHex transportAuthority
  use strict arg principalArg, keyIdArg, keyHexArg, authorityArg
  principal = principalArg~string~strip
  keyId = keyIdArg~string~strip
  keyHex = keyHexArg~string~strip~lower
  if principal == "" then raise syntax 88.900 array("Terminal broker socket principal must not be empty")
  if principal~length > 256 then raise syntax 88.900 array("Terminal broker socket principal is too long")
  if principal~pos("0"x) > 0 then raise syntax 88.900 array("Terminal broker socket principal contains a prohibited NUL")
  if keyId == "" then raise syntax 88.900 array("Terminal broker socket key id must not be empty")
  if keyId~length > 128 then raise syntax 88.900 array("Terminal broker socket key id is too long")
  if keyId~pos("0"x) > 0 then raise syntax 88.900 array("Terminal broker socket key id contains a prohibited NUL")
  if keyHex~length < 64 then raise syntax 88.900 array("Terminal broker socket HMAC key must contain at least 32 bytes")
  if keyHex~length > 512 then raise syntax 88.900 array("Terminal broker socket HMAC key is too long")
  if keyHex~length // 2 \= 0 then raise syntax 88.900 array("Terminal broker socket HMAC key hex length must be even")
  if verify(keyHex, "0123456789abcdef") \= 0 then raise syntax 88.900 array("Terminal broker socket HMAC key must be hexadecimal")
  transportAuthority = authorityArg

::method macInternal
  expose keyHex transportAuthority
  use strict arg textArg, authorityArg
  if authorityArg \== transportAuthority then raise syntax 88.900 array("Terminal broker socket peer authority mismatch")
  return .HMACSHA512~digest(keyHex, textArg~string)

::method verifyInternal
  expose keyHex transportAuthority
  use strict arg textArg, suppliedMacArg, authorityArg
  if authorityArg \== transportAuthority then return .false
  supplied = suppliedMacArg~string~strip~lower
  if supplied~length \= 128 then return .false
  if verify(supplied, "0123456789abcdef") \= 0 then return .false
  expected = .HMACSHA512~digest(keyHex, textArg~string)
  return .CryptoUtils~secureEquals(expected, supplied)


::class TerminalBrokerSocketServiceStatus public
::attribute state get
::attribute port get
::attribute generation get
::attribute workerLimit get
::attribute acceptorActive get
::attribute activeConnections get
::attribute peakConnections get
::attribute completedConnections get
::attribute totalConnections get
::attribute authenticatedConnections get
::attribute rejectedConnections get
::attribute requestCount get
::attribute drainReason get
::attribute lastError get

::method init
  expose state port generation workerLimit acceptorActive activeConnections peakConnections completedConnections totalConnections authenticatedConnections rejectedConnections requestCount drainReason lastError
  use strict arg stateArg, portArg, generationArg, workerLimitArg, acceptorActiveArg, activeArg, peakArg, completedArg, totalArg, authenticatedArg, rejectedArg, requestArg, drainReasonArg, lastErrorArg
  state = stateArg~string
  port = portArg
  generation = generationArg
  workerLimit = workerLimitArg
  acceptorActive = acceptorActiveArg
  activeConnections = activeArg
  peakConnections = peakArg
  completedConnections = completedArg
  totalConnections = totalArg
  authenticatedConnections = authenticatedArg
  rejectedConnections = rejectedArg
  requestCount = requestArg
  drainReason = drainReasonArg~string
  lastError = lastErrorArg~string


/* One acceptor owns the blocking accept() call.  It is deliberately not an
 * Alchemy object and exposes no socket/endpoint authority.  Its only job is to
 * execute the host's exact-authority service loop on an ooRexx activity. */
::class TerminalBrokerSocketAcceptor
::method init
  expose host authority generation
  use strict arg hostArg, authorityArg, generationArg
  host = hostArg
  authority = authorityArg
  generation = generationArg

::method run unguarded
  expose host authority generation
  ignore = host~serviceAcceptLoop(authority, generation)


/* A connection worker owns exactly one accepted socket.  Workers never retain
 * TerminalSessionOwner, broker client/controller objects, HMAC peer tables or
 * endpoint maps; those stay inside TerminalBrokerLocalSocketHost / endpoint. */
::class TerminalBrokerSocketConnectionWorker
::method init
  expose host acceptedSocket authority generation workerId
  use strict arg hostArg, acceptedSocketArg, authorityArg, generationArg, workerIdArg
  host = hostArg
  acceptedSocket = acceptedSocketArg
  authority = authorityArg
  generation = generationArg
  workerId = workerIdArg

::method run unguarded
  expose host acceptedSocket authority generation workerId
  ignore = host~serviceConnection(acceptedSocket, authority, generation, workerId)
  acceptedSocket = .nil


::class TerminalBrokerLocalSocketHost subclass TerminalAlchemyObject public
::attribute bindHost get
::attribute port get
::attribute state get
::attribute connectionCount get
::attribute authenticatedCount get
::attribute rejectedCount get
::attribute requestCount get
::attribute maxRequestsPerConnection get
::attribute socketTimeoutMilliseconds get
::attribute lastError get
::attribute activeConnectionCount get
::attribute peakConnectionCount get
::attribute completedConnectionCount get
::attribute serviceState get
::attribute serviceWorkerLimit get
::attribute serviceGeneration get
::attribute serviceAcceptorActive get
::attribute serviceDrainReason get

::method init
  expose endpoint bindHost port state peers nonceSource framer listenSocket authority connectionCount authenticatedCount rejectedCount requestCount maxRequestsPerConnection socketTimeoutMilliseconds lastError activeConnectionCount peakConnectionCount completedConnectionCount serviceState serviceWorkerLimit serviceGeneration serviceAcceptorActive serviceDrainReason serviceAuthority serviceWorkerSequence alchemySealer alchemyCapabilityAuthority
  use strict arg endpointArg, portArg = 0, maxRequestsArg = 256, recordLimitArg = 262144, nonceSourceArg = .nil, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil, socketTimeoutArg = 30000

  if endpointArg == .nil then raise syntax 88.900 array("TerminalBrokerLocalSocketHost requires a serialized protocol endpoint")
  if \endpointArg~hasMethod("HANDLEFRAME") then raise syntax 88.900 array("TerminalBrokerLocalSocketHost endpoint must implement handleFrame(principal, frame)")
  if \datatype(portArg, "W") then raise syntax 88.900 array("TerminalBrokerLocalSocketHost port must be a whole number")
  if portArg < 0 | portArg > 65535 then raise syntax 88.900 array("TerminalBrokerLocalSocketHost port is outside 0..65535")
  if \datatype(maxRequestsArg, "W") then raise syntax 88.900 array("TerminalBrokerLocalSocketHost request limit must be a positive whole number")
  if maxRequestsArg < 1 | maxRequestsArg > 65535 then raise syntax 88.900 array("TerminalBrokerLocalSocketHost request limit must be within 1..65535")
  if \datatype(socketTimeoutArg, "W") then raise syntax 88.900 array("TerminalBrokerLocalSocketHost socket timeout must be a positive whole number of milliseconds")
  if socketTimeoutArg < 100 | socketTimeoutArg > 3600000 then raise syntax 88.900 array("TerminalBrokerLocalSocketHost socket timeout must be within 100..3600000 milliseconds")

  endpoint = endpointArg
  bindHost = .TerminalBrokerSocketBuild~BIND_HOST
  port = portArg
  maxRequestsPerConnection = maxRequestsArg
  socketTimeoutMilliseconds = socketTimeoutArg
  if nonceSourceArg == .nil then nonceSource = .TerminalBrokerSocketNonceSource~new
  else nonceSource = nonceSourceArg
  if \nonceSource~hasMethod("NEXTNONCEHEX") then raise syntax 88.900 array("TerminalBrokerLocalSocketHost nonce source must implement nextNonceHex()")
  framer = .TerminalBrokerSocketFramer~new(recordLimitArg)
  peers = .table~new
  listenSocket = .nil
  authority = .TerminalBrokerSocketAuthority~new
  serviceAuthority = .TerminalBrokerSocketAuthority~new
  state = "STOPPED"
  connectionCount = 0
  authenticatedCount = 0
  rejectedCount = 0
  requestCount = 0
  activeConnectionCount = 0
  peakConnectionCount = 0
  completedConnectionCount = 0
  serviceState = "STOPPED"
  serviceWorkerLimit = 0
  serviceGeneration = 0
  serviceAcceptorActive = .false
  serviceDrainReason = ""
  serviceWorkerSequence = 0
  lastError = ""
  alchemySealer = alchemySealerArg
  alchemyCapabilityAuthority = alchemyCapabilityAuthorityArg

  meta = .directory~new
  meta["transport"] = .TerminalBrokerSocketBuild~PROTOCOL
  meta["bind_scope"] = "IPV4_LOOPBACK_ONLY"
  meta["confidentiality"] = "NONE_LOCAL_AUTHENTICATED_INTEGRITY"
  limitations = .array~of("ooRexx r13196 RxSock supports AF_INET only, so v0.17 binds 127.0.0.1 rather than pretending to provide AF_UNIX", "persistent service uses one acceptor plus a bounded set of concurrent connection workers", "accepted connections have a bounded inactivity I/O timeout", "transport authenticates/integrity-protects but does not encrypt broker JSON")
  meta["design_limitations"] = limitations
  self~initTerminalAlchemy("Authenticated loopback IPC host around TerminalBrokerProtocolEndpoint", meta, alchemySealer, alchemyCapabilityAuthority)
  self~registerStateVariable("bindHost", "CUSTOMER", "fixed loopback listener address")
  self~registerStateVariable("port", "CUSTOMER", "actual loopback listener port")
  self~registerStateVariable("state", "CUSTOMER", "socket listener lifecycle state")
  self~registerStateVariable("connectionCount", "CUSTOMER", "accepted local socket connections")
  self~registerStateVariable("authenticatedCount", "CUSTOMER", "mutually authenticated local socket sessions")
  self~registerStateVariable("rejectedCount", "CUSTOMER", "rejected socket sessions")
  self~registerStateVariable("requestCount", "CUSTOMER", "authenticated broker requests dispatched")
  self~registerStateVariable("activeConnectionCount", "CUSTOMER", "currently serviced local socket connections")
  self~registerStateVariable("peakConnectionCount", "CUSTOMER", "peak concurrent serviced local socket connections")
  self~registerStateVariable("completedConnectionCount", "CUSTOMER", "completed serviced local socket connections")
  self~registerStateVariable("serviceState", "CUSTOMER", "persistent service lifecycle state")
  self~registerStateVariable("serviceWorkerLimit", "CUSTOMER", "maximum concurrent authenticated connection workers")
  self~registerStateVariable("serviceGeneration", "CUSTOMER", "monotonic persistent service launch generation")
  self~registerStateVariable("serviceAcceptorActive", "INTERNAL", "whether the persistent acceptor activity is live")
  self~registerStateVariable("serviceDrainReason", "INTERNAL", "latest graceful service drain reason")
  self~registerStateVariable("maxRequestsPerConnection", "CUSTOMER", "per-connection authenticated request bound")
  self~registerStateVariable("socketTimeoutMilliseconds", "CUSTOMER", "bounded per-connection socket I/O timeout in milliseconds")
  self~registerStateVariable("lastError", "INTERNAL", "latest bounded socket host error")
  /* endpoint/peers/keys/nonces/socket/framer/authorities/worker objects are deliberately unregistered. */
  self~registerMethodContract("TRUSTPRINCIPAL", "configure one principal/key-id HMAC trust binding while service is stopped", .array~of("PRINCIPAL", "KEY_ID", "KEY_HEX"), "TERMINALRESULT", .true, "FALSE", "INTERNAL", "SECURITY_BOUNDARY", "MUTATE", "USE")
  self~registerMethodContract("START", "bind an authenticated listener to IPv4 loopback only", .array~of("BACKLOG"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("STOP", "close only the local IPC listener; terminal ownership is untouched", .array~new, "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("SERVEONE", "accept and service one bounded authenticated local connection synchronously", .array~new, "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("LAUNCHSERVICE", "launch one acceptor and bounded concurrent connection workers", .array~of("MAX_CONNECTIONS", "BACKLOG"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("REQUESTDRAIN", "stop accepting new clients while existing bounded connections finish", .array~of("REASON"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("AWAITDRAIN", "wait a bounded time for acceptor and active connection workers to finish", .array~of("TIMEOUT_MS"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("SERVICESTATUS", "return detached scalar persistent-service evidence", .array~new, "TERMINALBROKERSOCKETSERVICESTATUS", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "USE")

::method trustPrincipal public protected
  expose peers authority serviceState
  use strict arg principalArg, keyIdArg, keyHexArg
  if serviceState == "RUNNING" | serviceState == "DRAINING" then return .TerminalResult~failure("BROKER_SOCKET_SERVICE_ACTIVE", "trust bindings are immutable while persistent service is active")
  signal on syntax name invalidPeer
  peer = .TerminalBrokerSocketPeer~new(principalArg, keyIdArg, keyHexArg, authority)
  signal off syntax
  key = self~peerKey(peer~principal, peer~keyId)
  if peers~at(key) \== .nil then return .TerminalResult~failure("BROKER_SOCKET_PEER_EXISTS", "principal/key id already configured")
  peers~put(peer, key)
  self~alchemyTouch("SOCKET_TRUST_PRINCIPAL")
  ignore = self~terminalAuthorityEvent("SOCKET_TRUST_PRINCIPAL", peer~principal, peer~keyId)
  return .TerminalResult~success(.true)
invalidPeer:
  signal off syntax
  return .TerminalResult~failure("BROKER_SOCKET_PEER_INVALID", condition("D"))

::method start public
  expose bindHost port state listenSocket lastError
  use strict arg backlogArg = 16
  if state == "LISTENING" then do
    if listenSocket \== .nil then return .TerminalResult~success(port)
  end
  if \datatype(backlogArg, "W") then return .TerminalResult~failure("BROKER_SOCKET_BACKLOG_INVALID", "backlog must be a positive whole number")
  if backlogArg < 1 | backlogArg > 1024 then return .TerminalResult~failure("BROKER_SOCKET_BACKLOG_INVALID", "backlog must be within 1..1024")

  socketObject = .Socket~new("AF_INET", "SOCK_STREAM", 0)
  if socketObject~errno \= 0 then do
    lastError = "SOCKET_CREATE_FAILED:" || socketObject~errno
    state = "ERROR"
    return .TerminalResult~failure("BROKER_SOCKET_CREATE_FAILED", socketObject~errno)
  end
  ignore = socketObject~setOption("SO_REUSEADDR", 1)
  address = .InetAddress~new(bindHost, port)
  if socketObject~bind(address) = -1 then do
    err = socketObject~errno
    ignore = socketObject~close
    lastError = "BIND_FAILED:" || err
    state = "ERROR"
    return .TerminalResult~failure("BROKER_SOCKET_BIND_FAILED", err)
  end
  if socketObject~listen(backlogArg) = -1 then do
    err = socketObject~errno
    ignore = socketObject~close
    lastError = "LISTEN_FAILED:" || err
    state = "ERROR"
    return .TerminalResult~failure("BROKER_SOCKET_LISTEN_FAILED", err)
  end
  actual = socketObject~getSockName
  if actual \== .nil then port = actual~port
  listenSocket = socketObject
  lastError = ""
  state = "LISTENING"
  self~alchemyTouch("SOCKET_START")
  ignore = self~terminalLifecycleEvent("IPC_LISTENING", bindHost || ":" || port)
  return .TerminalResult~success(port)

::method stop public
  expose state listenSocket lastError
  use strict arg
  if listenSocket \== .nil then ignore = listenSocket~close
  listenSocket = .nil
  state = "STOPPED"
  lastError = ""
  self~alchemyTouch("SOCKET_STOP")
  ignore = self~terminalLifecycleEvent("IPC_STOPPED")
  return .TerminalResult~success(.true)

::method serveOne public unguarded
  expose listenSocket state lastError serviceState
  use strict arg
  if serviceState == "RUNNING" | serviceState == "DRAINING" then return .TerminalResult~failure("BROKER_SOCKET_SERVICE_ACTIVE", "persistent acceptor owns the listener")
  if state \== "LISTENING" then do
    started = self~start
    if \started~ok then return started
  end
  socketObject = listenSocket
  if socketObject == .nil then return .TerminalResult~failure("BROKER_SOCKET_NOT_LISTENING")
  acceptedSocket = socketObject~accept
  if acceptedSocket == .nil then do
    self~noteRejected("BROKER_SOCKET_ACCEPT_FAILED")
    return .TerminalResult~failure("BROKER_SOCKET_ACCEPT_FAILED")
  end
  prepared = self~prepareAcceptedSocket(acceptedSocket)
  if \prepared~ok then do
    ignore = acceptedSocket~close
    self~noteRejected(prepared~code || ":" || prepared~detail)
    return prepared
  end
  self~noteConnectionStarted
  connection = .StreamSocket~new(acceptedSocket)
  handled = self~handleConnection(connection)
  ignore = connection~close
  self~noteConnectionFinished(handled)
  self~alchemyTouch("SOCKET_SERVE_ONE")
  return handled

::method launchService public
  expose serviceState serviceWorkerLimit serviceGeneration serviceAcceptorActive serviceDrainReason serviceAuthority port
  use strict arg maxConnectionsArg = 16, backlogArg = 64
  if serviceState == "RUNNING" then return .TerminalResult~success(port)
  if serviceState == "DRAINING" then return .TerminalResult~failure("BROKER_SOCKET_SERVICE_DRAINING", serviceDrainReason)
  if \datatype(maxConnectionsArg, "W") then return .TerminalResult~failure("BROKER_SOCKET_WORKER_LIMIT_INVALID", "max connections must be a positive whole number")
  if maxConnectionsArg < 1 | maxConnectionsArg > 1024 then return .TerminalResult~failure("BROKER_SOCKET_WORKER_LIMIT_INVALID", "max connections must be within 1..1024")
  started = self~start(backlogArg)
  if \started~ok then return started
  serviceWorkerLimit = maxConnectionsArg
  serviceGeneration += 1
  serviceAcceptorActive = .true
  serviceDrainReason = ""
  serviceState = "RUNNING"
  acceptor = .TerminalBrokerSocketAcceptor~new(self, serviceAuthority, serviceGeneration)
  acceptor~start("RUN")
  self~alchemyTouch("SOCKET_SERVICE_LAUNCH")
  ignore = self~terminalLifecycleEvent("IPC_SERVICE_RUNNING", "generation=" || serviceGeneration || ";workers=" || serviceWorkerLimit)
  return .TerminalResult~success(port)

::method requestDrain public
  expose serviceState serviceDrainReason serviceAcceptorActive activeConnectionCount
  use strict arg reasonArg = "DRAIN_REQUESTED"
  if serviceState == "DRAINED" | serviceState == "STOPPED" then return .TerminalResult~success(self~serviceStatus)
  if serviceState \== "RUNNING" & serviceState \== "DRAINING" then return .TerminalResult~failure("BROKER_SOCKET_SERVICE_NOT_RUNNING", serviceState)
  serviceDrainReason = reasonArg~string
  serviceState = "DRAINING"
  self~alchemyTouch("SOCKET_SERVICE_DRAIN_REQUEST")
  ignore = self~terminalLifecycleEvent("IPC_SERVICE_DRAINING", serviceDrainReason)
  if serviceAcceptorActive then do
    woke = self~wakeAcceptor
    if \woke~ok then return woke
  end
  if \serviceAcceptorActive & activeConnectionCount = 0 then serviceState = "DRAINED"
  return .TerminalResult~success(self~serviceStatus)

::method awaitDrain public unguarded
  use strict arg timeoutMillisecondsArg = 30000
  if \datatype(timeoutMillisecondsArg, "W") then return .TerminalResult~failure("BROKER_SOCKET_DRAIN_TIMEOUT_INVALID", "timeout must be a non-negative whole number")
  if timeoutMillisecondsArg < 0 | timeoutMillisecondsArg > 3600000 then return .TerminalResult~failure("BROKER_SOCKET_DRAIN_TIMEOUT_INVALID", "timeout must be within 0..3600000 milliseconds")
  waited = 0
  do forever
    status = self~serviceStatus
    if status~state == "DRAINED" | status~state == "STOPPED" then return .TerminalResult~success(status)
    if status~state == "ERROR" then return .TerminalResult~failure("BROKER_SOCKET_SERVICE_ERROR", status~lastError)
    if waited >= timeoutMillisecondsArg then return .TerminalResult~failure("BROKER_SOCKET_DRAIN_TIMEOUT", "active=" || status~activeConnections || ";acceptor=" || status~acceptorActive)
    sleepMilliseconds = 10
    if timeoutMillisecondsArg - waited < sleepMilliseconds then sleepMilliseconds = timeoutMillisecondsArg - waited
    if sleepMilliseconds <= 0 then iterate
    call SysSleep sleepMilliseconds / 1000
    waited += sleepMilliseconds
  end

::method serviceStatus public
  expose serviceState port serviceGeneration serviceWorkerLimit serviceAcceptorActive activeConnectionCount peakConnectionCount completedConnectionCount connectionCount authenticatedCount rejectedCount requestCount serviceDrainReason lastError
  use strict arg
  return .TerminalBrokerSocketServiceStatus~new(serviceState, port, serviceGeneration, serviceWorkerLimit, serviceAcceptorActive, activeConnectionCount, peakConnectionCount, completedConnectionCount, connectionCount, authenticatedCount, rejectedCount, requestCount, serviceDrainReason, lastError)

/* Executed only by the private acceptor object holding the exact service
 * authority. One blocking accept activity feeds bounded concurrent workers. */
::method serviceAcceptLoop public protected unguarded
  expose serviceAuthority serviceGeneration serviceState serviceWorkerLimit serviceAcceptorActive listenSocket serviceWorkerSequence
  use strict arg authorityArg, generationArg
  if authorityArg \== serviceAuthority then return .TerminalResult~failure("BROKER_SOCKET_SERVICE_AUTHORITY_INVALID")
  if generationArg \= serviceGeneration then return .TerminalResult~failure("BROKER_SOCKET_SERVICE_GENERATION_INVALID")
  signal on syntax name acceptorSyntaxFailure

  do while serviceState == "RUNNING"
    if generationArg \= serviceGeneration then leave
    socketObject = listenSocket
    if socketObject == .nil then leave
    acceptedSocket = socketObject~accept

    /* requestDrain changes state before its loopback wake connection. */
    if serviceState \== "RUNNING" then do
      if acceptedSocket \== .nil then ignore = acceptedSocket~close
      leave
    end
    if acceptedSocket == .nil then do
      self~noteRejected("BROKER_SOCKET_ACCEPT_FAILED")
      leave
    end

    if self~activeConnectionCount >= serviceWorkerLimit then do
      ignore = acceptedSocket~close
      self~noteRejected("BROKER_SOCKET_CONNECTION_LIMIT")
      iterate
    end

    prepared = self~prepareAcceptedSocket(acceptedSocket)
    if \prepared~ok then do
      ignore = acceptedSocket~close
      self~noteRejected(prepared~code || ":" || prepared~detail)
      iterate
    end

    serviceWorkerSequence += 1
    workerId = serviceGeneration || "-" || right(serviceWorkerSequence, 8, "0")
    self~noteConnectionStarted
    worker = .TerminalBrokerSocketConnectionWorker~new(self, acceptedSocket, serviceAuthority, serviceGeneration, workerId)
    worker~start("RUN")
  end

  signal off syntax
  self~serviceAcceptorStopped(authorityArg, generationArg)
  return .TerminalResult~success(.true)

acceptorSyntaxFailure:
  signal off syntax
  detail = condition("D")
  self~serviceAcceptorFailed(authorityArg, generationArg, detail)
  return .TerminalResult~failure("BROKER_SOCKET_ACCEPTOR_FAILED", detail)

::method serviceConnection public protected unguarded
  expose serviceAuthority serviceGeneration
  use strict arg acceptedSocket, authorityArg, generationArg, workerIdArg
  if authorityArg \== serviceAuthority then do
    if acceptedSocket \== .nil then ignore = acceptedSocket~close
    return .TerminalResult~failure("BROKER_SOCKET_SERVICE_AUTHORITY_INVALID")
  end
  if generationArg \= serviceGeneration then do
    if acceptedSocket \== .nil then ignore = acceptedSocket~close
    return .TerminalResult~failure("BROKER_SOCKET_SERVICE_GENERATION_INVALID")
  end
  connection = .nil
  signal on syntax name workerSyntaxFailure
  connection = .StreamSocket~new(acceptedSocket)
  handled = self~handleConnection(connection)
  signal off syntax
  ignore = connection~close
  self~noteConnectionFinished(handled)
  return handled

workerSyntaxFailure:
  signal off syntax
  detail = condition("D")
  if connection \== .nil then ignore = connection~close
  else if acceptedSocket \== .nil then ignore = acceptedSocket~close
  handled = .TerminalResult~failure("BROKER_SOCKET_WORKER_FAILED", "worker=" || workerIdArg || ";" || detail)
  self~noteConnectionFinished(handled)
  return handled

::method prepareAcceptedSocket private
  expose bindHost socketTimeoutMilliseconds
  use strict arg acceptedSocket
  peerAddress = acceptedSocket~getPeerName
  if peerAddress == .nil then return .TerminalResult~failure("BROKER_SOCKET_PEER_ADDRESS_FAILED", "accepted peer address unavailable")
  if peerAddress~address \== bindHost then return .TerminalResult~failure("BROKER_SOCKET_NONLOCAL_PEER", peerAddress~address)
  receiveOption = acceptedSocket~setOption("SO_RCVTIMEO", socketTimeoutMilliseconds)
  if receiveOption == .nil then return .TerminalResult~failure("BROKER_SOCKET_TIMEOUT_CONFIG_FAILED", "SO_RCVTIMEO")
  sendOption = acceptedSocket~setOption("SO_SNDTIMEO", socketTimeoutMilliseconds)
  if sendOption == .nil then return .TerminalResult~failure("BROKER_SOCKET_TIMEOUT_CONFIG_FAILED", "SO_SNDTIMEO")
  return .TerminalResult~success(peerAddress~address)

::method handleConnection private unguarded
  expose endpoint peers nonceSource framer authority maxRequestsPerConnection
  use strict arg connection

  helloResult = framer~receiveRecord(connection)
  if \helloResult~ok then return self~reject(helloResult~code, helloResult~detail)
  helloParsed = self~parseRecord(helloResult~value)
  if \helloParsed~ok then return helloParsed
  hello = helloParsed~value
  if self~recordString(hello, "type") \== "AUTH_HELLO" then return self~reject("BROKER_SOCKET_HELLO_INVALID", "AUTH_HELLO required")
  if self~recordString(hello, "protocol") \== .TerminalBrokerSocketBuild~PROTOCOL then return self~reject("BROKER_SOCKET_PROTOCOL_MISMATCH", "unsupported socket protocol")
  principal = self~recordString(hello, "principal")~strip
  keyId = self~recordString(hello, "key_id")~strip
  clientNonce = self~recordString(hello, "client_nonce")~strip~lower
  suppliedMac = self~recordString(hello, "mac")~strip~lower
  if \self~validNonce(clientNonce) then return self~reject("BROKER_SOCKET_NONCE_INVALID", "client nonce must be 32-byte hexadecimal")
  peer = peers~at(self~peerKey(principal, keyId))
  if peer == .nil then return self~reject("BROKER_SOCKET_PEER_NOT_TRUSTED", "principal/key id is not trusted")
  helloText = .TerminalBrokerSocketProtocol~helloText(principal, keyId, clientNonce)
  if \peer~verifyInternal(helloText, suppliedMac, authority) then return self~reject("BROKER_SOCKET_AUTHENTICATION_FAILED", "client authentication failed")
  self~noteAuthenticated

  signal on syntax name nonceFailure
  serverNonce = nonceSource~nextNonceHex~string~strip~lower
  signal off syntax
  if \self~validNonce(serverNonce) then return self~reject("BROKER_SOCKET_NONCE_SOURCE_INVALID", "server nonce source returned invalid data")
  challengeText = .TerminalBrokerSocketProtocol~challengeText(principal, keyId, clientNonce, serverNonce)
  challenge = .directory~new
  challenge["type"] = "AUTH_CHALLENGE"
  challenge["protocol"] = .TerminalBrokerSocketBuild~PROTOCOL
  challenge["server_nonce"] = serverNonce
  challenge["mac"] = peer~macInternal(challengeText, authority)
  sentChallenge = framer~sendRecord(connection, .json~toJson(challenge))
  if \sentChallenge~ok then return self~reject(sentChallenge~code, sentChallenge~detail)

  expectedSequence = 1
  handledRequests = 0
  do forever
    recordResult = framer~receiveRecord(connection)
    if \recordResult~ok then return self~reject(recordResult~code, recordResult~detail)
    parsed = self~parseRecord(recordResult~value)
    if \parsed~ok then return parsed
    record = parsed~value
    if self~recordString(record, "protocol") \== .TerminalBrokerSocketBuild~PROTOCOL then return self~reject("BROKER_SOCKET_PROTOCOL_MISMATCH", "unsupported socket protocol")
    recordType = self~recordString(record, "type")~upper
    sequenceResult = self~recordWhole(record, "sequence")
    if \sequenceResult~ok then return sequenceResult
    sequence = sequenceResult~value
    if sequence \= expectedSequence then return self~reject("BROKER_SOCKET_SEQUENCE_INVALID", "expected=" || expectedSequence || ";actual=" || sequence)

    if recordType == "BYE" then do
      byeMac = self~recordString(record, "mac")~strip~lower
      byeText = .TerminalBrokerSocketProtocol~byeText(principal, keyId, clientNonce, serverNonce, sequence)
      if \peer~verifyInternal(byeText, byeMac, authority) then return self~reject("BROKER_SOCKET_AUTHENTICATION_FAILED", "BYE authentication failed")
      ack = .directory~new
      ack["type"] = "BYE_ACK"
      ack["protocol"] = .TerminalBrokerSocketBuild~PROTOCOL
      ack["sequence"] = sequence
      ack["mac"] = peer~macInternal(.TerminalBrokerSocketProtocol~byeAckText(principal, keyId, clientNonce, serverNonce, sequence), authority)
      sentAck = framer~sendRecord(connection, .json~toJson(ack))
      if \sentAck~ok then return self~reject(sentAck~code, sentAck~detail)
      return .TerminalResult~success(handledRequests)
    end

    if recordType \== "BROKER_REQUEST" then return self~reject("BROKER_SOCKET_RECORD_INVALID", "BROKER_REQUEST or BYE required")
    if handledRequests >= maxRequestsPerConnection then return self~reject("BROKER_SOCKET_REQUEST_LIMIT", "authenticated request limit reached")
    brokerFrame = self~recordString(record, "frame")
    if brokerFrame == "" then return self~reject("BROKER_SOCKET_BROKER_FRAME_REQUIRED", "broker frame is required")
    requestMac = self~recordString(record, "mac")~strip~lower
    requestText = .TerminalBrokerSocketProtocol~requestText(principal, keyId, clientNonce, serverNonce, sequence, brokerFrame)
    if \peer~verifyInternal(requestText, requestMac, authority) then return self~reject("BROKER_SOCKET_AUTHENTICATION_FAILED", "broker request authentication failed")

    responseFrame = endpoint~handleFrame(principal, brokerFrame)
    if responseFrame == .nil then return self~reject("BROKER_SOCKET_ENDPOINT_FAILED", "endpoint returned NIL")
    responseFrame = responseFrame~string
    if responseFrame == "" then return self~reject("BROKER_SOCKET_ENDPOINT_FAILED", "endpoint returned an empty frame")
    response = .directory~new
    response["type"] = "BROKER_RESPONSE"
    response["protocol"] = .TerminalBrokerSocketBuild~PROTOCOL
    response["sequence"] = sequence
    response["frame"] = responseFrame
    response["mac"] = peer~macInternal(.TerminalBrokerSocketProtocol~responseText(principal, keyId, clientNonce, serverNonce, sequence, responseFrame), authority)
    sent = framer~sendRecord(connection, .json~toJson(response))
    if \sent~ok then return self~reject(sent~code, sent~detail)
    handledRequests += 1
    self~noteRequest
    expectedSequence += 1
  end

nonceFailure:
  signal off syntax
  return self~reject("BROKER_SOCKET_NONCE_SOURCE_FAILED", condition("D"))

::method parseRecord private
  use strict arg jsonTextArg
  signal on syntax name invalidJson
  record = .json~fromJson(jsonTextArg~string)
  signal off syntax
  if record == .nil then return self~reject("BROKER_SOCKET_JSON_INVALID", "socket record must be a JSON object")
  if \record~isA(.Directory) then return self~reject("BROKER_SOCKET_JSON_INVALID", "socket record must be a JSON object")
  return .TerminalResult~success(record)
invalidJson:
  signal off syntax
  return self~reject("BROKER_SOCKET_JSON_INVALID", "socket record JSON could not be parsed")

::method recordString private
  use strict arg record, key
  value = record~at(key)
  if value == .nil then return ""
  return value~string

::method recordWhole private
  use strict arg record, key
  value = record~at(key)
  if value == .nil then return self~reject("BROKER_SOCKET_SEQUENCE_REQUIRED", "sequence is required")
  if \datatype(value, "W") then return self~reject("BROKER_SOCKET_SEQUENCE_INVALID", "sequence must be a whole number")
  if value < 1 then return self~reject("BROKER_SOCKET_SEQUENCE_INVALID", "sequence must be positive")
  return .TerminalResult~success(value + 0)

::method validNonce private
  use strict arg nonceArg
  nonce = nonceArg~string~strip~lower
  if nonce~length \= 64 then return .false
  return verify(nonce, "0123456789abcdef") = 0

::method peerKey private
  use strict arg principalArg, keyIdArg
  return principalArg~string || "0"x || keyIdArg~string

::method wakeAcceptor private
  expose bindHost port state
  use strict arg
  if state \== "LISTENING" then return .TerminalResult~success(.false)
  if port < 1 then return .TerminalResult~failure("BROKER_SOCKET_WAKE_FAILED", "listener port unavailable")
  wake = .Socket~new("AF_INET", "SOCK_STREAM", 0)
  if wake~errno \= 0 then return .TerminalResult~failure("BROKER_SOCKET_WAKE_FAILED", wake~errno)
  connected = wake~connect(.InetAddress~new(bindHost, port))
  if connected = -1 then do
    err = wake~errno
    ignore = wake~close
    return .TerminalResult~failure("BROKER_SOCKET_WAKE_FAILED", err)
  end
  ignore = wake~close
  return .TerminalResult~success(.true)

::method noteConnectionStarted private
  expose connectionCount activeConnectionCount peakConnectionCount
  connectionCount += 1
  activeConnectionCount += 1
  if activeConnectionCount > peakConnectionCount then peakConnectionCount = activeConnectionCount
  return activeConnectionCount

::method noteConnectionFinished private
  expose activeConnectionCount completedConnectionCount rejectedCount lastError serviceState serviceAcceptorActive
  use strict arg handled
  activeConnectionCount -= 1
  if activeConnectionCount < 0 then activeConnectionCount = 0
  completedConnectionCount += 1
  if handled~ok then lastError = ""
  else do
    rejectedCount += 1
    lastError = handled~code || ":" || handled~detail
  end
  if serviceState == "DRAINING" then do
    if \serviceAcceptorActive & activeConnectionCount = 0 then serviceState = "DRAINED"
  end
  self~alchemyTouch("SOCKET_CONNECTION_COMPLETE")
  return activeConnectionCount

::method noteRejected private
  expose rejectedCount lastError
  use strict arg detailArg
  rejectedCount += 1
  lastError = detailArg~string
  return rejectedCount

::method noteAuthenticated private
  expose authenticatedCount
  authenticatedCount += 1
  return authenticatedCount

::method noteRequest private
  expose requestCount
  requestCount += 1
  return requestCount

::method serviceAcceptorStopped private
  expose serviceAuthority serviceGeneration serviceAcceptorActive serviceState activeConnectionCount listenSocket state
  use strict arg authorityArg, generationArg
  if authorityArg \== serviceAuthority then return .false
  if generationArg \= serviceGeneration then return .false
  serviceAcceptorActive = .false
  if listenSocket \== .nil then ignore = listenSocket~close
  listenSocket = .nil
  state = "STOPPED"
  if serviceState == "RUNNING" then serviceState = "ERROR"
  else if serviceState == "DRAINING" then do
    if activeConnectionCount = 0 then serviceState = "DRAINED"
  end
  self~alchemyTouch("SOCKET_SERVICE_ACCEPTOR_STOP")
  return .true

::method serviceAcceptorFailed private
  expose serviceAuthority serviceGeneration serviceAcceptorActive serviceState listenSocket state lastError
  use strict arg authorityArg, generationArg, detailArg
  if authorityArg \== serviceAuthority then return .false
  if generationArg \= serviceGeneration then return .false
  serviceAcceptorActive = .false
  if listenSocket \== .nil then ignore = listenSocket~close
  listenSocket = .nil
  state = "STOPPED"
  serviceState = "ERROR"
  lastError = "BROKER_SOCKET_ACCEPTOR_FAILED:" || detailArg~string
  self~alchemyTouch("SOCKET_SERVICE_ACCEPTOR_FAILED")
  ignore = self~terminalLifecycleEvent("IPC_SERVICE_ERROR", lastError)
  return .true

::method reject private
  use strict arg codeArg, detailArg = ""
  return .TerminalResult~failure(codeArg, detailArg)

::method uninit
  expose listenSocket state serviceState
  if listenSocket \== .nil then ignore = listenSocket~close
  listenSocket = .nil
  state = "STOPPED"
  if serviceState == "RUNNING" then serviceState = "DRAINING"


::class TerminalBrokerLocalSocketClient subclass TerminalAlchemyObject public
::attribute host get
::attribute port get
::attribute principal get
::attribute keyId get
::attribute state get
::attribute sequence get
::attribute requestCount get
::attribute socketTimeoutMilliseconds get
::attribute lastError get

::method init
  expose host port principal keyId keyHex nonceSource framer connection clientNonce serverNonce state sequence requestCount socketTimeoutMilliseconds lastError alchemySealer alchemyCapabilityAuthority
  use strict arg portArg, principalArg, keyIdArg, keyHexArg, recordLimitArg = 262144, nonceSourceArg = .nil, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil, socketTimeoutArg = 30000
  if \datatype(portArg, "W") then raise syntax 88.900 array("TerminalBrokerLocalSocketClient port must be a whole number")
  if portArg < 1 | portArg > 65535 then raise syntax 88.900 array("TerminalBrokerLocalSocketClient port is outside 1..65535")
  if \datatype(socketTimeoutArg, "W") then raise syntax 88.900 array("TerminalBrokerLocalSocketClient socket timeout must be a positive whole number of milliseconds")
  if socketTimeoutArg < 100 | socketTimeoutArg > 3600000 then raise syntax 88.900 array("TerminalBrokerLocalSocketClient socket timeout must be within 100..3600000 milliseconds")
  principal = principalArg~string~strip
  keyId = keyIdArg~string~strip
  keyHex = keyHexArg~string~strip~lower
  /* Reuse peer validation without retaining/exposing a peer capability. */
  validationAuthority = .TerminalBrokerSocketAuthority~new
  ignore = .TerminalBrokerSocketPeer~new(principal, keyId, keyHex, validationAuthority)
  host = .TerminalBrokerSocketBuild~BIND_HOST
  port = portArg
  if nonceSourceArg == .nil then nonceSource = .TerminalBrokerSocketNonceSource~new
  else nonceSource = nonceSourceArg
  if \nonceSource~hasMethod("NEXTNONCEHEX") then raise syntax 88.900 array("TerminalBrokerLocalSocketClient nonce source must implement nextNonceHex()")
  framer = .TerminalBrokerSocketFramer~new(recordLimitArg)
  connection = .nil
  clientNonce = ""
  serverNonce = ""
  state = "DISCONNECTED"
  sequence = 1
  requestCount = 0
  socketTimeoutMilliseconds = socketTimeoutArg
  lastError = ""
  alchemySealer = alchemySealerArg
  alchemyCapabilityAuthority = alchemyCapabilityAuthorityArg

  meta = .directory~new
  meta["transport"] = .TerminalBrokerSocketBuild~PROTOCOL
  meta["bind_scope"] = "IPV4_LOOPBACK_ONLY"
  self~initTerminalAlchemy("Authenticated local socket client for serialized terminal broker protocol", meta, alchemySealer, alchemyCapabilityAuthority)
  self~registerStateVariable("host", "CUSTOMER", "fixed loopback destination")
  self~registerStateVariable("port", "CUSTOMER", "local socket destination port")
  self~registerStateVariable("principal", "CUSTOMER", "configured authenticated transport principal")
  self~registerStateVariable("keyId", "INTERNAL", "non-secret authentication key identifier")
  self~registerStateVariable("state", "CUSTOMER", "authenticated local socket connection state")
  self~registerStateVariable("sequence", "INTERNAL", "next authenticated request sequence")
  self~registerStateVariable("requestCount", "CUSTOMER", "authenticated broker requests completed")
  self~registerStateVariable("socketTimeoutMilliseconds", "CUSTOMER", "bounded socket I/O timeout in milliseconds")
  self~registerStateVariable("lastError", "INTERNAL", "latest bounded client error")
  /* keyHex/nonces/connection/framer are deliberately unregistered. */
  self~registerMethodContract("CONNECT", "establish mutually authenticated loopback session", .array~new, "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("REQUESTFRAME", "send one authenticated serialized broker frame", .array~of("FRAME"), "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("REQUESTJSON", "frame and send one broker JSON request and return response JSON", .array~of("JSON"), "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("CLOSE", "authenticated socket BYE; does not close terminal/broker ownership", .array~new, "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "USE")

::method connect public
  expose host port principal keyId keyHex nonceSource framer connection clientNonce serverNonce state sequence socketTimeoutMilliseconds lastError
  use strict arg
  if state == "AUTHENTICATED" & connection \== .nil then return .TerminalResult~success(.true)
  if connection \== .nil then ignore = connection~close
  connection = .nil
  socketObject = .Socket~new("AF_INET", "SOCK_STREAM", 0)
  if socketObject~errno \= 0 then do
    state = "DISCONNECTED"
    lastError = "SOCKET_CREATE_FAILED:" || socketObject~errno
    return .TerminalResult~failure("BROKER_SOCKET_CONNECT_FAILED", lastError)
  end
  address = .InetAddress~new(host, port)
  if socketObject~connect(address) = -1 then do
    err = socketObject~errno
    ignore = socketObject~close
    state = "DISCONNECTED"
    lastError = "CONNECT_FAILED:" || err
    return .TerminalResult~failure("BROKER_SOCKET_CONNECT_FAILED", lastError)
  end
  receiveOption = socketObject~setOption("SO_RCVTIMEO", socketTimeoutMilliseconds)
  if receiveOption == .nil then do
    ignore = socketObject~close
    state = "DISCONNECTED"
    lastError = "TIMEOUT_CONFIG_FAILED:SO_RCVTIMEO"
    return .TerminalResult~failure("BROKER_SOCKET_TIMEOUT_CONFIG_FAILED", "SO_RCVTIMEO")
  end
  sendOption = socketObject~setOption("SO_SNDTIMEO", socketTimeoutMilliseconds)
  if sendOption == .nil then do
    ignore = socketObject~close
    state = "DISCONNECTED"
    lastError = "TIMEOUT_CONFIG_FAILED:SO_SNDTIMEO"
    return .TerminalResult~failure("BROKER_SOCKET_TIMEOUT_CONFIG_FAILED", "SO_SNDTIMEO")
  end
  connection = .StreamSocket~new(socketObject)

  signal on syntax name nonceFailure
  clientNonce = nonceSource~nextNonceHex~string~strip~lower
  signal off syntax
  if clientNonce~length \= 64 | verify(clientNonce, "0123456789abcdef") \= 0 then return self~failAndClose("BROKER_SOCKET_NONCE_SOURCE_INVALID", "client nonce source returned invalid data")
  hello = .directory~new
  hello["type"] = "AUTH_HELLO"
  hello["protocol"] = .TerminalBrokerSocketBuild~PROTOCOL
  hello["principal"] = principal
  hello["key_id"] = keyId
  hello["client_nonce"] = clientNonce
  hello["mac"] = .HMACSHA512~digest(keyHex, .TerminalBrokerSocketProtocol~helloText(principal, keyId, clientNonce))
  sent = framer~sendRecord(connection, .json~toJson(hello))
  if \sent~ok then return self~failAndClose(sent~code, sent~detail)

  challengeResult = framer~receiveRecord(connection)
  if \challengeResult~ok then return self~failAndClose(challengeResult~code, challengeResult~detail)
  parsed = self~parseRecord(challengeResult~value)
  if \parsed~ok then return self~failAndClose(parsed~code, parsed~detail)
  challenge = parsed~value
  if self~recordString(challenge, "type") \== "AUTH_CHALLENGE" then return self~failAndClose("BROKER_SOCKET_CHALLENGE_INVALID", "AUTH_CHALLENGE required")
  if self~recordString(challenge, "protocol") \== .TerminalBrokerSocketBuild~PROTOCOL then return self~failAndClose("BROKER_SOCKET_PROTOCOL_MISMATCH", "unsupported socket protocol")
  serverNonce = self~recordString(challenge, "server_nonce")~strip~lower
  if serverNonce~length \= 64 | verify(serverNonce, "0123456789abcdef") \= 0 then return self~failAndClose("BROKER_SOCKET_NONCE_INVALID", "server nonce must be 32-byte hexadecimal")
  challengeMac = self~recordString(challenge, "mac")~strip~lower
  expected = .HMACSHA512~digest(keyHex, .TerminalBrokerSocketProtocol~challengeText(principal, keyId, clientNonce, serverNonce))
  if challengeMac~length \= 128 then return self~failAndClose("BROKER_SOCKET_SERVER_AUTH_FAILED", "challenge MAC is invalid")
  if verify(challengeMac, "0123456789abcdef") \= 0 then return self~failAndClose("BROKER_SOCKET_SERVER_AUTH_FAILED", "challenge MAC is invalid")
  if \.CryptoUtils~secureEquals(expected, challengeMac) then return self~failAndClose("BROKER_SOCKET_SERVER_AUTH_FAILED", "server authentication failed")
  state = "AUTHENTICATED"
  sequence = 1
  lastError = ""
  self~alchemyTouch("SOCKET_CONNECT")
  ignore = self~terminalLifecycleEvent("IPC_AUTHENTICATED", principal)
  return .TerminalResult~success(.true)
nonceFailure:
  signal off syntax
  return self~failAndClose("BROKER_SOCKET_NONCE_SOURCE_FAILED", condition("D"))

::method requestFrame public
  expose principal keyId keyHex framer connection clientNonce serverNonce state sequence requestCount lastError
  use strict arg brokerFrameArg
  if state \== "AUTHENTICATED" | connection == .nil then return .TerminalResult~failure("BROKER_SOCKET_NOT_AUTHENTICATED")
  brokerFrame = brokerFrameArg~string
  if brokerFrame == "" then return .TerminalResult~failure("BROKER_SOCKET_BROKER_FRAME_REQUIRED")
  record = .directory~new
  record["type"] = "BROKER_REQUEST"
  record["protocol"] = .TerminalBrokerSocketBuild~PROTOCOL
  record["sequence"] = sequence
  record["frame"] = brokerFrame
  record["mac"] = .HMACSHA512~digest(keyHex, .TerminalBrokerSocketProtocol~requestText(principal, keyId, clientNonce, serverNonce, sequence, brokerFrame))
  sent = framer~sendRecord(connection, .json~toJson(record))
  if \sent~ok then return self~failAndClose(sent~code, sent~detail)
  responseResult = framer~receiveRecord(connection)
  if \responseResult~ok then return self~failAndClose(responseResult~code, responseResult~detail)
  parsed = self~parseRecord(responseResult~value)
  if \parsed~ok then return self~failAndClose(parsed~code, parsed~detail)
  response = parsed~value
  if self~recordString(response, "type") \== "BROKER_RESPONSE" then return self~failAndClose("BROKER_SOCKET_RESPONSE_INVALID", "BROKER_RESPONSE required")
  if self~recordString(response, "protocol") \== .TerminalBrokerSocketBuild~PROTOCOL then return self~failAndClose("BROKER_SOCKET_PROTOCOL_MISMATCH", "unsupported socket protocol")
  responseSequence = self~recordWhole(response, "sequence")
  if \responseSequence~ok then return self~failAndClose(responseSequence~code, responseSequence~detail)
  if responseSequence~value \= sequence then return self~failAndClose("BROKER_SOCKET_SEQUENCE_INVALID", "response sequence mismatch")
  responseFrame = self~recordString(response, "frame")
  if responseFrame == "" then return self~failAndClose("BROKER_SOCKET_RESPONSE_INVALID", "response broker frame is empty")
  responseMac = self~recordString(response, "mac")~strip~lower
  expected = .HMACSHA512~digest(keyHex, .TerminalBrokerSocketProtocol~responseText(principal, keyId, clientNonce, serverNonce, sequence, responseFrame))
  if responseMac~length \= 128 then return self~failAndClose("BROKER_SOCKET_RESPONSE_AUTH_FAILED", "response MAC is invalid")
  if verify(responseMac, "0123456789abcdef") \= 0 then return self~failAndClose("BROKER_SOCKET_RESPONSE_AUTH_FAILED", "response MAC is invalid")
  if \.CryptoUtils~secureEquals(expected, responseMac) then return self~failAndClose("BROKER_SOCKET_RESPONSE_AUTH_FAILED", "response authentication failed")
  sequence += 1
  requestCount += 1
  lastError = ""
  self~alchemyTouch("SOCKET_REQUEST")
  return .TerminalResult~success(responseFrame)

::method requestJson public
  use strict arg jsonTextArg
  framed = .TerminalBrokerFrameCodec~encode(jsonTextArg~string)
  if \framed~ok then return framed
  response = self~requestFrame(framed~value)
  if \response~ok then return response
  decoded = .TerminalBrokerFrameCodec~decode(response~value)
  if \decoded~ok then return decoded
  return .TerminalResult~success(decoded~value)

::method close public
  expose principal keyId keyHex framer connection clientNonce serverNonce state sequence lastError
  use strict arg
  if connection == .nil then do
    state = "DISCONNECTED"
    return .TerminalResult~success(.true)
  end
  if state == "AUTHENTICATED" then do
    bye = .directory~new
    bye["type"] = "BYE"
    bye["protocol"] = .TerminalBrokerSocketBuild~PROTOCOL
    bye["sequence"] = sequence
    bye["mac"] = .HMACSHA512~digest(keyHex, .TerminalBrokerSocketProtocol~byeText(principal, keyId, clientNonce, serverNonce, sequence))
    sent = framer~sendRecord(connection, .json~toJson(bye))
    if sent~ok then do
      ackResult = framer~receiveRecord(connection)
      if ackResult~ok then do
        parsed = self~parseRecord(ackResult~value)
        if parsed~ok then do
          ack = parsed~value
          if self~recordString(ack, "type") == "BYE_ACK" & self~recordString(ack, "protocol") == .TerminalBrokerSocketBuild~PROTOCOL then do
            ackSequence = self~recordWhole(ack, "sequence")
            if ackSequence~ok then if ackSequence~value == sequence then do
              ackMac = self~recordString(ack, "mac")~strip~lower
              expected = .HMACSHA512~digest(keyHex, .TerminalBrokerSocketProtocol~byeAckText(principal, keyId, clientNonce, serverNonce, sequence))
              if ackMac~length == 128 then if verify(ackMac, "0123456789abcdef") = 0 then if .CryptoUtils~secureEquals(expected, ackMac) then do
                ignore = connection~close
                connection = .nil
                state = "DISCONNECTED"
                lastError = ""
                self~alchemyTouch("SOCKET_CLOSE")
                ignore = self~terminalLifecycleEvent("IPC_DISCONNECTED")
                return .TerminalResult~success(.true)
              end
            end
          end
        end
      end
    end
  end
  ignore = connection~close
  connection = .nil
  state = "DISCONNECTED"
  lastError = "BROKER_SOCKET_CLOSE_UNCONFIRMED"
  self~alchemyTouch("SOCKET_CLOSE_UNCONFIRMED")
  return .TerminalResult~failure("BROKER_SOCKET_CLOSE_UNCONFIRMED", "authenticated BYE acknowledgement was not verified")

::method parseRecord private
  use strict arg jsonTextArg
  signal on syntax name invalidJson
  record = .json~fromJson(jsonTextArg~string)
  signal off syntax
  if record == .nil then return .TerminalResult~failure("BROKER_SOCKET_JSON_INVALID", "socket record must be a JSON object")
  if \record~isA(.Directory) then return .TerminalResult~failure("BROKER_SOCKET_JSON_INVALID", "socket record must be a JSON object")
  return .TerminalResult~success(record)
invalidJson:
  signal off syntax
  return .TerminalResult~failure("BROKER_SOCKET_JSON_INVALID", "socket record JSON could not be parsed")

::method recordString private
  use strict arg record, key
  value = record~at(key)
  if value == .nil then return ""
  return value~string

::method recordWhole private
  use strict arg record, key
  value = record~at(key)
  if value == .nil then return .TerminalResult~failure("BROKER_SOCKET_SEQUENCE_REQUIRED", "sequence is required")
  if \datatype(value, "W") then return .TerminalResult~failure("BROKER_SOCKET_SEQUENCE_INVALID", "sequence must be a whole number")
  if value < 1 then return .TerminalResult~failure("BROKER_SOCKET_SEQUENCE_INVALID", "sequence must be positive")
  return .TerminalResult~success(value + 0)

::method failAndClose private
  expose connection state lastError
  use strict arg codeArg, detailArg = ""
  if connection \== .nil then ignore = connection~close
  connection = .nil
  state = "DISCONNECTED"
  lastError = codeArg~string || ":" || detailArg~string
  self~alchemyTouch("SOCKET_FAILURE")
  return .TerminalResult~failure(codeArg, detailArg)

::method uninit
  expose connection state
  if connection \== .nil then ignore = connection~close
  connection = .nil
  state = "DISCONNECTED"


::requires "TerminalBrokerProtocol.cls"
::requires "crypto.cls"
::requires "json.cls"
::requires "socket.cls"
::requires "streamsocket.cls"
