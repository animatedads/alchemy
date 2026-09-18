failures = 0

audit = .OpsAudit~new
host = .OpsHost~new(audit)
endpoint = .OpsEndpoint~new(audit)
broker = .OpsBroker~new(audit)
service = .TerminalBrokerServiceLifecycle~new(host, endpoint, broker)
sealer = .OpsEvidenceSealer~new
authority = .OpsCapabilityAuthority~new
supervisor = .TerminalBrokerServiceSupervisor~new(service, sealer, authority)

call assertTrue supervisor~isA(.AlchemyObject), "supervisor inherits AlchemyObject"
surface = supervisor~checkSurfaceContract
if \surface~ok then say "OPERATIONS SURFACE:" surface~code surface~message
call assertTrue surface~ok, "operations Alchemy surface contract"

initial = supervisor~health
call assertEq initial~health, "STOPPED", "initial health stopped"
call assertTrue \initial~ready, "initial health not ready"
call assertTrue \initial~accepting, "initial health not accepting"
call assertEq initial~serviceGeneration, 0, "initial service generation"

started = supervisor~start(8, 32)
call assertTrue started~ok, "controlled start succeeds"
call assertEq supervisor~startCount, 1, "successful start counted"
health = supervisor~health
call assertEq health~health, "HEALTHY", "running service healthy"
call assertTrue health~ready, "running service ready"
call assertTrue health~accepting, "running service accepting"
call assertEq health~listenerPort, 32123, "listener port surfaced"
call assertEq health~serviceGeneration, 1, "service generation surfaced"
call assertEq health~workerLimit, 8, "worker limit surfaced"
call assertEq health~brokerClientCount, 2, "broker clients surfaced"
call assertTrue health~brokerControlActive, "broker controller evidence surfaced"
call assertEq health~brokerControllerPrincipal, "AI-A", "controller principal surfaced"
call assertEq health~socketLastError, "", "socket operational error surface starts empty"
call assertEq health~summary, "health=HEALTHY;lifecycle=RUNNING;socket=RUNNING;listener=LISTENING;protocol=OPEN;broker=OPEN;active=1", "bounded health summary"
call assertTrue supervisor~requireReady~ok, "requireReady succeeds while healthy"

/* A cross-layer disagreement is DEGRADED rather than silently reported ready. */
endpoint~setState("QUIESCED")
degraded = supervisor~health
call assertEq degraded~health, "DEGRADED", "unexpected endpoint quiesce degrades service"
call assertTrue \degraded~ready, "degraded service not ready"
required = supervisor~requireReady
call assertTrue \required~ok, "requireReady fails closed"
call assertEq required~code, "TERMINAL_SERVICE_NOT_READY", "readiness failure code"
endpoint~setState("OPEN")

shutdown = supervisor~shutdown(5000, "OPS_TEST")
call assertTrue shutdown~ok, "controlled shutdown succeeds"
call assertEq supervisor~shutdownCount, 1, "successful shutdown counted"
quiesced = supervisor~health
call assertEq quiesced~health, "QUIESCED", "shutdown health quiesced"
call assertTrue \quiesced~ready, "quiesced service not ready"
call assertEq audit~text, "LAUNCH|REQUEST_DRAIN|AWAIT_DRAIN|QUIESCE", "controlled shutdown preserves strict order"
call assertEq broker~status~state, "OPEN", "shutdown retains terminal broker"
call assertEq broker~closeCount, 0, "shutdown never becomes implicit terminal close"

again = supervisor~shutdown(5000, "OPS_TEST_AGAIN")
call assertTrue again~ok, "quiesced shutdown is idempotent"
call assertEq supervisor~shutdownCount, 1, "idempotent shutdown not double counted"

restart = supervisor~start(8, 32)
call assertTrue \restart~ok, "quiesced supervisor cannot restart same lifecycle"
call assertEq restart~code, "TERMINAL_SUPERVISOR_START_REFUSED", "restart refusal code"

full = supervisor~sealedIntrospection("FULL", .nil)~payload["state"]
call assertMissing full, "LIFECYCLE", "supervisor introspection cannot delegate lifecycle authority"
call assertMissing full, "ALCHEMYSEALER", "supervisor introspection cannot delegate sealer"
call assertMissing full, "ALCHEMYCAPABILITYAUTHORITY", "supervisor introspection cannot delegate capability authority"
call assertEq full["STATE"], "QUIESCED", "safe supervisor state remains inspectable"
call assertEq full["STARTCOUNT"], 1, "safe start count remains inspectable"
call assertEq full["SHUTDOWNCOUNT"], 1, "safe shutdown count remains inspectable"

/* Launch failure is bounded and reflected in supervisor evidence. */
audit2 = .OpsAudit~new
host2 = .OpsHost~new(audit2)
host2~failLaunch(.true)
service2 = .TerminalBrokerServiceLifecycle~new(host2, .OpsEndpoint~new(audit2), .OpsBroker~new(audit2))
supervisor2 = .TerminalBrokerServiceSupervisor~new(service2, sealer, authority)
failed = supervisor2~start
call assertTrue \failed~ok, "launch failure surfaces"
call assertEq failed~code, "OPS_LAUNCH_FAILED", "launch failure code preserved"
failedHealth = supervisor2~health
call assertEq failedHealth~health, "ERROR", "failed lifecycle health is error"
call assertTrue failedHealth~lastError~pos("OPS_LAUNCH_FAILED") > 0, "failed health retains bounded error"

if failures > 0 then do
  say "FAIL test_terminal_broker_operations" failures
  exit 1
end
say "PASS test_terminal_broker_operations"
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

::class OpsAudit
::method init
  expose events
  events = .array~new
::method add
  expose events
  use strict arg eventArg
  events~append(eventArg~string)
::method text
  expose events
  text = ""
  do event over events
    if text \== "" then text ||= "|"
    text ||= event
  end
  return text

::class OpsSocketStatus
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
::method init
  expose state port generation workerLimit acceptorActive activeConnections peakConnections completedConnections totalConnections authenticatedConnections rejectedConnections requestCount
  use strict arg stateArg, generationArg, workerArg
  state = stateArg
  port = 32123
  generation = generationArg
  workerLimit = workerArg
  acceptorActive = stateArg == "RUNNING"
  if stateArg == "RUNNING" then activeConnections = 1
  else activeConnections = 0
  peakConnections = 2
  completedConnections = 3
  totalConnections = 5
  authenticatedConnections = 4
  rejectedConnections = 1
  requestCount = 9

::class OpsHost
::attribute state get
::method init
  expose audit running generation workerLimit failLaunchFlag state
  use strict arg auditArg
  audit = auditArg
  running = .false
  generation = 0
  workerLimit = 0
  failLaunchFlag = .false
  state = "STOPPED"
::method failLaunch
  expose failLaunchFlag
  use strict arg flagArg
  failLaunchFlag = flagArg == .true
::method launchService
  expose audit running generation workerLimit failLaunchFlag state
  use strict arg maxArg = 16, backlogArg = 64
  audit~add("LAUNCH")
  if failLaunchFlag then return .TerminalResult~failure("OPS_LAUNCH_FAILED", "fixture")
  running = .true
  state = "LISTENING"
  generation += 1
  workerLimit = maxArg
  return .TerminalResult~success(32123)
::method requestDrain
  expose audit
  use strict arg reasonArg = "DRAIN"
  audit~add("REQUEST_DRAIN")
  return .TerminalResult~success(.true)
::method awaitDrain
  expose audit running state
  use strict arg timeoutArg = 30000
  audit~add("AWAIT_DRAIN")
  running = .false
  state = "STOPPED"
  return .TerminalResult~success(.true)
::method serviceStatus
  expose running generation workerLimit
  if running then state = "RUNNING"
  else if generation = 0 then state = "STOPPED"
  else state = "DRAINED"
  return .OpsSocketStatus~new(state, generation, workerLimit)

::class OpsEndpoint
::attribute endpointState get
::method init
  expose audit endpointState
  use strict arg auditArg
  audit = auditArg
  endpointState = "OPEN"
::method setState
  expose endpointState
  use strict arg stateArg
  endpointState = stateArg~string
::method quiesce
  expose audit endpointState
  use strict arg reasonArg = "DRAIN"
  audit~add("QUIESCE")
  endpointState = "QUIESCED"
  return .TerminalResult~success(.true)

::class OpsBrokerStatus
::attribute state get
::attribute clientCount get
::attribute maxClients get
::attribute controlActive get
::attribute activeControllerPrincipal get
::method init
  expose state clientCount maxClients controlActive activeControllerPrincipal
  use strict arg stateArg
  state = stateArg
  clientCount = 2
  maxClients = 16
  controlActive = .true
  activeControllerPrincipal = "AI-A"

::class OpsBroker
::attribute attachedClientCount get
::attribute controlActive get
::attribute closeCount get
::method init
  expose audit attachedClientCount controlActive closeCount state
  use strict arg auditArg
  audit = auditArg
  attachedClientCount = 2
  controlActive = .true
  closeCount = 0
  state = "OPEN"
::method status
  expose state
  return .OpsBrokerStatus~new(state)
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

::class OpsEvidenceEnvelope
::attribute payload get
::method init
  expose payload
  use strict arg payloadArg
  payload = payloadArg

::class OpsEvidenceSealer
::method seal
  use strict arg producer, payload
  return .OpsEvidenceEnvelope~new(payload)

::class OpsCapabilityAuthority
::method verify
  use arg capability, objectId, operation, purpose, requireActive = .true
  return .true

::requires "TerminalBrokerOperations.cls"
