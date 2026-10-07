failures = 0

chunks = .array~new
chunks~append("FFFD27"x)                              /* DO NEW-ENVIRON */
chunks~append("FFFA27010003FFF0"x)                  /* SEND VAR/USERVAR */
chunks~append("FFFA270103"x || "DEVNAME" || "FFF0"x) /* collision */
fake = .FakeLiveTransport~new(chunks)
live = .TN5250LiveSession~new("RESUME", "example.test", 992, "IBM-3179-2", "QPADEV0037", "STRICT", fake)
call assertTrue live~isA(.AlchemyObject), "live session inherits AlchemyObject"
call assertTrue live~checkSurfaceContract~ok, "live session Alchemy surface contract"

opened = live~open
call assertTrue opened~ok, "live open"
call assertEq live~state, "OPEN", "live open state"

p1 = live~pumpOnce(1)
call assertTrue p1~ok, "first negotiation pump"
p2 = live~pumpOnce(1)
call assertTrue p2~ok, "initial DEVNAME pump"
call assertTrue fake~sentBytes~pos("QPADEV0037") > 0, "exact requested DEVNAME sent"

p3 = live~pumpOnce(1)
call assertTrue \p3~ok, "strict collision is terminal result"
call assertEq p3~code, "TN5250_DEVICE_COLLISION", "strict collision code"
call assertEq live~state, "DEVICE_COLLISION", "strict collision state"
call assertEq live~negotiatedDeviceName, "QPADEV0037", "no fallback device"
call assertEq live~effectiveDeviceName, "QPADEV0037", "requested/negotiated device remains effective"
call assertEq live~deviceIdentitySource, "TELNET_DEVNAME", "negotiation evidence source refreshed"
call assertEq live~deviceNameCollisionCount, 1, "collision count"
call assertTrue fake~closed, "collision closes rejected transport"
call assertTrue fake~sentBytes~pos("QPADEV0038") = 0, "never creates next device"

/* A quiet long-lived session is not an error; it simply reports no activity. */
quiet = .FakeLiveTransport~new(.array~new)
live2 = .TN5250LiveSession~new("QUIET", "example.test", 992, "IBM-3179-2", "", "ADVANCE", quiet)
call assertTrue live2~open~ok, "quiet open"
raw = live2~automationPort
call assertTrue \raw~ok, "live session refuses raw mutable automation port"
call assertEq raw~code, "CONTROL_GATE_REQUIRED", "live raw port denial"
observer = live2~observerPort
call assertTrue observer~hasMethod("SNAPSHOT"), "observer can snapshot"
call assertTrue \observer~hasMethod("PRESS"), "observer has no AID mutation method"
call assertEq observer~knownStateStatus, "UNTRACKED", "observer reports untracked semantic state before catalog attachment"
loadedCatalog = .KnownStateJsonStore~load("ibmi_known_states_live.json")
call assertTrue loadedCatalog~ok, "load catalog for live semantic tracker"
semanticAttach = live2~attachKnownStateCatalog(loadedCatalog~value, 8)
call assertTrue semanticAttach~ok, "attach semantic tracker to live session"
semanticObserver = live2~observerPort
call assertEq semanticObserver~knownStateStatus, "NO_MATCH", "semantic observer starts at no-match generation zero"
call assertEq live2~currentKnownStateStatus, "NO_MATCH", "live session mirrors semantic status"
secondSemantic = live2~attachKnownStateCatalog(loadedCatalog~value, 8)
call assertTrue \secondSemantic~ok, "second live semantic tracker rejected"
call assertEq secondSemantic~code, "KNOWN_STATE_TRACKER_EXISTS", "second live semantic tracker code"

authority = .FakeLiveAdmission~new
call assertTrue live2~enableControlGate(authority, "TERMINAL:SESSION:QUIET")~ok, "enable control gate"
reservation = .FakeLiveReservation~new("AI_A", "TERMINAL:SESSION:QUIET")
controller = live2~acquireControl("AI_A", reservation, .array~of("AID"))
call assertTrue controller~ok, "live controller acquire"
call assertTrue live2~controlActive, "live reports controller active"
call assertEq live2~activeControllerIdentity, "AI_A", "live controller identity"
call assertTrue live2~activeControlLeaseId \= "", "live lease id exposed without capability object"
reservationB = .FakeLiveReservation~new("AI_B", "TERMINAL:SESSION:QUIET")
busyControl = live2~acquireControl("AI_B", reservationB, .array~of("AID"))
call assertTrue \busyControl~ok, "second live controller blocked"
call assertEq busyControl~code, "CONTROL_BUSY", "live one-writer code"
call assertTrue live2~revokeControl("TEST")~ok, "trusted owner revoke"
call assertTrue \live2~controlActive, "revocation clears controller"

qp = live2~pumpOnce(1)
call assertTrue qp~ok, "quiet pump success"
call assertTrue \qp~value~activity, "quiet pump no activity"
call assertEq live2~state, "OPEN", "quiet session stays open"
controller2 = live2~acquireControl("AI_B", reservationB, .array~of("AID"))
call assertTrue controller2~ok, "controller reacquired before session close"
ignore = live2~close
call assertEq live2~state, "CLOSED", "explicit close"
call assertTrue \live2~controlActive, "session close revokes controller"
call assertTrue \controller2~value~press(0, "ENTER")~ok, "revoked controller cannot mutate closed session"

/* Remote EOF is represented separately from a protocol or TLS error. */
eofChunks = .array~new
eofChunks~append("")
eofTransport = .FakeLiveTransport~new(eofChunks)
live3 = .TN5250LiveSession~new("EOF", "example.test", 992, "IBM-3179-2", "", "ADVANCE", eofTransport)
call assertTrue live3~open~ok, "EOF open"
eofPump = live3~pumpOnce(1)
call assertTrue eofPump~ok, "EOF pump is observable state"
call assertEq live3~state, "REMOTE_CLOSED", "remote close state"
call assertTrue eofTransport~closed, "remote close closes local transport"

if failures > 0 then do
  say "FAIL test_tn5250_live_session" failures
  exit 1
end
say "PASS test_tn5250_live_session"
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

::class FakeLiveTransport
::attribute sentBytes get
::attribute closed get

::method init
  expose chunks nextIndex sentBytes closed opened
  use arg chunksArg
  chunks = chunksArg
  nextIndex = 1
  sentBytes = ""
  closed = .false
  opened = .false

::method open
  expose opened closed
  opened = .true
  closed = .false
  return .TerminalResult~success

::method receiveBytesWait
  expose chunks nextIndex opened closed
  use arg maximum = 16384, timeoutSeconds = 1
  if \opened | closed then return .TerminalResult~failure("TRANSPORT_CLOSED")
  if nextIndex > chunks~items then return .TerminalResult~failure("TRANSPORT_TIMEOUT", timeoutSeconds)
  bytes = chunks[nextIndex]
  nextIndex += 1
  return .TerminalResult~success(bytes)

::method sendBytes
  expose sentBytes opened closed
  use arg bytes
  if \opened | closed then return .TerminalResult~failure("TRANSPORT_CLOSED")
  sentBytes ||= bytes
  return .TerminalResult~success(bytes~length)

::method close
  expose closed opened
  closed = .true
  opened = .false
  return .TerminalResult~success

::class FakeLiveReservation
::attribute identity get
::attribute scope get
::method init
  expose identity scope
  use arg identityArg, scopeArg
  identity = identityArg~string
  scope = scopeArg~string

::class FakeLiveAdmission
::method admit
  use arg reservation
  return .TerminalResult~success(reservation)

::requires "TN5250LiveSession.cls"
::requires "KnownStateJsonStore.cls"
