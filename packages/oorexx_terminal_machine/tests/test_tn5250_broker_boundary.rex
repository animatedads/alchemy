failures = 0

transport = .BrokerCountingTransport~new
live = .TN5250LiveSession~new("BROKER5250", "example.test", 992, "IBM-3179-2", "", "ADVANCE", transport)
owner = .TerminalSessionOwner~new(live, 4)
broker = .TerminalSessionBroker~new("TN5250-SERVICE", owner, 4)

call assertTrue live~ownershipClaimed, "persistent owner claims actual TN5250 live session"
call assertTrue broker~open~ok, "broker opens actual TN5250 through owner"
call assertEq transport~openCount, 1, "one TN5250 transport open"

/* Retaining the raw live session or public owner facade still cannot bypass the
 * private owner token merely because a broker is now layered above it. */
directPump = live~pumpOnce(0)
call assertTrue \directPump~ok, "direct TN5250 pump denied under broker"
call assertEq directPump~code, "SESSION_OWNERSHIP_REQUIRED", "raw live pump still owner-gated"
call assertEq transport~receiveCount, 0, "denied raw pump reads no bytes"
call assertTrue broker~pumpOnce(0)~ok, "broker service pump reaches live session through owner"
call assertEq transport~receiveCount, 1, "broker has one legitimate read pump path"

catalog = .KnownStateCatalog~new
call assertTrue broker~attachKnownStateCatalog(catalog, 8)~ok, "broker attaches semantic tracker inside owner"

attached = broker~attachClient("AI_A")
call assertTrue attached~ok, "attach broker client to actual TN5250"
client = attached~value
call assertEq transport~openCount, 1, "client attachment creates no TN5250 connection"
call assertEq client~knownStateStatus~value, "NO_MATCH", "broker client sees semantic tracker"
call assertTrue \client~hasMethod("PRESS"), "broker client has no AID path"
call assertTrue \client~hasMethod("BROKER"), "broker client has no broker getter"

/* Actual TN5250 control gate remains owner-token protected; broker reaches it
 * only through TerminalSessionOwner. */
auth = .BrokerLiveAdmission~new
directGate = live~enableControlGate(auth, "TERMINAL:SESSION:BROKER5250")
call assertTrue \directGate~ok, "raw live cannot enable control gate"
call assertEq directGate~code, "SESSION_OWNERSHIP_REQUIRED", "raw gate owner code"
call assertTrue broker~enableControlGate(auth, "TERMINAL:SESSION:BROKER5250")~ok, "broker enables actual TN5250 gate through owner"
reservation = .BrokerLiveReservation~new("AI_A", "TERMINAL:SESSION:BROKER5250")
control = client~requestControl(reservation, .array~of("AID"))
call assertTrue control~ok, "broker client acquires actual TN5250 controller"
ctl = control~value
call assertTrue broker~controlActive, "broker control active"
call assertTrue owner~controlActive, "owner control active"
call assertEq broker~activeControllerPrincipal, "AI_A", "broker controller principal"

directRevoke = live~revokeControl("BYPASS")
call assertTrue \directRevoke~ok, "raw live cannot revoke broker-owned control"
call assertEq directRevoke~code, "SESSION_OWNERSHIP_REQUIRED", "raw revoke owner code"
call assertTrue ctl~release("DONE")~ok, "broker controller releases through owner"
call assertTrue \broker~controlActive, "broker control cleared"
call assertTrue \owner~controlActive, "owner control cleared"

/* Generic broker close remains transport teardown, not permission to invent an
 * IBM i signoff action; this fixture sends no AID at all. */
directClose = live~close
call assertTrue \directClose~ok, "raw TN5250 close denied"
call assertEq directClose~code, "SESSION_OWNERSHIP_REQUIRED", "raw close owner code"
call assertTrue broker~close~ok, "broker closes actual TN5250 via owner"
call assertEq transport~closeCount, 1, "one TN5250 transport close"
call assertTrue \live~ownershipClaimed, "owner token released after broker close"
call assertTrue \client~active, "broker close invalidates client"

if failures > 0 then do
  say "FAIL test_tn5250_broker_boundary" failures
  exit 1
end
say "PASS test_tn5250_broker_boundary"
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

::class BrokerCountingTransport
::attribute openCount get
::attribute closeCount get
::attribute receiveCount get
::attribute sendCount get
::method init
  expose openCount closeCount receiveCount sendCount opened
  openCount = 0
  closeCount = 0
  receiveCount = 0
  sendCount = 0
  opened = .false
::method open
  expose openCount opened
  openCount += 1
  opened = .true
  return .TerminalResult~success(.true)
::method receiveBytesWait
  expose receiveCount opened
  use arg maximumArg = 16384, timeoutArg = 1
  if \opened then return .TerminalResult~failure("TRANSPORT_CLOSED")
  receiveCount += 1
  return .TerminalResult~failure("TRANSPORT_TIMEOUT", timeoutArg)
::method sendBytes
  expose sendCount opened
  use arg bytesArg
  if \opened then return .TerminalResult~failure("TRANSPORT_CLOSED")
  sendCount += 1
  return .TerminalResult~success(bytesArg~length)
::method close
  expose closeCount opened
  closeCount += 1
  opened = .false
  return .TerminalResult~success(.true)

::class BrokerLiveReservation
::attribute identity get
::attribute scope get
::method init
  expose identity scope
  use arg identityArg, scopeArg
  identity = identityArg~string
  scope = scopeArg~string

::class BrokerLiveAdmission
::method admit
  use arg reservation
  return .TerminalResult~success(reservation)

::requires "TerminalBroker.cls"
::requires "TN5250LiveSession.cls"
