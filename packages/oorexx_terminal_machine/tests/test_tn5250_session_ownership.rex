failures = 0

transport = .CountingLiveTransport~new
live = .TN5250LiveSession~new("OWN5250", "example.test", 992, "IBM-3179-2", "", "ADVANCE", transport)
owner = .TerminalSessionOwner~new(live, 4)
call assertTrue live~ownershipClaimed, "TN5250 session claimed by persistent owner"
intruder = .OwnershipToken~new
busyClaim = live~claimExclusiveOwner(intruder)
call assertTrue \busyClaim~ok, "second exact-object ownership claim denied"
call assertEq busyClaim~code, "SESSION_OWNERSHIP_BUSY", "one live session has one owner"

/* The owner facade is not the claim capability.  A retained live-session
 * reference plus the owner object still cannot bypass the private token. */
directOpen = live~open
call assertTrue \directOpen~ok, "direct TN5250 open denied"
call assertEq directOpen~code, "SESSION_OWNERSHIP_REQUIRED", "direct TN5250 open ownership code"
call assertEq transport~openCount, 0, "denied direct open does not touch transport"
facadeOpen = live~open(owner)
call assertTrue \facadeOpen~ok, "owner facade cannot impersonate private ownership capability"
call assertEq facadeOpen~code, "SESSION_OWNERSHIP_INVALID", "owner facade is not ownership token"
call assertEq transport~openCount, 0, "invalid owner facade does not touch transport"
call assertTrue \owner~hasMethod("OWNERSHIPTOKEN"), "owner does not export ownership token getter"

call assertTrue owner~open~ok, "owner opens TN5250 session"
call assertEq transport~openCount, 1, "one TN5250 transport open"
call assertTrue owner~open~ok, "owner TN5250 open idempotent"
call assertEq transport~openCount, 1, "observer/session reuse does not reopen transport"
facadeRelease = live~releaseExclusiveOwner(owner)
call assertTrue \facadeRelease~ok, "owner facade cannot release private ownership capability"
call assertEq facadeRelease~code, "SESSION_OWNERSHIP_INVALID", "owner facade release is rejected as wrong capability"

loaded = .KnownStateJsonStore~load("ibmi_known_states_live.json")
call assertTrue loaded~ok, "load IBM i known-state fixture"
directCatalog = live~attachKnownStateCatalog(loaded~value, 8)
call assertTrue \directCatalog~ok, "direct semantic tracker attach denied after claim"
call assertEq directCatalog~code, "SESSION_OWNERSHIP_REQUIRED", "direct semantic tracker ownership code"
ownedCatalog = owner~attachKnownStateCatalog(loaded~value, 8)
call assertTrue ownedCatalog~ok, "owner attaches semantic tracker"

obs = owner~attachObserver("AI_A")
call assertTrue obs~ok, "attach real TN5250 observer facade through owner"
observer = obs~value
call assertEq transport~openCount, 1, "TN5250 observer attaches to existing transport"
call assertEq observer~knownStateStatus~value, "NO_MATCH", "owned observer sees semantic tracker"
call assertTrue \observer~hasMethod("PRESS"), "TN5250 attached observer remains read-only"

/* Live-session control APIs are owner-gated as soon as ownership is claimed. */
auth = .LiveAdmission~new
directGate = live~enableControlGate(auth, "TERMINAL:SESSION:OWN5250")
call assertTrue \directGate~ok, "direct TN5250 gate enable denied"
call assertEq directGate~code, "SESSION_OWNERSHIP_REQUIRED", "direct gate ownership code"
call assertTrue owner~enableControlGate(auth, "TERMINAL:SESSION:OWN5250")~ok, "owner enables TN5250 control gate"
reservation = .LiveReservation~new("AI_A", "TERMINAL:SESSION:OWN5250")
control = observer~requestControl(reservation, .array~of("AID"))
call assertTrue control~ok, "owner grants TN5250 control to attached observer"
call assertTrue owner~controlActive, "owner reports real TN5250 control active"

directRevoke = live~revokeControl("BYPASS")
call assertTrue \directRevoke~ok, "direct TN5250 revoke denied"
call assertEq directRevoke~code, "SESSION_OWNERSHIP_REQUIRED", "direct revoke ownership code"
call assertTrue owner~revokeControl("OWNER_TEST")~ok, "owner revokes TN5250 controller"
call assertTrue \owner~controlActive, "owner revoke clears TN5250 control"

/* Pump and wire drain are also part of the exclusive lifecycle authority. */
directPump = live~pumpOnce(0)
call assertTrue \directPump~ok, "direct TN5250 pump denied"
call assertEq directPump~code, "SESSION_OWNERSHIP_REQUIRED", "direct pump ownership code"
call assertEq transport~receiveCount, 0, "denied direct pump reads no network bytes"
ownedPump = owner~pumpOnce(0)
call assertTrue ownedPump~ok, "owner quiet pump succeeds"
call assertEq transport~receiveCount, 1, "owner is sole TN5250 read pump"

directFlush = live~flushTerminalOutput
call assertTrue \directFlush~ok, "direct TN5250 wire flush denied"
call assertEq directFlush~code, "SESSION_OWNERSHIP_REQUIRED", "direct flush ownership code"
call assertEq transport~sendCount, 0, "denied flush sends no bytes"

directClose = live~close
call assertTrue \directClose~ok, "direct TN5250 close denied"
call assertEq directClose~code, "SESSION_OWNERSHIP_REQUIRED", "direct close ownership code"
call assertEq transport~closeCount, 0, "denied direct close leaves transport owned"
call assertTrue owner~close~ok, "owner closes TN5250 live session"
call assertEq transport~closeCount, 1, "one TN5250 transport close"
call assertTrue \live~ownershipClaimed, "TN5250 ownership claim released on close"

if failures > 0 then do
  say "FAIL test_tn5250_session_ownership" failures
  exit 1
end
say "PASS test_tn5250_session_ownership"
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


::class OwnershipToken

::class CountingLiveTransport
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

::class LiveReservation
::attribute identity get
::attribute scope get
::method init
  expose identity scope
  use arg identityArg, scopeArg
  identity = identityArg~string
  scope = scopeArg~string

::class LiveAdmission
::method admit
  use arg reservation
  return .TerminalResult~success(reservation)

::requires "TerminalOwnership.cls"
::requires "TN5250LiveSession.cls"
::requires "KnownStateJsonStore.cls"
