failures = 0

audit = .ServiceAudit~new
host = .ServiceHostFixture~new(audit)
endpoint = .ServiceEndpointFixture~new(audit)
broker = .ServiceBrokerFixture~new(audit)
sealer = .ServiceEvidenceSealer~new
authority = .ServiceCapabilityAuthority~new
service = .TerminalBrokerServiceLifecycle~new(host, endpoint, broker, sealer, authority)

call assertTrue service~isA(.AlchemyObject), "service lifecycle inherits AlchemyObject"
surface = service~checkSurfaceContract
if \surface~ok then say "SERVICE SURFACE:" surface~code surface~message
call assertTrue surface~ok, "service lifecycle Alchemy surface contract"
call assertEq service~state, "STOPPED", "service starts stopped"

launched = service~launch(4, 12)
call assertTrue launched~ok, "service launch"
call assertEq service~state, "RUNNING", "service running"
call assertEq launched~value~port, 32123, "service status exposes scalar listener port"

/* Drain order is the core v0.17 boundary: listener/worker drain completes
 * before remote capabilities are quiesced.  The terminal broker remains open. */
drained = service~drain(5000, "TEST_DRAIN")
call assertTrue drained~ok, "service drain"
call assertEq service~state, "QUIESCED", "service quiesced after drain"
call assertEq audit~text, "LAUNCH|REQUEST_DRAIN|AWAIT_DRAIN|QUIESCE", "drain and quiesce ordering"
call assertEq endpoint~endpointState, "QUIESCED", "endpoint quiesced"
call assertEq broker~closeCount, 0, "drain does not close terminal broker"
call assertEq broker~status~state, "OPEN", "terminal retained after service drain"

full = service~sealedIntrospection("FULL", .nil)~payload["state"]
call assertMissing full, "SOCKETHOST", "service introspection cannot delegate socket host"
call assertMissing full, "ENDPOINT", "service introspection cannot delegate protocol endpoint"
call assertMissing full, "BROKER", "service introspection cannot delegate terminal broker"
call assertMissing full, "ALCHEMYSEALER", "service introspection cannot delegate sealer"
call assertMissing full, "ALCHEMYCAPABILITYAUTHORITY", "service introspection cannot delegate capability authority"
call assertEq full["STATE"], "QUIESCED", "safe service state remains inspectable"
call assertEq full["DRAINREASON"], "TEST_DRAIN", "safe drain reason remains inspectable"

/* The coordinator does not turn quiesce into implicit host signoff.  A bad
 * local signoff request is surfaced while the retained broker stays open. */
signoffRefusal = service~orderlyIBMISignoff(.nil, .nil)
call assertTrue \signoffRefusal~ok, "invalid local signoff request is refused"
call assertEq signoffRefusal~code, "BROKER_SIGNOFF_CATALOG_REQUIRED", "signoff delegation preserves refusal code"
call assertEq service~state, "QUIESCED", "signoff refusal leaves service quiesced"
call assertEq broker~closeCount, 0, "signoff refusal leaves terminal broker open"

restart = service~launch(4, 12)
call assertTrue \restart~ok, "quiesced service cannot silently restart"
call assertEq restart~code, "TERMINAL_SERVICE_NOT_RESTARTABLE", "restart refusal code"

/* A socket drain failure must not revoke protocol capabilities out of order. */
audit2 = .ServiceAudit~new
host2 = .ServiceHostFixture~new(audit2)
host2~failDrain(.true)
endpoint2 = .ServiceEndpointFixture~new(audit2)
broker2 = .ServiceBrokerFixture~new(audit2)
service2 = .TerminalBrokerServiceLifecycle~new(host2, endpoint2, broker2, sealer, authority)
call assertTrue service2~launch~ok, "failure fixture launch"
failedDrain = service2~drain(50, "FAIL_DRAIN")
call assertTrue \failedDrain~ok, "failed socket drain surfaces failure"
call assertEq failedDrain~code, "FIXTURE_DRAIN_TIMEOUT", "drain failure code preserved"
call assertEq service2~state, "ERROR", "service marks drain failure"
call assertEq endpoint2~endpointState, "OPEN", "endpoint remains open when socket drain fails"
call assertEq audit2~text, "LAUNCH|REQUEST_DRAIN|AWAIT_DRAIN", "quiesce is not called after failed drain"
call assertEq broker2~closeCount, 0, "failed drain does not close terminal broker"

if failures > 0 then do
  say "FAIL test_terminal_broker_service" failures
  exit 1
end
say "PASS test_terminal_broker_service"
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

::class ServiceAudit
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

::class ServiceSocketStatusFixture
::attribute port get
::attribute activeConnections get
::attribute peakConnections get
::method init
  expose port activeConnections peakConnections
  use strict arg portArg, activeArg, peakArg
  port = portArg
  activeConnections = activeArg
  peakConnections = peakArg

::class ServiceHostFixture
::method init
  expose audit running failDrainFlag
  use strict arg auditArg
  audit = auditArg
  running = .false
  failDrainFlag = .false
::method failDrain
  expose failDrainFlag
  use strict arg valueArg
  failDrainFlag = valueArg
::method launchService
  expose audit running
  use strict arg maxArg = 16, backlogArg = 64
  audit~add("LAUNCH")
  running = .true
  return .TerminalResult~success(32123)
::method requestDrain
  expose audit
  use strict arg reasonArg = "DRAIN"
  audit~add("REQUEST_DRAIN")
  return .TerminalResult~success(.true)
::method awaitDrain
  expose audit running failDrainFlag
  use strict arg timeoutArg = 30000
  audit~add("AWAIT_DRAIN")
  if failDrainFlag then return .TerminalResult~failure("FIXTURE_DRAIN_TIMEOUT", timeoutArg)
  running = .false
  return .TerminalResult~success(.true)
::method serviceStatus
  expose running
  active = 0
  peak = 0
  if running then peak = 1
  return .ServiceSocketStatusFixture~new(32123, active, peak)

::class ServiceEndpointFixture
::attribute endpointState get
::method init
  expose audit endpointState
  use strict arg auditArg
  audit = auditArg
  endpointState = "OPEN"
::method quiesce
  expose audit endpointState
  use strict arg reasonArg = "DRAIN"
  audit~add("QUIESCE")
  endpointState = "QUIESCED"
  return .TerminalResult~success(.true)

::class ServiceBrokerStatusFixture
::attribute state get
::method init
  expose state
  use strict arg stateArg
  state = stateArg~string

::class ServiceBrokerFixture
::attribute attachedClientCount get
::attribute controlActive get
::attribute closeCount get
::method init
  expose audit attachedClientCount controlActive closeCount state
  use strict arg auditArg
  audit = auditArg
  attachedClientCount = 0
  controlActive = .false
  closeCount = 0
  state = "OPEN"
::method status
  expose state
  return .ServiceBrokerStatusFixture~new(state)
::method attachClient
  use strict arg principalArg
  return .TerminalResult~failure("FIXTURE_NOT_USED")
::method pumpOnce
  use strict arg timeoutArg, byteLimitArg
  return .TerminalResult~failure("FIXTURE_NOT_USED")
::method close
  expose closeCount state audit
  closeCount += 1
  state = "CLOSED"
  audit~add("BROKER_CLOSE")
  return .TerminalResult~success(.true)

::class ServiceEvidenceEnvelope
::attribute payload get
::method init
  expose payload
  use strict arg payloadArg
  payload = payloadArg
::class ServiceEvidenceSealer
::method seal
  use strict arg producer, payload
  return .ServiceEvidenceEnvelope~new(payload)
::class ServiceCapabilityAuthority
::method verify
  use arg capability, objectId, operation, purpose, requireActive = .true
  return .true

::requires "TerminalBrokerService.cls"
