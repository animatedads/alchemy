/*
 * ObjectQueueFabric encrypted authenticated TCP transport.
 * v0.9-dev6 retains queue.transport/2 and adds bounded non-blocking connect.
 * mandatory source-IP admission while preserving queue/channel semantics.
 *
 * HELLO/CHALLENGE authenticate the configured peer with HMAC-SHA-512.  After
 * both random nonces are known, directional per-connection keys are derived
 * from the configured transport PSK. Command/result payloads are protected by
 * ChaCha20 plus encrypt-then-HMAC-SHA-512. The listener rejects an accepted
 * socket whose numeric peer address is not explicitly bound to a trusted peer
 * before reading protocol bytes or performing cryptographic work.
 *
 * Built on ooRexx Socket / StreamSocket objects. Channel and queue-manager
 * semantics remain above this layer.
 */

::class QueueSocketTransportBuild public
::constant VERSION "0.8"
::constant PROTOCOL "queue.transport/2"
::constant FRAME_LIMIT 8388608

::class QueueSocketTransportAuthority
::method init
  nop

::class QueueSocketNonceSource public
::method nextNonceHex
  use strict arg
  randomStream = .stream~new("/dev/urandom")
  signal on notready name randomFailure
  nonceBytes = randomStream~charIn(, 32)
  signal off notready
  ignore = randomStream~close
  if nonceBytes~length \= 32 then raise syntax 88.900 array("Queue socket nonce source returned the wrong byte count")
  return c2x(nonceBytes)~lower
randomFailure:
  signal off notready
  ignore = randomStream~close
  raise syntax 88.900 array("Queue socket nonce source is unavailable")

::class QueueSocketFramer public
::attribute maxFrameBytes get

::method init
  expose maxFrameBytes
  use strict arg maxFrameBytes = 8388608
  if \datatype(maxFrameBytes, "W") | maxFrameBytes < 1 then raise syntax 88.900 array("Queue socket frame limit must be a positive whole number")
  maxFrameBytes = maxFrameBytes

::method sendFrame
  expose maxFrameBytes
  use strict arg connection, payload
  payload = payload~string
  payloadLength = payload~length
  if payloadLength > maxFrameBytes then return .QueueOperationResult~failure("FRAME_TOO_LARGE", payloadLength)
  if payloadLength > 4294967295 then return .QueueOperationResult~failure("FRAME_TOO_LARGE", payloadLength)
  header = right(d2x(payloadLength), 8, "0")
  sendResult = self~writeAll(connection, header || payload)
  if \sendResult~ok then return sendResult
  return .QueueOperationResult~success(payloadLength)

::method receiveFrame
  expose maxFrameBytes
  use strict arg connection
  headerResult = self~readExact(connection, 8)
  if \headerResult~ok then return headerResult
  header = headerResult~value
  if verify(header~lower, "0123456789abcdef") \= 0 then return .QueueOperationResult~failure("FRAME_HEADER_INVALID")
  signal on syntax name invalidHeader
  payloadLength = x2d(header)
  signal off syntax
  if payloadLength > maxFrameBytes then return .QueueOperationResult~failure("FRAME_TOO_LARGE", payloadLength)
  if payloadLength = 0 then return .QueueOperationResult~success("")
  return self~readExact(connection, payloadLength)
invalidHeader:
  signal off syntax
  return .QueueOperationResult~failure("FRAME_HEADER_INVALID")

::method writeAll private
  use strict arg connection, bytes
  offset = 1
  do while offset <= bytes~length
    signal on notready name writeFailure
    written = connection~charOut(bytes~substr(offset))
    signal off notready
    if \datatype(written, "W") | written <= 0 then return .QueueOperationResult~failure("SOCKET_WRITE_FAILED", connection~description)
    offset += written
  end
  return .QueueOperationResult~success(bytes~length)
writeFailure:
  signal off notready
  return .QueueOperationResult~failure("SOCKET_WRITE_FAILED", connection~description)

::method readExact private
  use strict arg connection, byteCount
  if byteCount = 0 then return .QueueOperationResult~success("")
  signal on notready name readFailure
  bytes = connection~charIn(, byteCount)
  signal off notready
  if bytes~length \= byteCount then return .QueueOperationResult~failure("SOCKET_EOF", "wanted=" || byteCount || ";got=" || bytes~length)
  return .QueueOperationResult~success(bytes)
readFailure:
  signal off notready
  return .QueueOperationResult~failure("SOCKET_READ_FAILED", connection~description)

::class QueueSocketEndpoint public
::attribute endpointId get
::attribute endpointOrder get
::attribute remoteManager get
::attribute host get
::attribute port get
::attribute principal get
::attribute keyId get
::attribute connectTimeoutMs get
::attribute attemptCount get
::attribute successCount get
::attribute failureCount get
::attribute lastError get
::attribute lastAttemptAt get
::attribute lastSuccessAt get
::attribute healthAttemptCount get
::attribute healthSuccessCount get
::attribute healthFailureCount get
::attribute lastHealthAt get
::attribute lastHealthError get

::method init
  expose endpointId endpointOrder remoteManager host port principal keyId keyHex connectTimeoutMs attemptCount successCount failureCount lastError lastAttemptAt lastSuccessAt healthAttemptCount healthSuccessCount healthFailureCount lastHealthAt lastHealthError transportAuthority
  use strict arg remoteManager, host, port, principal, keyId, keyHex, authorityCandidate, endpointOrder = 1, connectTimeoutArg = 5000
  remoteManager = remoteManager~string~strip
  host = host~string~strip
  principal = principal~string
  keyId = keyId~string~strip
  keyHex = keyHex~string~strip~lower
  if remoteManager = "" | host = "" | keyId = "" then raise syntax 88.900 array("Queue socket endpoint identity fields must not be empty")
  if \datatype(port, "W") | port < 1 | port > 65535 then raise syntax 88.900 array("Queue socket endpoint port is invalid")
  if keyHex = "" | verify(keyHex, "0123456789abcdef") \= 0 | keyHex~length // 2 \= 0 then raise syntax 88.900 array("Queue socket endpoint transport key must be even-length hexadecimal")
  if keyHex~length < 64 then raise syntax 88.900 array("Queue socket endpoint transport key must be at least 32 bytes / 64 hex characters")
  if \datatype(endpointOrder, "W") | endpointOrder < 1 then raise syntax 88.900 array("Queue socket endpoint order must be a positive whole number")
  if \datatype(connectTimeoutArg, "W") | connectTimeoutArg < 1 then raise syntax 88.900 array("Queue socket connect timeout must be a positive whole number of milliseconds")
  port = port
  endpointOrder = endpointOrder
  connectTimeoutMs = connectTimeoutArg + 0
  endpointId = remoteManager || "|" || host || ":" || port || "|" || keyId
  attemptCount = 0
  successCount = 0
  failureCount = 0
  lastError = ""
  lastAttemptAt = ""
  lastSuccessAt = ""
  healthAttemptCount = 0
  healthSuccessCount = 0
  healthFailureCount = 0
  lastHealthAt = ""
  lastHealthError = ""
  transportAuthority = authorityCandidate

::method macInternal
  expose keyHex transportAuthority
  use strict arg text, authorityCandidate
  if authorityCandidate \== transportAuthority then raise syntax 88.900 array("Queue socket endpoint authority mismatch")
  return .QueueHmacSha512~digest(keyHex, text)

::method verifyInternal
  expose keyHex transportAuthority
  use strict arg text, suppliedMac, authorityCandidate
  if authorityCandidate \== transportAuthority then return .false
  expectedMac = .QueueHmacSha512~digest(keyHex, text)
  return .QueueHmacSha512~secureEquals(expectedMac, suppliedMac~string~lower)

::method sessionCryptoInternal
  expose keyHex transportAuthority
  use strict arg transcript, authorityCandidate
  if authorityCandidate \== transportAuthority then raise syntax 88.900 array("Queue socket endpoint authority mismatch")
  return .QueueSocketSessionCrypto~new(keyHex, transcript)

::method noteAttemptInternal
  expose attemptCount lastAttemptAt transportAuthority
  use strict arg authorityCandidate
  if authorityCandidate \== transportAuthority then return .false
  attemptCount += 1
  lastAttemptAt = .QueueClock~timestamp
  return .true

::method noteSuccessInternal
  expose successCount lastError lastSuccessAt transportAuthority
  use strict arg authorityCandidate
  if authorityCandidate \== transportAuthority then return .false
  successCount += 1
  lastError = ""
  lastSuccessAt = .QueueClock~timestamp
  return .true

::method noteFailureInternal
  expose failureCount lastError transportAuthority
  use strict arg detail, authorityCandidate
  if authorityCandidate \== transportAuthority then return .false
  failureCount += 1
  lastError = detail~string
  return .true

::method noteHealthAttemptInternal
  expose healthAttemptCount transportAuthority
  use strict arg authorityCandidate
  if authorityCandidate \== transportAuthority then return .false
  healthAttemptCount += 1
  return .true

::method noteHealthSuccessInternal
  expose healthSuccessCount lastHealthAt lastHealthError transportAuthority
  use strict arg authorityCandidate
  if authorityCandidate \== transportAuthority then return .false
  healthSuccessCount += 1
  lastHealthAt = .QueueClock~timestamp
  lastHealthError = ""
  return .true

::method noteHealthFailureInternal
  expose healthFailureCount lastHealthError transportAuthority
  use strict arg detail, authorityCandidate
  if authorityCandidate \== transportAuthority then return .false
  healthFailureCount += 1
  lastHealthError = detail~string
  return .true

::class QueueSocketIpv4 public

::method canonical class
  use strict arg address
  address = address~string~strip
  if address = "" then raise syntax 88.900 array("Queue socket source IP must not be empty")
  if address~pos("/") > 0 then raise syntax 88.900 array("Queue socket application allowlist requires an exact IPv4 address, not CIDR: " || address)
  if address~pos(":") > 0 then raise syntax 88.900 array("Queue socket v0.9-dev6 source admission currently supports IPv4 only: " || address)
  parts = translate(address, " ", ".")
  if words(parts) \= 4 then raise syntax 88.900 array("Queue socket source IP is not canonical dotted-quad IPv4: " || address)
  canonical = ""
  do i = 1 to 4
    part = word(parts, i)
    if \datatype(part, "W") then raise syntax 88.900 array("Queue socket source IP contains a non-decimal IPv4 octet: " || address)
    if part~length > 1 & left(part, 1) = "0" then raise syntax 88.900 array("Queue socket source IP must use canonical decimal IPv4 without leading zeroes: " || address)
    value = part + 0
    if value < 0 | value > 255 then raise syntax 88.900 array("Queue socket source IP IPv4 octet is out of range: " || address)
    if canonical = "" then canonical = value
    else canonical = canonical || "." || value
  end
  if canonical \= address then raise syntax 88.900 array("Queue socket source IP must be canonical dotted-quad IPv4: " || address)
  if canonical = "0.0.0.0" then raise syntax 88.900 array("Queue socket source-IP allowlist cannot use the unspecified IPv4 address 0.0.0.0")
  return canonical

::method canonicalOrEmpty class
  use strict arg address
  signal on syntax name invalidAddress
  return self~canonical(address)
invalidAddress:
  signal off syntax
  return ""

::class QueueSocketPeer public
::attribute sourceManager get
::attribute principal get
::attribute keyId get
::attribute allowedIpAddresses get

::method init
  expose sourceManager principal keyId keyHex transportAuthority allowedIpSet allowedIpAddresses
  use strict arg sourceManager, principal, keyId, keyHex, allowedIpsArg, authorityCandidate
  sourceManager = sourceManager~string~strip
  principal = principal~string
  keyId = keyId~string~strip
  keyHex = keyHex~string~strip~lower
  if sourceManager = "" | keyId = "" then raise syntax 88.900 array("Queue socket peer identity fields must not be empty")
  if keyHex = "" | verify(keyHex, "0123456789abcdef") \= 0 | keyHex~length // 2 \= 0 then raise syntax 88.900 array("Queue socket peer transport key must be even-length hexadecimal")
  if keyHex~length < 64 then raise syntax 88.900 array("Queue socket peer transport key must be at least 32 bytes / 64 hex characters")
  if allowedIpsArg == .nil then raise syntax 88.900 array("Queue socket peer requires an explicit source-IP allowlist")
  allowedIpSet = .table~new
  allowedIpAddresses = .array~new
  do ip over allowedIpsArg
    ip = ip~string~strip
    if ip = "" then raise syntax 88.900 array("Queue socket peer allowlist contains an empty IP address")
    if ip~pos("/") > 0 then raise syntax 88.900 array("Queue socket application allowlist requires exact IP addresses, not CIDR ranges: " || ip)
    if \allowedIpSet~hasIndex(ip) then do
      allowedIpSet[ip] = .true
      allowedIpAddresses~append(ip)
    end
  end
  if allowedIpAddresses~items = 0 then raise syntax 88.900 array("Queue socket peer source-IP allowlist must not be empty")
  transportAuthority = authorityCandidate

::method allowsIpInternal
  expose allowedIpSet transportAuthority
  use strict arg sourceIp, authorityCandidate
  if authorityCandidate \== transportAuthority then return .false
  sourceIp = .QueueSocketIpv4~canonicalOrEmpty(sourceIp)
  if sourceIp = "" then return .false
  return allowedIpSet~hasIndex(sourceIp)

::method macInternal
  expose keyHex transportAuthority
  use strict arg text, authorityCandidate
  if authorityCandidate \== transportAuthority then raise syntax 88.900 array("Queue socket peer authority mismatch")
  return .QueueHmacSha512~digest(keyHex, text)

::method verifyInternal
  expose keyHex transportAuthority
  use strict arg text, suppliedMac, authorityCandidate
  if authorityCandidate \== transportAuthority then return .false
  expectedMac = .QueueHmacSha512~digest(keyHex, text)
  return .QueueHmacSha512~secureEquals(expectedMac, suppliedMac~string~lower)

::method sessionCryptoInternal
  expose keyHex transportAuthority
  use strict arg transcript, authorityCandidate
  if authorityCandidate \== transportAuthority then raise syntax 88.900 array("Queue socket peer authority mismatch")
  return .QueueSocketSessionCrypto~new(keyHex, transcript)

::class QueueSocketProtocol public

::method helloText class
  use strict arg sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce
  return .QueueSocketTransportBuild~PROTOCOL || "0a"x || "HELLO" || "0a"x || sourceManager || "0a"x || destinationManager || "0a"x || receiverChannel || "0a"x || principal || "0a"x || keyId || "0a"x || clientNonce

::method challengeText class
  use strict arg sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce
  return .QueueSocketTransportBuild~PROTOCOL || "0a"x || "CHALLENGE" || "0a"x || sourceManager || "0a"x || destinationManager || "0a"x || receiverChannel || "0a"x || principal || "0a"x || keyId || "0a"x || clientNonce || "0a"x || serverNonce

::method deliveryText class
  use strict arg sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce, encodedEnvelope
  return .QueueSocketTransportBuild~PROTOCOL || "0a"x || "DELIVER" || "0a"x || sourceManager || "0a"x || destinationManager || "0a"x || receiverChannel || "0a"x || principal || "0a"x || keyId || "0a"x || clientNonce || "0a"x || serverNonce || "0a"x || encodedEnvelope

::method resultText class
  use strict arg sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce, okText, code, detail, transferId, packageId, queueName, acceptedAt, receiptSourceManager, duplicateText
  return .QueueSocketTransportBuild~PROTOCOL || "0a"x || "RESULT" || "0a"x || sourceManager || "0a"x || destinationManager || "0a"x || receiverChannel || "0a"x || principal || "0a"x || keyId || "0a"x || clientNonce || "0a"x || serverNonce || "0a"x || okText || "0a"x || code || "0a"x || detail || "0a"x || transferId || "0a"x || packageId || "0a"x || queueName || "0a"x || acceptedAt || "0a"x || receiptSourceManager || "0a"x || duplicateText

::method probeText class
  use strict arg sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce
  return .QueueSocketTransportBuild~PROTOCOL || "0a"x || "PROBE" || "0a"x || sourceManager || "0a"x || destinationManager || "0a"x || receiverChannel || "0a"x || principal || "0a"x || keyId || "0a"x || clientNonce || "0a"x || serverNonce

::method healthText class
  use strict arg sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce, statusText, serverTimestamp
  return .QueueSocketTransportBuild~PROTOCOL || "0a"x || "HEALTH" || "0a"x || sourceManager || "0a"x || destinationManager || "0a"x || receiverChannel || "0a"x || principal || "0a"x || keyId || "0a"x || clientNonce || "0a"x || serverNonce || "0a"x || statusText || "0a"x || serverTimestamp

::class QueueSocketSessionCrypto public
::attribute transcript get

::method init
  expose transcript c2sEnc c2sMac c2sNonce s2cEnc s2cMac s2cNonce
  use strict arg masterKeyHex, transcript
  transcript = transcript~string
  root = .QueueHmacSha512~digest(masterKeyHex, .QueueSocketTransportBuild~PROTOCOL || "0a"x || "SESSION" || "0a"x || transcript)
  c2sEnc = .QueueHmacSha512~digest(root, "C2S-ENC")~left(64)
  c2sMac = .QueueHmacSha512~digest(root, "C2S-MAC")
  c2sNonce = .QueueHmacSha512~digest(root, "C2S-NONCE")~left(24)
  s2cEnc = .QueueHmacSha512~digest(root, "S2C-ENC")~left(64)
  s2cMac = .QueueHmacSha512~digest(root, "S2C-MAC")
  s2cNonce = .QueueHmacSha512~digest(root, "S2C-NONCE")~left(24)

::method seal
  expose transcript c2sEnc c2sMac c2sNonce s2cEnc s2cMac s2cNonce
  use strict arg direction, plaintext
  direction = direction~string~translate
  if direction = "C2S" then do; encKey=c2sEnc; macKey=c2sMac; nonce=c2sNonce; end
  else if direction = "S2C" then do; encKey=s2cEnc; macKey=s2cMac; nonce=s2cNonce; end
  else raise syntax 88.900 array("Queue socket secure direction is invalid: " || direction)
  cipher = .ChaCha20~encrypt(plaintext~string, encKey, nonce)
  cipherHex = c2x(cipher)~lower
  authText = self~authText(direction, cipherHex)
  tag = .QueueHmacSha512~digest(macKey, authText)
  return .QueueRecordCodec~encode("SECURE", .array~of(.QueueSocketTransportBuild~PROTOCOL, direction, cipherHex, tag))

::method open
  expose transcript c2sEnc c2sMac c2sNonce s2cEnc s2cMac s2cNonce
  use strict arg direction, sealedFrame
  direction = direction~string~translate
  if direction = "C2S" then do; encKey=c2sEnc; macKey=c2sMac; nonce=c2sNonce; end
  else if direction = "S2C" then do; encKey=s2cEnc; macKey=s2cMac; nonce=s2cNonce; end
  else return .QueueOperationResult~failure("SECURE_DIRECTION_INVALID", direction)
  row = .QueueRecordCodec~decode(sealedFrame)
  if row == .nil | row~items \= 5 then return .QueueOperationResult~failure("SECURE_FRAME_INVALID")
  if row[1] \= "SECURE" | row[2] \= .QueueSocketTransportBuild~PROTOCOL | row[3] \= direction then return .QueueOperationResult~failure("SECURE_FRAME_INVALID")
  cipherHex = row[4]~string~lower
  tag = row[5]~string~lower
  if cipherHex \= "" then if verify(cipherHex, "0123456789abcdef") \= 0 | cipherHex~length // 2 \= 0 then return .QueueOperationResult~failure("SECURE_CIPHERTEXT_INVALID")
  authText = self~authText(direction, cipherHex)
  expected = .QueueHmacSha512~digest(macKey, authText)
  if \.QueueHmacSha512~secureEquals(expected, tag) then return .QueueOperationResult~failure("SECURE_AUTHENTICATION_FAILED")
  signal on syntax name decryptFailure
  cipher = x2c(cipherHex)
  plaintext = .ChaCha20~decrypt(cipher, encKey, nonce)
  signal off syntax
  return .QueueOperationResult~success(plaintext)
decryptFailure:
  signal off syntax
  return .QueueOperationResult~failure("SECURE_DECRYPT_FAILED")

::method authText private
  expose transcript
  use strict arg direction, cipherHex
  return .QueueSocketTransportBuild~PROTOCOL || "0a"x || "SECURE" || "0a"x || direction || "0a"x || transcript || "0a"x || cipherHex

::method transcript class
  use strict arg sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce
  return sourceManager || "0a"x || destinationManager || "0a"x || receiverChannel || "0a"x || principal || "0a"x || keyId || "0a"x || clientNonce || "0a"x || serverNonce

::class QueueSocketAuthenticatedSession public
::attribute endpoint get
::attribute connection get
::attribute sourceManager get
::attribute destinationManager get
::attribute receiverChannel get
::attribute principal get
::attribute keyId get
::attribute clientNonce get
::attribute serverNonce get
::attribute crypto get

::method init
  expose endpoint connection sourceManager destinationManager receiverChannel principal keyId clientNonce serverNonce crypto
  use strict arg endpoint, connection, sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce, crypto

::class QueueSocketConnector public
/* Establish a bounded TCP connection without relying on the platform's
 * potentially minutes-long blocking connect timeout.  FIONBIO + select keeps
 * the queue.transport/2 delivery boundary bounded even when a route silently
 * drops SYN packets.  The socket is restored to blocking mode before it is
 * wrapped as a StreamSocket, so the established protocol remains unchanged. */
::method connect class
  use strict arg host, port, timeoutMs = 5000
  if \datatype(timeoutMs, "W") | timeoutMs < 1 then return .QueueOperationResult~failure("CONNECT_TIMEOUT_INVALID", timeoutMs)
  socketObject = .Socket~new("AF_INET", "SOCK_STREAM", 0)
  if socketObject~errno \= 0 then return .QueueOperationResult~failure("SOCKET_CREATE_FAILED", socketObject~errno)
  nonblocking = socketObject~ioctl("FIONBIO", 1)
  if nonblocking == .nil then do
    detail = socketObject~errno
    ignore = socketObject~close
    return .QueueOperationResult~failure("CONNECT_NONBLOCK_UNAVAILABLE", detail)
  end
  signal on syntax name connectSyntax
  address = .InetAddress~new(host, port)
  signal off syntax
  rc = socketObject~connect(address)
  if rc = 0 then return self~connected(socketObject)
  connectErr = socketObject~errno~string
  if connectErr \= "EINPROGRESS" & connectErr \= "EWOULDBLOCK" & connectErr \= "EALREADY" then do
    ignore = socketObject~close
    return .QueueOperationResult~failure("CONNECT_FAILED", connectErr)
  end
  reads = .array~new
  writes = .array~of(socketObject)
  excepts = .array~of(socketObject)
  waitSeconds = (timeoutMs + 0) / 1000
  selected = socketObject~select(reads, writes, excepts, waitSeconds)
  if selected == .nil then do
    detail = socketObject~errno
    ignore = socketObject~close
    return .QueueOperationResult~failure("CONNECT_SELECT_FAILED", detail)
  end
  if selected = 0 then do
    ignore = socketObject~close
    return .QueueOperationResult~failure("CONNECT_TIMEOUT", "host=" || host || ";port=" || port || ";timeout_ms=" || timeoutMs)
  end
  socketError = socketObject~getOption("SO_ERROR")
  if socketError == .nil then do
    detail = socketObject~errno
    ignore = socketObject~close
    return .QueueOperationResult~failure("CONNECT_STATUS_UNAVAILABLE", detail)
  end
  if socketError \= 0 then do
    ignore = socketObject~close
    return .QueueOperationResult~failure("CONNECT_FAILED", socketError)
  end
  return self~connected(socketObject)
connectSyntax:
  detail = condition("D")
  signal off syntax
  ignore = socketObject~close
  return .QueueOperationResult~failure("CONNECT_ADDRESS_INVALID", detail)

::method connected class private
  use strict arg socketObject
  reset = socketObject~ioctl("FIONBIO", 0)
  if reset == .nil then do
    detail = socketObject~errno
    ignore = socketObject~close
    return .QueueOperationResult~failure("CONNECT_BLOCKING_RESTORE_FAILED", detail)
  end
  return .QueueOperationResult~success(.StreamSocket~new(socketObject))

::class QueueSocketClientTransport subclass AlchemyObject public
::attribute adminPrincipal get
::attribute framer get
::attribute payloadCodec get

::method init
  expose endpoints endpointGroups adminPrincipal payloadCodec nonceSource framer authority
  use strict arg adminPrincipal = "queue-admin", payloadCodec = .nil, nonceSource = .nil, framer = .nil
  endpoints = .table~new
  endpointGroups = .table~new
  adminPrincipal = adminPrincipal~string
  if payloadCodec == .nil then payloadCodec = .QueueGraphPayloadCodec~new
  payloadCodec = payloadCodec
  if payloadCodec~hasMethod("typeRegistry") then ignore = payloadCodec~typeRegistry~register(.QueueTransmissionEnvelope~PERSISTENT_TYPE, .QueueTransmissionEnvelopeFactory~new)
  if nonceSource == .nil then nonceSource = .QueueSocketNonceSource~new
  nonceSource = nonceSource
  if framer == .nil then framer = .QueueSocketFramer~new
  framer = framer
  authority = .QueueSocketTransportAuthority~new

  limitations = .array~of("One delivery request per TCP connection", "Failover advances only for conservatively classified endpoint-unavailable failures")
  meta = .QueueFabricAlchemyMetadata~standard("Authenticated socket client transport and ordered endpoint failover", "queue.socket.client.transport/0.9-dev3", limitations)
  self~initAlchemy(meta)
  self~registerStateVariable("adminPrincipal", "INTERNAL", "socket transport administration principal")
  self~registerMethodContract("DELIVER", "Deliver one authenticated transfer envelope", .array~of("REMOTE_MANAGER", "REMOTE_CHANNEL", "ENVELOPE", "PRINCIPAL"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("PROBE", "Perform one authenticated endpoint health probe", .array~of("REMOTE_MANAGER", "REMOTE_CHANNEL", "PRINCIPAL"), "QUEUEOPERATIONRESULT", .false)
  self~describeMethodPolicy("DELIVER", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("PROBE", "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~recordRelationship("PAYLOAD_CODEC", payloadCodec, "authenticated graph payload boundary", "INTERNAL")
  self~recordRelationship("FRAMER", framer, "bounded transport frame codec", "INTERNAL")

::method registerEndpoint
  expose endpoints endpointGroups authority
  use strict arg remoteManager, host, port, principal, keyId, keyHex, connectTimeoutMs = 5000
  endpoint = .QueueSocketEndpoint~new(remoteManager, host, port, principal, keyId, keyHex, authority, 1, connectTimeoutMs)
  key = remoteManager~string~translate
  group = .array~of(endpoint)
  guard on
  endpoints[key] = endpoint
  endpointGroups[key] = group
  guard off
  return endpoint

::method registerFailoverEndpoint
  expose endpoints endpointGroups authority
  use strict arg remoteManager, host, port, principal, keyId, keyHex, connectTimeoutMs = 5000
  key = remoteManager~string~translate
  guard on
  group = endpointGroups~at(key)
  if group == .nil then do
    group = .array~new
    endpointGroups[key] = group
  end
  order = group~items + 1
  endpoint = .QueueSocketEndpoint~new(remoteManager, host, port, principal, keyId, keyHex, authority, order, connectTimeoutMs)
  do existing over group
    if existing~endpointId = endpoint~endpointId then do
      guard off
      return existing
    end
  end
  group~append(endpoint)
  if endpoints~at(key) == .nil then endpoints[key] = endpoint
  guard off
  return endpoint

::method unregisterEndpoint
  expose endpoints endpointGroups
  use strict arg remoteManager
  key = remoteManager~string~translate
  guard on
  endpoint = endpoints~remove(key)
  endpointGroups~remove(key)
  guard off
  return endpoint

::method endpoint
  expose endpoints
  use strict arg remoteManager
  return endpoints[remoteManager~string~translate]

::method endpointsFor
  expose endpointGroups
  use strict arg remoteManager
  group = endpointGroups~at(remoteManager~string~translate)
  rows = .array~new
  if group == .nil then return rows
  do endpoint over group
    rows~append(endpoint)
  end
  return rows

::method authorisedEndpoints
  expose endpointGroups adminPrincipal
  use strict arg principal
  rows = .array~new
  if principal~string \= adminPrincipal then return rows
  supplier = endpointGroups~supplier
  do while supplier~available
    group = supplier~item
    do endpoint over group
      rows~append(endpoint)
    end
    supplier~next
  end
  return rows

::method deliver
  use strict arg remoteManager, remoteChannel, envelope, principal
  candidates = self~eligibleEndpoints(remoteManager, principal)
  if candidates~items = 0 then do
    if self~endpoint(remoteManager) == .nil then return .QueueOperationResult~failure("REMOTE_MANAGER_UNAVAILABLE", remoteManager)
    return .QueueOperationResult~failure("TRANSPORT_PRINCIPAL_MISMATCH", principal)
  end
  lastResult = .nil
  do endpoint over candidates
    lastResult = self~deliverToEndpoint(endpoint, remoteManager, remoteChannel, envelope, principal)
    if lastResult~ok then return lastResult
    if \self~failoverEligible(lastResult) then return lastResult
  end
  return lastResult

::method probe
  use strict arg sourceManager, remoteManager, remoteChannel, principal
  candidates = self~eligibleEndpoints(remoteManager, principal)
  if candidates~items = 0 then do
    if self~endpoint(remoteManager) == .nil then return .QueueOperationResult~failure("REMOTE_MANAGER_UNAVAILABLE", remoteManager)
    return .QueueOperationResult~failure("TRANSPORT_PRINCIPAL_MISMATCH", principal)
  end
  lastResult = .nil
  do endpoint over candidates
    lastResult = self~probeEndpoint(endpoint, sourceManager, remoteManager, remoteChannel, principal)
    if lastResult~ok then return lastResult
    if \self~failoverEligible(lastResult) then return lastResult
  end
  return lastResult

::method eligibleEndpoints private
  use strict arg remoteManager, principal
  candidates = .array~new
  do endpoint over self~endpointsFor(remoteManager)
    if endpoint~principal = principal~string then candidates~append(endpoint)
  end
  return candidates

::method failoverEligible private
  use strict arg operationResult
  if operationResult~code = "REMOTE_MANAGER_UNAVAILABLE" then return .true
  if operationResult~code = "TRANSPORT_FAILURE" then return .true
  return .false

::method deliverToEndpoint private
  expose payloadCodec framer authority
  use strict arg endpoint, remoteManager, remoteChannel, envelope, principal
  ignore = endpoint~noteAttemptInternal(authority)
  sessionResult = self~openAuthenticatedSession(endpoint, envelope~sourceManager, remoteManager~string, remoteChannel, principal)
  if \sessionResult~ok then do
    ignore = endpoint~noteFailureInternal(sessionResult~code || ":" || sessionResult~detail, authority)
    return sessionResult
  end
  session = sessionResult~value
  connection = session~connection
  encodedEnvelope = payloadCodec~encode(envelope)
  plaintextFrame = .QueueRecordCodec~encode("DELIVER", .array~of(.QueueSocketTransportBuild~PROTOCOL, encodedEnvelope))
  deliveryFrame = session~crypto~seal("C2S", plaintextFrame)
  sendResult = framer~sendFrame(connection, deliveryFrame)
  if \sendResult~ok then return self~deliveryFailure(endpoint, connection, sendResult~code || ":" || sendResult~detail)

  resultFrameResult = framer~receiveFrame(connection)
  if \resultFrameResult~ok then return self~deliveryFailure(endpoint, connection, resultFrameResult~code || ":" || resultFrameResult~detail)
  ignore = connection~close
  openResult = session~crypto~open("S2C", resultFrameResult~value)
  if \openResult~ok then do
    ignore = endpoint~noteFailureInternal(openResult~code, authority)
    return .QueueOperationResult~failure(openResult~code, openResult~detail)
  end
  resultRow = .QueueRecordCodec~decode(openResult~value)
  if resultRow == .nil | resultRow~items \= 11 | resultRow[1] \= "RESULT" | resultRow[2] \= .QueueSocketTransportBuild~PROTOCOL then do
    ignore = endpoint~noteFailureInternal("RESULT_INVALID", authority)
    return .QueueOperationResult~failure("TRANSPORT_PROTOCOL_ERROR", "RESULT_INVALID")
  end
  okText = resultRow[3]
  code = resultRow[4]
  detail = resultRow[5]
  transferId = resultRow[6]
  packageId = resultRow[7]
  queueName = resultRow[8]
  acceptedAt = resultRow[9]
  receiptSourceManager = resultRow[10]
  duplicateText = resultRow[11]
  if okText = "1" then do
    receipt = .QueueTransferReceipt~new(transferId, packageId, queueName, acceptedAt, receiptSourceManager, duplicateText = "1")
    ignore = endpoint~noteSuccessInternal(authority)
    return .QueueOperationResult~success(receipt, detail)
  end
  ignore = endpoint~noteFailureInternal(code || ":" || detail, authority)
  return .QueueOperationResult~failure(code, detail)

::method probeEndpoint private
  expose framer authority
  use strict arg endpoint, sourceManager, remoteManager, remoteChannel, principal
  ignore = endpoint~noteHealthAttemptInternal(authority)
  sessionResult = self~openAuthenticatedSession(endpoint, sourceManager, remoteManager~string, remoteChannel, principal)
  if \sessionResult~ok then do
    ignore = endpoint~noteHealthFailureInternal(sessionResult~code || ":" || sessionResult~detail, authority)
    return sessionResult
  end
  session = sessionResult~value
  connection = session~connection
  plaintextFrame = .QueueRecordCodec~encode("PROBE", .array~of(.QueueSocketTransportBuild~PROTOCOL))
  probeFrame = session~crypto~seal("C2S", plaintextFrame)
  sendResult = framer~sendFrame(connection, probeFrame)
  if \sendResult~ok then return self~healthFailure(endpoint, connection, sendResult~code || ":" || sendResult~detail)
  healthFrameResult = framer~receiveFrame(connection)
  if \healthFrameResult~ok then return self~healthFailure(endpoint, connection, healthFrameResult~code || ":" || healthFrameResult~detail)
  ignore = connection~close
  openResult = session~crypto~open("S2C", healthFrameResult~value)
  if \openResult~ok then do
    ignore = endpoint~noteHealthFailureInternal(openResult~code, authority)
    return .QueueOperationResult~failure(openResult~code, openResult~detail)
  end
  health = .QueueRecordCodec~decode(openResult~value)
  if health == .nil | health~items \= 4 | health[1] \= "HEALTH" | health[2] \= .QueueSocketTransportBuild~PROTOCOL then do
    ignore = endpoint~noteHealthFailureInternal("HEALTH_INVALID", authority)
    return .QueueOperationResult~failure("TRANSPORT_PROTOCOL_ERROR", "HEALTH_INVALID")
  end
  statusText = health[3]
  serverTimestamp = health[4]
  if statusText \= "OK" then do
    ignore = endpoint~noteHealthFailureInternal("HEALTH_STATUS:" || statusText, authority)
    return .QueueOperationResult~failure("REMOTE_HEALTH_FAILED", statusText)
  end
  ignore = endpoint~noteHealthSuccessInternal(authority)
  return .QueueOperationResult~success(endpoint, "server_time=" || serverTimestamp || ";endpoint=" || endpoint~endpointId)

::method openAuthenticatedSession private
  expose nonceSource framer authority
  use strict arg endpoint, sourceManager, destinationManager, remoteChannel, principal
  connected = .QueueSocketConnector~connect(endpoint~host, endpoint~port, endpoint~connectTimeoutMs)
  if \connected~ok then return .QueueOperationResult~failure("REMOTE_MANAGER_UNAVAILABLE", connected~code || ":" || connected~detail)
  connection = connected~value
  keyId = endpoint~keyId
  clientNonce = nonceSource~nextNonceHex
  helloText = .QueueSocketProtocol~helloText(sourceManager, destinationManager, remoteChannel, principal, keyId, clientNonce)
  helloMac = endpoint~macInternal(helloText, authority)
  helloFrame = .QueueRecordCodec~encode("HELLO", .array~of(.QueueSocketTransportBuild~PROTOCOL, sourceManager, destinationManager, remoteChannel, principal, keyId, clientNonce, helloMac))
  sendResult = framer~sendFrame(connection, helloFrame)
  if \sendResult~ok then return self~sessionFailure(connection, sendResult~code || ":" || sendResult~detail)
  challengeFrameResult = framer~receiveFrame(connection)
  if \challengeFrameResult~ok then return self~sessionFailure(connection, challengeFrameResult~code || ":" || challengeFrameResult~detail)
  challenge = .QueueRecordCodec~decode(challengeFrameResult~value)
  if challenge == .nil | challenge~items \= 4 | challenge[1] \= "CHALLENGE" | challenge[2] \= .QueueSocketTransportBuild~PROTOCOL then return self~sessionFailure(connection, "CHALLENGE_INVALID")
  serverNonce = challenge[3]
  challengeMac = challenge[4]
  challengeText = .QueueSocketProtocol~challengeText(sourceManager, destinationManager, remoteChannel, principal, keyId, clientNonce, serverNonce)
  if \endpoint~verifyInternal(challengeText, challengeMac, authority) then do
    ignore = connection~close
    return .QueueOperationResult~failure("SERVER_AUTHENTICATION_FAILED")
  end
  transcript = .QueueSocketSessionCrypto~transcript(sourceManager, destinationManager, remoteChannel, principal, keyId, clientNonce, serverNonce)
  sessionCrypto = endpoint~sessionCryptoInternal(transcript, authority)
  session = .QueueSocketAuthenticatedSession~new(endpoint, connection, sourceManager, destinationManager, remoteChannel, principal, keyId, clientNonce, serverNonce, sessionCrypto)
  return .QueueOperationResult~success(session)

::method sessionFailure private
  use strict arg connection, detail
  ignore = connection~close
  return .QueueOperationResult~failure("TRANSPORT_FAILURE", detail)

::method deliveryFailure private
  expose authority
  use strict arg endpoint, connection, detail
  ignore = connection~close
  ignore = endpoint~noteFailureInternal(detail, authority)
  return .QueueOperationResult~failure("TRANSPORT_FAILURE", detail)

::method healthFailure private
  expose authority
  use strict arg endpoint, connection, detail
  ignore = connection~close
  ignore = endpoint~noteHealthFailureInternal(detail, authority)
  return .QueueOperationResult~failure("TRANSPORT_FAILURE", detail)

::class QueueSocketListener subclass AlchemyObject public
::attribute managerName get
::attribute bindHost get
::attribute port get
::attribute connectionCount get
::attribute authenticatedCount get
::attribute rejectedCount get
::attribute acceptedCount get
::attribute probeCount get
::attribute ipRejectedCount get
::attribute lastPeerAddress get
::attribute lastError get
::attribute framer get

::method init
  expose managerName bindHost port channelFabric payloadCodec nonceSource framer peers trustedSourceIps listenSocket connectionCount authenticatedCount rejectedCount acceptedCount probeCount ipRejectedCount lastPeerAddress lastError authority
  use strict arg managerName, bindHost, port, channelFabric, payloadCodec = .nil, nonceSource = .nil, framer = .nil
  managerName = managerName~string~strip
  bindHost = bindHost~string~strip
  if managerName = "" | bindHost = "" then raise syntax 88.900 array("Queue socket listener identity fields must not be empty")
  if \datatype(port, "W") | port < 0 | port > 65535 then raise syntax 88.900 array("Queue socket listener port is invalid")
  port = port
  if channelFabric == .nil then raise syntax 88.900 array("Queue socket listener requires a channel fabric")
  channelFabric = channelFabric
  if payloadCodec == .nil then payloadCodec = channelFabric~queueManager~payloadCodec
  payloadCodec = payloadCodec
  if payloadCodec~hasMethod("typeRegistry") then ignore = payloadCodec~typeRegistry~register(.QueueTransmissionEnvelope~PERSISTENT_TYPE, .QueueTransmissionEnvelopeFactory~new)
  if nonceSource == .nil then nonceSource = .QueueSocketNonceSource~new
  nonceSource = nonceSource
  if framer == .nil then framer = .QueueSocketFramer~new
  framer = framer
  peers = .table~new
  trustedSourceIps = .table~new
  listenSocket = .nil
  connectionCount = 0
  authenticatedCount = 0
  rejectedCount = 0
  acceptedCount = 0
  probeCount = 0
  ipRejectedCount = 0
  lastPeerAddress = ""
  lastError = ""
  authority = .QueueSocketTransportAuthority~new

  limitations = .array~of("Listener admits exact configured source IPs only", "Transport confidentiality has no forward secrecy because it uses a pre-shared transport key", "Receiver semantics remain at-least-once transport with idempotent receiver insertion")
  meta = .QueueFabricAlchemyMetadata~standard("Encrypted authenticated socket listener and receiver ingress boundary", "queue.socket.listener/0.9-dev6", limitations)
  self~initAlchemy(meta)
  self~registerStateVariable("managerName", "PUBLIC", "listener queue-manager identity")
  self~registerStateVariable("bindHost", "INTERNAL", "listener bind host")
  self~registerStateVariable("port", "CUSTOMER", "listener TCP port")
  self~registerStateVariable("connectionCount", "CUSTOMER", "accepted TCP connection attempts")
  self~registerStateVariable("authenticatedCount", "CUSTOMER", "authenticated sessions")
  self~registerStateVariable("rejectedCount", "CUSTOMER", "rejected sessions")
  self~registerStateVariable("acceptedCount", "CUSTOMER", "accepted authenticated operations")
  self~registerStateVariable("probeCount", "CUSTOMER", "authenticated health probes")
  self~registerStateVariable("ipRejectedCount", "CUSTOMER", "connections rejected by source-IP admission")
  self~registerStateVariable("lastPeerAddress", "INTERNAL", "latest accepted socket peer address")
  self~registerStateVariable("lastError", "INTERNAL", "latest listener error")
  self~registerMethodContract("START", "Start bounded authenticated socket listener", .array~of("BACKLOG"), "BOOLEAN", .false)
  self~registerMethodContract("STOP", "Stop listener and wake blocked accept", .array~new, "BOOLEAN", .false)
  self~registerMethodContract("SERVEONE", "Accept and process one authenticated connection", .array~new, "QUEUEOPERATIONRESULT", .false)
  self~describeMethodPolicy("START", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("STOP", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("SERVEONE", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~recordRelationship("CHANNEL_FABRIC", channelFabric, "authenticated receiver-channel ingress", "INTERNAL")
  self~recordRelationship("PAYLOAD_CODEC", payloadCodec, "authenticated graph payload boundary", "INTERNAL")
  self~recordRelationship("FRAMER", framer, "bounded transport frame codec", "INTERNAL")

::method trustPeer
  expose peers authority
  use strict arg sourceManager, principal, keyId, keyHex, allowedIpAddresses
  peer = .QueueSocketPeer~new(sourceManager, principal, keyId, keyHex, allowedIpAddresses, authority)
  peers[self~peerKey(sourceManager, principal, keyId)] = peer
  self~rebuildTrustedSourceIps
  return peer

::method rebuildTrustedSourceIps private
  expose peers trustedSourceIps
  trustedSourceIps = .table~new
  do peerKeyValue over peers
    peer = peers[peerKeyValue]
    do ip over peer~allowedIpAddresses
      trustedSourceIps[ip] = .true
    end
  end
  return trustedSourceIps~items

::method start
  expose bindHost port listenSocket lastError trustedSourceIps
  use strict arg backlog = 16
  if listenSocket \== .nil then return .true
  if trustedSourceIps~items = 0 then do
    lastError = "SOURCE_IP_ALLOWLIST_EMPTY"
    return .false
  end
  socketObject = .Socket~new("AF_INET", "SOCK_STREAM", 0)
  if socketObject~errno \= 0 then do
    lastError = "SOCKET_CREATE_FAILED:" || socketObject~errno
    return .false
  end
  ignore = socketObject~setOption("SO_REUSEADDR", 1)
  address = .InetAddress~new(bindHost, port)
  if socketObject~bind(address) = -1 then do
    lastError = "BIND_FAILED:" || socketObject~errno
    ignore = socketObject~close
    return .false
  end
  if socketObject~listen(backlog) = -1 then do
    lastError = "LISTEN_FAILED:" || socketObject~errno
    ignore = socketObject~close
    return .false
  end
  actualAddress = socketObject~getSockName
  if actualAddress \== .nil then port = actualAddress~port
  listenSocket = socketObject
  lastError = ""
  return .true

::method stop
  expose listenSocket
  use strict arg
  if listenSocket == .nil then return .true
  ignore = listenSocket~close
  listenSocket = .nil
  return .true

::method serveOne
  expose listenSocket connectionCount authenticatedCount rejectedCount acceptedCount ipRejectedCount lastPeerAddress lastError trustedSourceIps
  use strict arg
  if listenSocket == .nil then do
    if \self~start then return .QueueOperationResult~failure("LISTENER_START_FAILED", lastError)
  end
  acceptedSocket = listenSocket~accept
  if acceptedSocket == .nil then do
    lastError = "ACCEPT_FAILED"
    rejectedCount += 1
    return .QueueOperationResult~failure("ACCEPT_FAILED")
  end
  connectionCount += 1
  peerAddress = acceptedSocket~getPeerName
  if peerAddress == .nil then do
    ignore = acceptedSocket~close
    rejectedCount += 1
    ipRejectedCount += 1
    lastError = "PEER_ADDRESS_UNAVAILABLE"
    return .QueueOperationResult~failure("SOURCE_IP_REJECTED", lastError)
  end
  sourceIp = peerAddress~address~string~strip
  lastPeerAddress = sourceIp || ":" || peerAddress~port
  if sourceIp = "" | \trustedSourceIps~hasIndex(sourceIp) then do
    ignore = acceptedSocket~close
    rejectedCount += 1
    ipRejectedCount += 1
    lastError = "SOURCE_IP_NOT_ALLOWED:" || sourceIp
    return .QueueOperationResult~failure("SOURCE_IP_REJECTED", sourceIp)
  end
  connection = .StreamSocket~new(acceptedSocket)
  handleResult = self~handleConnection(connection, sourceIp)
  ignore = connection~close
  if handleResult~ok then acceptedCount += 1
  else rejectedCount += 1
  return handleResult

::method handleConnection private
  expose managerName channelFabric payloadCodec nonceSource framer peers authenticatedCount lastError authority
  use strict arg connection, sourceIp
  helloFrameResult = framer~receiveFrame(connection)
  if \helloFrameResult~ok then return self~reject(helloFrameResult~code || ":" || helloFrameResult~detail)
  hello = .QueueRecordCodec~decode(helloFrameResult~value)
  if hello == .nil | hello~items \= 9 | hello[1] \= "HELLO" | hello[2] \= .QueueSocketTransportBuild~PROTOCOL then return self~reject("HELLO_INVALID")
  sourceManager = hello[3]
  destinationManager = hello[4]
  receiverChannel = hello[5]
  principal = hello[6]
  keyId = hello[7]
  clientNonce = hello[8]
  helloMac = hello[9]
  if destinationManager \= managerName then return self~reject("DESTINATION_MANAGER_MISMATCH")
  peer = peers[self~peerKey(sourceManager, principal, keyId)]
  if peer == .nil then return self~reject("PEER_NOT_TRUSTED")
  if \peer~allowsIpInternal(sourceIp, authority) then return self~reject("PEER_IP_BINDING_MISMATCH:" || sourceIp)
  helloText = .QueueSocketProtocol~helloText(sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce)
  if \peer~verifyInternal(helloText, helloMac, authority) then return self~reject("HELLO_AUTHENTICATION_FAILED")
  authenticatedCount += 1

  serverNonce = nonceSource~nextNonceHex
  challengeText = .QueueSocketProtocol~challengeText(sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce)
  challengeMac = peer~macInternal(challengeText, authority)
  challengeFrame = .QueueRecordCodec~encode("CHALLENGE", .array~of(.QueueSocketTransportBuild~PROTOCOL, serverNonce, challengeMac))
  sendResult = framer~sendFrame(connection, challengeFrame)
  if \sendResult~ok then return self~reject(sendResult~code || ":" || sendResult~detail)

  transcript = .QueueSocketSessionCrypto~transcript(sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce)
  sessionCrypto = peer~sessionCryptoInternal(transcript, authority)
  commandFrameResult = framer~receiveFrame(connection)
  if \commandFrameResult~ok then return self~reject(commandFrameResult~code || ":" || commandFrameResult~detail)
  openResult = sessionCrypto~open("C2S", commandFrameResult~value)
  if \openResult~ok then return self~reject(openResult~code || ":" || openResult~detail)
  command = .QueueRecordCodec~decode(openResult~value)
  if command == .nil | command~items < 2 then return self~reject("TRANSPORT_COMMAND_INVALID")
  if command[1] = "PROBE" then do
    if command~items \= 2 | command[2] \= .QueueSocketTransportBuild~PROTOCOL then return self~reject("PROBE_INVALID")
    return self~sendHealth(connection, sessionCrypto)
  end
  if command~items \= 3 | command[1] \= "DELIVER" | command[2] \= .QueueSocketTransportBuild~PROTOCOL then return self~reject("DELIVERY_INVALID")
  encodedEnvelope = command[3]
  signal on syntax name envelopeDecodeFailure
  envelope = payloadCodec~decode(encodedEnvelope)
  signal off syntax
  receiveResult = channelFabric~receiveEnvelope(envelope, receiverChannel, principal)
  return self~sendResult(connection, sessionCrypto, receiveResult)
envelopeDecodeFailure:
  signal off syntax
  return self~reject("ENVELOPE_DECODE_FAILED")

::method sendHealth private
  expose framer probeCount
  use strict arg connection, sessionCrypto
  statusText = "OK"
  serverTimestamp = .QueueClock~timestamp
  plaintextFrame = .QueueRecordCodec~encode("HEALTH", .array~of(.QueueSocketTransportBuild~PROTOCOL, statusText, serverTimestamp))
  healthFrame = sessionCrypto~seal("S2C", plaintextFrame)
  sendResult = framer~sendFrame(connection, healthFrame)
  if \sendResult~ok then return self~reject(sendResult~code || ":" || sendResult~detail)
  probeCount += 1
  return .QueueOperationResult~success(.nil, "HEALTH_SENT")

::method sendResult private
  expose framer
  use strict arg connection, sessionCrypto, receiveResult
  if receiveResult~ok then okText = "1"
  else okText = "0"
  code = receiveResult~code
  detail = receiveResult~detail
  transferId = ""
  packageId = ""
  queueName = ""
  acceptedAt = ""
  receiptSourceManager = ""
  duplicateText = "0"
  receipt = receiveResult~value
  if receipt \== .nil then do
    if receipt~hasMethod("TRANSFERID") then transferId = receipt~transferId
    if receipt~hasMethod("PACKAGEID") then packageId = receipt~packageId
    if receipt~hasMethod("QUEUENAME") then queueName = receipt~queueName
    if receipt~hasMethod("ACCEPTEDAT") then acceptedAt = receipt~acceptedAt
    if receipt~hasMethod("SOURCEMANAGER") then receiptSourceManager = receipt~sourceManager
    if receipt~hasMethod("DUPLICATE") then do
      if receipt~duplicate then duplicateText = "1"
    end
  end
  plaintextFrame = .QueueRecordCodec~encode("RESULT", .array~of(.QueueSocketTransportBuild~PROTOCOL, okText, code, detail, transferId, packageId, queueName, acceptedAt, receiptSourceManager, duplicateText))
  resultFrame = sessionCrypto~seal("S2C", plaintextFrame)
  sendResult = framer~sendFrame(connection, resultFrame)
  if \sendResult~ok then return self~reject(sendResult~code || ":" || sendResult~detail)
  return .QueueOperationResult~success(receiveResult, "REQUEST_HANDLED")

::method reject private
  expose lastError
  use strict arg detail
  lastError = detail~string
  return .QueueOperationResult~failure("TRANSPORT_REJECTED", detail)

::method peerKey private
  use strict arg sourceManager, principal, keyId
  return sourceManager~string~translate || "|" || principal~string || "|" || keyId~string

::requires "ObjectQueueChannels.cls"
::requires "ObjectQueueCrypto.cls"
::requires "socket.cls"
::requires "streamsocket.cls"
::requires "AlchemyObject.cls"
