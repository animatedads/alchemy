failures = 0

endpoint = .SocketUnitEndpoint~new
nonce = .SocketUnitNonce~new(copies("ab", 32))
sealer = .SocketUnitEvidenceSealer~new
authority = .SocketUnitCapabilityAuthority~new
host = .TerminalBrokerLocalSocketHost~new(endpoint, 0, 4, 8192, nonce, sealer, authority)

call assertTrue host~isA(.AlchemyObject), "local socket host inherits AlchemyObject"
surface = host~checkSurfaceContract
if \surface~ok then say "HOST SURFACE:" surface~code surface~message
call assertTrue surface~ok, "local socket host Alchemy surface contract"
call assertEq host~bindHost, "127.0.0.1", "host is fixed to IPv4 loopback"
call assertEq host~state, "STOPPED", "initial host state"
call assertEq host~maxRequestsPerConnection, 4, "request bound retained"
call assertEq host~socketTimeoutMilliseconds, 30000, "host socket timeout retained in milliseconds"

key = copies("44", 64)
trusted = host~trustPrincipal("AI_A", "k1", key)
call assertTrue trusted~ok, "principal trust installed"
duplicate = host~trustPrincipal("AI_A", "k1", key)
call assertTrue \duplicate~ok, "duplicate principal/key id denied"
call assertEq duplicate~code, "BROKER_SOCKET_PEER_EXISTS", "duplicate trust code"

full = host~sealedIntrospection("FULL", .nil)~payload["state"]
call assertMissing full, "ENDPOINT", "FULL state does not export endpoint"
call assertMissing full, "PEERS", "FULL state does not export peer table"
call assertMissing full, "NONCESOURCE", "FULL state does not export nonce source"
call assertMissing full, "FRAMER", "FULL state does not export framer"
call assertMissing full, "LISTENSOCKET", "FULL state does not export socket"
call assertMissing full, "AUTHORITY", "FULL state does not export transport authority"
call assertEq full["BINDHOST"], "127.0.0.1", "safe loopback bind evidence retained"
call assertEq full["SOCKETTIMEOUTMILLISECONDS"], 30000, "safe host timeout evidence retained"
call assertMissing full, "SERVICEAUTHORITY", "FULL state does not export persistent-service authority"

/* v0.17 service launch freezes the configured trust set, and an idle listener
 * can be drained without creating a terminal session or fake client. */
launched = host~launchService(2, 8)
call assertTrue launched~ok, "persistent socket service launches"
call assertEq host~serviceStatus~state, "RUNNING", "service reports running"
serveConflict = host~serveOne
call assertTrue \serveConflict~ok, "synchronous serveOne cannot steal persistent-service accepts"
call assertEq serveConflict~code, "BROKER_SOCKET_SERVICE_ACTIVE", "serveOne conflict code"
lateTrust = host~trustPrincipal("AI_B", "k1", key)
call assertTrue \lateTrust~ok, "trust changes blocked while service active"
call assertEq lateTrust~code, "BROKER_SOCKET_SERVICE_ACTIVE", "active-service trust code"
call assertTrue host~requestDrain("UNIT_DRAIN")~ok, "idle persistent service accepts drain"
drained = host~awaitDrain(2000)
call assertTrue drained~ok, "idle persistent service drains"
call assertEq host~serviceStatus~state, "DRAINED", "service reports drained"
call assertEq host~state, "STOPPED", "listener stopped after drain"

client = .TerminalBrokerLocalSocketClient~new(12345, "AI_A", "k1", key, 8192, nonce, sealer, authority)
call assertTrue client~isA(.AlchemyObject), "local socket client inherits AlchemyObject"
clientSurface = client~checkSurfaceContract
if \clientSurface~ok then say "CLIENT SURFACE:" clientSurface~code clientSurface~message
call assertTrue clientSurface~ok, "local socket client Alchemy surface contract"
clientFull = client~sealedIntrospection("FULL", .nil)~payload["state"]
call assertMissing clientFull, "KEYHEX", "FULL client state does not export HMAC key"
call assertMissing clientFull, "CLIENTNONCE", "FULL client state does not export client nonce"
call assertMissing clientFull, "SERVERNONCE", "FULL client state does not export server nonce"
call assertMissing clientFull, "CONNECTION", "FULL client state does not export socket"
call assertMissing clientFull, "FRAMER", "FULL client state does not export framer"
call assertEq clientFull["HOST"], "127.0.0.1", "safe client destination evidence retained"
call assertEq client~socketTimeoutMilliseconds, 30000, "client socket timeout retained in milliseconds"

/* Canonical authenticated texts bind connection nonces, sequence and exact
 * serialized broker frame.  A body change cannot preserve the MAC input. */
hello = .TerminalBrokerSocketProtocol~helloText("AI_A", "k1", copies("11",32))
hello2 = .TerminalBrokerSocketProtocol~helloText("AI_B", "k1", copies("11",32))
call assertTrue hello \== hello2, "principal is MAC-bound"
req1 = .TerminalBrokerSocketProtocol~requestText("AI_A", "k1", copies("11",32), copies("22",32), 1, "00000002{}")
req2 = .TerminalBrokerSocketProtocol~requestText("AI_A", "k1", copies("11",32), copies("22",32), 2, "00000002{}")
req3 = .TerminalBrokerSocketProtocol~requestText("AI_A", "k1", copies("11",32), copies("22",32), 1, "00000003{x}")
call assertTrue req1 \== req2, "sequence is MAC-bound"
call assertTrue req1 \== req3, "exact broker frame is MAC-bound"

/* A bug in an endpoint request handler must not strand the persistent service
 * worker count.  The worker converts an unexpected SYNTAX condition into a
 * bounded connection failure, closes that one socket, and remains drainable. */
explodingEndpoint = .SocketExplodingEndpoint~new
explodingHost = .TerminalBrokerLocalSocketHost~new(explodingEndpoint, 0, 2, 8192, nonce, sealer, authority, 5000)
call assertTrue explodingHost~trustPrincipal("AI_CRASH", "k1", key)~ok, "crash fixture trust installed"
explodingLaunch = explodingHost~launchService(2, 8)
call assertTrue explodingLaunch~ok, "crash fixture service launches"
if explodingLaunch~ok then do
  explodingClient = .TerminalBrokerLocalSocketClient~new(explodingHost~port, "AI_CRASH", "k1", key, 8192, nonce, sealer, authority, 5000)
  crashConnected = explodingClient~connect
  call assertTrue crashConnected~ok, "crash fixture client authenticates"
  if crashConnected~ok then do
    crashRequest = explodingClient~requestFrame("00000002{}")
    call assertTrue \crashRequest~ok, "endpoint exception terminates only its connection"
  end
  do tick = 1 to 500
    if explodingHost~activeConnectionCount = 0 then leave
    call SysSleep 0.01
  end
  call assertEq explodingHost~activeConnectionCount, 0, "endpoint exception cannot leak active worker count"
  call assertEq explodingHost~completedConnectionCount, 1, "failed worker counted complete"
  call assertTrue explodingHost~rejectedCount >= 1, "failed worker recorded as rejected"
  call assertTrue explodingHost~lastError~pos("BROKER_SOCKET_WORKER_FAILED") > 0, "worker failure retained as bounded evidence"
  call assertTrue explodingHost~requestDrain("CRASH_FIXTURE_DONE")~ok, "service remains drainable after endpoint exception"
  crashDrained = explodingHost~awaitDrain(5000)
  call assertTrue crashDrained~ok, "service drains after endpoint exception"
  if crashDrained~ok then call assertEq crashDrained~value~state, "DRAINED", "crash fixture reaches drained state"
end

if failures > 0 then do
  say "FAIL test_terminal_broker_socket" failures
  exit 1
end
say "PASS test_terminal_broker_socket"
exit 0

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return

assertMissing: procedure expose failures
  use arg state, key, label
  if \state~hasIndex(key) then return
  failures += 1
  say "ASSERT_MISSING FAIL:" label "key="key
  return


::class SocketUnitEvidenceEnvelope
::attribute payload get
::method init
  expose payload
  use strict arg payloadArg
  payload = payloadArg

::class SocketUnitEvidenceSealer
::method seal
  use strict arg producer, payload
  return .SocketUnitEvidenceEnvelope~new(payload)

::class SocketUnitCapabilityAuthority
::method verify
  use arg capability, objectId, operation, purpose, requireActive = .true
  return .true

::class SocketUnitEndpoint
::method handleFrame
  use strict arg principal, frame
  return frame

::class SocketExplodingEndpoint
::method handleFrame
  use strict arg principal, frame
  raise syntax 88.900 array("synthetic endpoint failure")

::class SocketUnitNonce
::method init
  expose nonce
  use strict arg nonceArg
  nonce = nonceArg~string
::method nextNonceHex
  expose nonce
  return nonce

::requires "TerminalBrokerSocket.cls"
