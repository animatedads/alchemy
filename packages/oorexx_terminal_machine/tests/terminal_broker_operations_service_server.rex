parse arg portFile statusFile keyHex
endpoint = .OpsServiceEndpoint~new
broker = .OpsServiceBroker~new
host = .TerminalBrokerLocalSocketHost~new(endpoint, 0, 8, 262144, .nil, .nil, .nil, 30000)
if \host~trustPrincipal("AI_A", "k1", keyHex)~ok then exit 21
if \host~trustPrincipal("AI_B", "k1", keyHex)~ok then exit 22
lifecycle = .TerminalBrokerServiceLifecycle~new(host, endpoint, broker)
supervisor = .TerminalBrokerServiceSupervisor~new(lifecycle)
launched = supervisor~start(4, 16)
if \launched~ok then do
  call lineout statusFile, "launch_fail=" || launched~code || ":" || launched~detail
  call lineout statusFile
  exit 23
end
initial = supervisor~health
if \initial~ready then do
  call lineout statusFile, "ready_fail=" || initial~summary
  call lineout statusFile
  exit 24
end
call lineout portFile, initial~listenerPort
call lineout portFile

/* Both independently authenticated clients must be simultaneously live and
 * the operational health surface must observe that without owning sockets. */
do tick = 1 to 2000
  health = supervisor~health
  if health~peakConnections >= 2 then leave
  call SysSleep 0.01
end
health = supervisor~health
if health~peakConnections < 2 then do
  call lineout statusFile, "peak_fail=" || health~peakConnections
  call lineout statusFile
  exit 25
end
if \health~ready then do
  call lineout statusFile, "mid_health_fail=" || health~summary
  call lineout statusFile
  exit 26
end

/* r13196 debug SHA-512 is intentionally slow; this only bounds harness drain. */
drained = supervisor~shutdown(60000, "OPS_SERVICE_TEST_COMPLETE")
if \drained~ok then do
  call lineout statusFile, "drain_fail=" || drained~code || ":" || drained~detail
  call lineout statusFile
  exit 27
end
health = supervisor~health
status = "health=" || health~health || ";lifecycle=" || health~lifecycleState || ";socket=" || health~socketServiceState || ";listener=" || health~listenerState || ";generation=" || health~serviceGeneration || ";connections=" || health~totalConnections || ";active=" || health~activeConnections || ";peak=" || health~peakConnections || ";completed=" || health~completedConnections || ";authenticated=" || health~authenticatedConnections || ";rejected=" || health~rejectedConnections || ";requests=" || health~requestCount || ";protocol=" || health~protocolState || ";broker=" || health~brokerState || ";broker_close=" || broker~closeCount || ";endpoint_calls=" || endpoint~callCount || ";last_error=" || health~lastError || ";socket_last_error=" || health~socketLastError
call lineout statusFile, status
call lineout statusFile
exit 0

::class OpsServiceEndpoint
::attribute callCount get
::attribute endpointState get
::method init
  expose callCount endpointState
  callCount = 0
  endpointState = "OPEN"
::method handleFrame
  expose callCount
  use strict arg principalArg, frameArg
  callCount += 1
  return .TerminalBrokerFrameCodec~encode('{"ok":true}', 65536)~value
::method quiesce
  expose endpointState
  use strict arg reasonArg = "DRAIN"
  endpointState = "QUIESCED"
  return .TerminalResult~success(.true)

::class OpsServiceBrokerStatus
::attribute state get
::attribute clientCount get
::attribute maxClients get
::attribute controlActive get
::attribute activeControllerPrincipal get
::method init
  expose state clientCount maxClients controlActive activeControllerPrincipal
  use strict arg stateArg
  state = stateArg
  clientCount = 0
  maxClients = 16
  controlActive = .false
  activeControllerPrincipal = ""

::class OpsServiceBroker
::attribute attachedClientCount get
::attribute controlActive get
::attribute closeCount get
::method init
  expose attachedClientCount controlActive closeCount state
  attachedClientCount = 0
  controlActive = .false
  closeCount = 0
  state = "OPEN"
::method status
  expose state
  return .OpsServiceBrokerStatus~new(state)
::method attachClient
  use strict arg principalArg
  return .TerminalResult~failure("FIXTURE_NOT_USED")
::method pumpOnce
  use strict arg timeoutArg, byteLimitArg
  return .TerminalResult~failure("FIXTURE_NOT_USED")
::method close
  expose closeCount state
  closeCount += 1
  state = "CLOSED"
  return .TerminalResult~success(.true)

::requires "TerminalBrokerOperations.cls"
