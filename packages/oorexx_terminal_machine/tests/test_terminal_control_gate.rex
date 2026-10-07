failures = 0

port = .FakeMutationPort~new("CTRL")
auth = .FakeAdmissionAuthority~new
alchemyRing = .CryptoMacKeyRing~new
alchemyRing~addKey("terminal-gate-test", "00112233445566778899aabbccddeeff")
alchemySealer = .AlchemyMacSealer~new(alchemyRing)
alchemyAuthority = .AlchemyCapabilityAuthority~new(alchemyRing)
gate = .TerminalControlGate~new("CTRL", "TERMINAL:QPADEV0037", port, auth, alchemySealer, alchemyAuthority)
call assertTrue gate~isA(.AlchemyObject), "control gate inherits AlchemyObject"
call assertTrue gate~checkSurfaceContract~ok, "control gate Alchemy surface contract"

/* Observation remains available without a controller. */
call assertEq gate~snapshot~generation, 1, "ungated observation"

capsA = .array~of("FIELD_WRITE", "FIELD_NAVIGATION", "AID")
resA = .FakeReservation~new("AI_A", "TERMINAL:QPADEV0037", "RA")
a = gate~acquire("AI_A", resA, capsA)
call assertTrue a~ok, "AI A acquires"
controllerA = a~value
call assertEq controllerA~controllerIdentity, "AI_A", "lease identity"
introspectCap = alchemyAuthority~issue("terminal-gate-audit", gate~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
gateView = gate~sealedIntrospection("CUSTOMER", introspectCap)
call assertTrue alchemySealer~verify(gateView), "control gate customer evidence verifies"
gateState = gateView~payload["state"]
call assertEq gateState["SCOPE"], "TERMINAL:QPADEV0037", "control scope visible to customer evidence"
call assertTrue \gateState~hasIndex("ACTIVERESERVATION"), "authenticated reservation remains secret"
call assertEq controllerA~acquiredGeneration, 1, "lease generation"

/* A second AI cannot acquire the same keyboard even with valid admission. */
resB = .FakeReservation~new("AI_B", "TERMINAL:QPADEV0037", "RB")
busy = gate~acquire("AI_B", resB, .array~of("AID"))
call assertTrue \busy~ok, "AI B blocked while A controls"
call assertEq busy~code, "CONTROL_BUSY", "one writer"
call assertEq port~actionCount, 0, "busy denial leaves terminal untouched"

/* Reservation identity/scope are authority data, not caller suggestions. */
wrongId = gate~acquire("AI_C", resB, .array~of("AID"))
call assertTrue \wrongId~ok, "wrong identity blocked (busy still wins)"

/* Mutation takes actor identity from the lease. */
set = controllerA~setField(1, "F1", "HELLO")
call assertTrue set~ok, "field write through gate"
call assertEq port~lastActor, "AI_A", "actor is lease identity"
call assertEq port~actionCount, 1, "one mutation"
facts = controllerA~meterFacts
call assertTrue facts~ok, "facts visible to lease holder"
call assertEq facts~value~items, 1, "field fact count"
call assertEq facts~value[1]~factType, "FIELD_WRITE", "field fact type"

/* The capability lease is not interchangeable with another object. */
fakeLease = .TerminalControlLease~new("forged", "AI_A", "CTRL", "TERMINAL:QPADEV0037", 1, capsA)
invalid = gate~press(fakeLease, 1, "ENTER")
call assertTrue \invalid~ok, "forged lease object rejected"
call assertEq invalid~code, "CONTROL_LEASE_INVALID", "object capability check"
call assertEq port~actionCount, 1, "forged lease no mutation"

/* Capability policy applies even while the controller owns the keyboard. */
sys = controllerA~systemRequest(1)
call assertTrue \sys~ok, "ungranted system request blocked"
call assertEq sys~code, "CONTROL_CAPABILITY_DENIED", "capability denial"
call assertEq port~actionCount, 1, "capability denial no mutation"

/* Host generation changes invalidate decisions made against the old screen. */
port~advanceGeneration
stale = controllerA~press(1, "ENTER")
call assertTrue \stale~ok, "stale action blocked"
call assertEq stale~code, "STALE_SCREEN", "stale generation code"
call assertEq port~actionCount, 1, "stale action no mutation"

/* Current-generation AID succeeds and is metered as an AID fact. */
pressed = controllerA~press(2, "ENTER")
call assertTrue pressed~ok, "current AID succeeds"
call assertEq port~lastActor, "AI_A", "AID actor"
facts2 = controllerA~meterFacts~value
call assertEq facts2~items, 2, "field plus aid facts"
call assertEq facts2[2]~factType, "AID", "aid fact type"

/* Host response attribution adds screen update + one round trip. */
port~advanceGeneration
ignore = gate~recordObservedFact("BYTES_RX", 128, "TN5250")
ignore = gate~recordHostScreenUpdate(1)
facts3 = controllerA~meterFacts~value
call assertEq facts3~items, 5, "transport + screen + roundtrip facts"
call assertEq facts3[3]~factType, "BYTES_RX", "rx fact"
call assertEq facts3[4]~factType, "SCREEN_UPDATE", "screen update fact"
call assertEq facts3[5]~factType, "HOST_ROUND_TRIP", "round trip fact"

/* Release is atomic; old authority cannot be inherited by B. */
released = controllerA~release("HANDOFF")
call assertTrue released~ok, "A releases"
call assertEq released~value~mutationCount, 2, "release mutation count"
old = controllerA~setField(3, "F1", "NO")
call assertTrue \old~ok, "released lease unusable"
call assertEq old~code, "CONTROL_NOT_HELD", "old lease after release"

/* B can now acquire, but not before. */
b = gate~acquire("AI_B", resB, .array~of("AID"))
call assertTrue b~ok, "B acquires after release"
controllerB = b~value
call assertEq controllerB~controllerIdentity, "AI_B", "handoff identity"

/* Revalidation occurs before every mutation.  Revoked/expired admission
 * removes the keyboard capability before touching the terminal. */
auth~denyReservation("RB", "WLU_RESERVATION_EXPIRED")
before = port~actionCount
expired = controllerB~press(3, "ENTER")
call assertTrue \expired~ok, "expired admission blocks action"
call assertEq expired~code, "CONTROL_ADMISSION_INVALID", "admission invalid code"
call assertEq port~actionCount, before, "expired admission no mutation"
call assertTrue \gate~active, "invalid admission revokes controller"

/* A capacity denial at acquisition is also pre-mutation. */
resC = .FakeReservation~new("AI_C", "TERMINAL:QPADEV0037", "RC")
auth~denyReservation("RC", "WLU_CAPACITY_EXHAUSTED")
denied = gate~acquire("AI_C", resC, .array~of("AID"))
call assertTrue \denied~ok, "capacity denial at acquisition"
call assertEq denied~code, "CONTROL_ADMISSION_DENIED", "acquire denial code"
call assertEq port~actionCount, before, "capacity denial no mutation"

if failures > 0 then do
  say "FAIL test_terminal_control_gate" failures
  exit 1
end
say "PASS test_terminal_control_gate"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::class FakeReservation
::attribute identity get
::attribute scope get
::attribute reservationId get
::method init
  expose identity scope reservationId
  use arg identityArg, scopeArg, idArg
  identity = identityArg~string
  scope = scopeArg~string
  reservationId = idArg~string

::class FakeAdmissionAuthority
::method init
  expose denials
  denials = .table~new
::method denyReservation
  expose denials
  use arg reservationIdArg, codeArg
  denials[reservationIdArg~string] = codeArg~string
  return self
::method admit
  expose denials
  use arg reservation
  code = denials[reservation~reservationId]
  if code \== .nil then return .TerminalResult~failure(code, "fixture denial")
  return .TerminalResult~success(reservation)

::class FakeMutationPort
::attribute actionCount get
::attribute lastActor get
::method init
  expose sessionId generation actionCount lastActor
  use arg sessionIdArg
  sessionId = sessionIdArg
  generation = 1
  actionCount = 0
  lastActor = ""
::method snapshot
  expose generation
  rows = .array~of("TEST")
  return .TerminalSnapshot~new(generation, "FAKE", 1, 80, 1, 1, "UNLOCKED", "OPERATOR_WAIT", rows)
::method advanceGeneration
  expose generation
  generation += 1
  return generation
::method mutate private
  expose actionCount lastActor
  use arg actorArg
  actionCount += 1
  lastActor = actorArg~string
  return .TerminalResult~success(self~snapshot)
::method setField
  use arg generationArg, fieldIdArg, valueArg, actorArg
  return self~mutate(actorArg)
::method typeAtCursor
  use arg generationArg, textArg, actorArg
  return self~mutate(actorArg)
::method moveCursor
  use arg generationArg, rowArg, colArg, actorArg
  return self~mutate(actorArg)
::method focusField
  use arg generationArg, fieldIdArg, actorArg
  return self~mutate(actorArg)
::method nextInputField
  use arg generationArg, actorArg
  return self~mutate(actorArg)
::method previousInputField
  use arg generationArg, actorArg
  return self~mutate(actorArg)
::method home
  use arg generationArg, actorArg
  return self~mutate(actorArg)
::method errorReset
  use arg generationArg, actorArg
  return self~mutate(actorArg)
::method press
  use arg generationArg, aidArg, actorArg
  return self~mutate(actorArg)
::method systemRequest
  use arg generationArg, actorArg
  return self~mutate(actorArg)

::requires "TerminalControl.cls"
