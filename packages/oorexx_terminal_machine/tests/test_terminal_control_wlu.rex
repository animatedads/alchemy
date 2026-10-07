/* Concrete integration with oorexx_work_load_units_v0.2.1.
 * WorkLoadUnits.cls and crypto.cls are external dependencies supplied through
 * REXX_PATH; this terminal package does not vendor them. */
failures = 0
MICRO = 1000000
scope = "TERMINAL:QPADEV0037"

clock = .WLUTestTimeSource~new(9000000)
keys = .WLUFastMacKeyRing~new
ignore = keys~addKey("terminal-live", "000102030405060708090a0b0c0d0e0f")
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
accountA = .WLUAccount~new("acct-a", 10 * MICRO)
accountB = .WLUAccount~new("acct-b", 10 * MICRO)
auth~addAccount(accountA)
auth~addAccount(accountB)
auth~bindAccount("AI_A", "TERMINAL:*", accountA~accountId)
auth~bindAccount("AI_B", "TERMINAL:*", accountB~accountId)

bucket = .WLUCapacityBucket~new("terminal-one-controller", 1 * MICRO, 0, clock~nowTick)
auth~addBucket(bucket)
auth~bindBucket("*", "TERMINAL:*", bucket~bucketId)

card = .WLURateCard~new("terminal.control", "2026-08")
card~addRule(.WLURateRule~new("FIELD_WRITE", 100000))
card~addRule(.WLURateRule~new("AID", 250000))
card~addRule(.WLURateRule~new("SCREEN_UPDATE", 50000))
card~addRule(.WLURateRule~new("HOST_ROUND_TRIP", 200000))
card~addRule(.WLURateRule~new("BYTES_RX", 1000, 1024))
card~addRule(.WLURateRule~new("BYTES_TX", 1000, 1024))
card~seal
auth~addRateCard(card)
auth~bindRateCard("*", "TERMINAL:*", card~rateCardId, card~version)

/* AI A reserves enough WLU for its planned terminal work. */
plannedA = .array~of(.WLUFact~new("FIELD_WRITE", 1, "TN5250"), .WLUFact~new("AID", 1, "TN5250"), .WLUFact~new("SCREEN_UPDATE", 1, "TN5250"), .WLUFact~new("HOST_ROUND_TRIP", 1, "TN5250"))
ra = auth~reserveFacts("AI_A", scope, plannedA, 10, "control-a")
call assertTrue ra~ok, "A WLU reservation"

port = .WluFakePort~new
gate = .TerminalControlGate~new("LIVE-1", scope, port, auth)
acqA = gate~acquire("AI_A", ra~value, .array~of("FIELD_WRITE", "AID"))
call assertTrue acqA~ok, "cryptographic WLU admission grants terminal lease"
controllerA = acqA~value

/* A separate admitted workload can consume the remaining shared WLU capacity
 * and prevent another controller from even obtaining a reservation.  This
 * happens before the terminal gate is touched. */
blocker = auth~reserve("AI_B", scope, 300000, 10, "capacity-blocker", "internal.fixture", "1")
call assertTrue blocker~ok, "capacity blocker"
plannedB = .array~of(.WLUFact~new("AID", 1, "TN5250"))
rbDenied = auth~reserveFacts("AI_B", scope, plannedB, 10, "control-b-denied")
call assertTrue \rbDenied~ok, "B WLU capacity denied"
call assertEq rbDenied~code, "WLU_CAPACITY_EXHAUSTED", "capacity is 429-like"
call assertEq port~actionCount, 0, "WLU denial leaves terminal untouched"

/* A performs work through the gate. */
call assertTrue controllerA~setField(1, "F1", "VALUE")~ok, "A field write"
call assertTrue controllerA~press(1, "ENTER")~ok, "A AID"
port~advanceGeneration
ignore = gate~recordHostScreenUpdate(1)
call assertEq port~actionCount, 2, "A owns both mutations"

/* Convert terminal-declared facts to WLU facts only at the WLU boundary. */
tfacts = controllerA~meterFacts~value
wfacts = .array~new
do f over tfacts
  wfacts~append(.WLUFact~new(f~factType, f~quantity, f~source, f~dimensions))
end
settled = auth~settleFacts(ra~value, wfacts)
call assertTrue settled~ok, "actual terminal facts settle against captured rate card"
call assertEq accountA~spentMicroWlu, 600000, "actual terminal work charged as policy values it"

/* Settling invalidates the reservation.  The gate revalidates before mutation,
 * revokes A and does not let a stale controller continue typing. */
before = port~actionCount
postSettle = controllerA~setField(2, "F1", "SHOULD-NOT-HAPPEN")
call assertTrue \postSettle~ok, "settled WLU proof no longer admits mutation"
call assertEq postSettle~code, "CONTROL_ADMISSION_INVALID", "gate rejects inactive admission"
call assertEq port~actionCount, before, "post-settlement mutation blocked"
call assertTrue \gate~active, "gate revoked settled controller"

/* Release unused blocker capacity; A's settled work remains consumed, while
 * enough capacity is now available for B. */
ignore = auth~release(blocker~value)
rb = auth~reserveFacts("AI_B", scope, plannedB, 10, "control-b")
call assertTrue rb~ok, "B reservation after A settlement"
acqB = gate~acquire("AI_B", rb~value, .array~of("AID"))
call assertTrue acqB~ok, "B takes keyboard only after A invalidated"
controllerB = acqB~value
call assertTrue controllerB~press(2, "F3")~ok, "B action"
call assertEq port~lastActor, "AI_B", "B action attribution"
ignore = controllerB~release("DONE")
ignore = auth~release(rb~value)

/* A forged copy with altered identity is rejected by the WLU MAC before a
 * terminal lease exists. */
rc = auth~reserveFacts("AI_A", scope, plannedB, 10, "forge-source")
call assertTrue rc~ok, "source reservation for tamper test"
r = rc~value
forged = .WLUReservation~new(r~reservationId, "AI_EVIL", r~accountId, r~scope, r~rateCardId, r~rateCardVersion, r~reservedMicroWlu, r~issuedTick, r~expiresTick, r~bucketIds, r~proofRevision, r~proof, r~expectedMicroWlu, r~reservedRateMicroWluPerSecond, r~throughputPoolIds)
forgedAcquire = gate~acquire("AI_EVIL", forged, .array~of("AID"))
call assertTrue \forgedAcquire~ok, "tampered cryptographic reservation rejected"
call assertEq forgedAcquire~code, "CONTROL_ADMISSION_DENIED", "WLU proof denial surfaced"
call assertEq port~actionCount, before + 1, "forged proof never touches terminal"
ignore = auth~release(rc~value)

if failures > 0 then do
  say "FAIL test_terminal_control_wlu" failures
  exit 1
end
say "PASS test_terminal_control_wlu"
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

::class WluFakePort
::attribute actionCount get
::attribute lastActor get
::method init
  expose generation actionCount lastActor
  generation = 1
  actionCount = 0
  lastActor = ""
::method snapshot
  expose generation
  return .TerminalSnapshot~new(generation, "FAKE", 1, 80, 1, 1, "UNLOCKED", "OPERATOR_WAIT", .array~of("TEST"))
::method advanceGeneration
  expose generation
  generation += 1
  return generation
::method setField
  expose actionCount lastActor
  use arg generationArg, fieldIdArg, valueArg, actorArg
  actionCount += 1
  lastActor = actorArg
  return .TerminalResult~success(self~snapshot)
::method press
  expose actionCount lastActor
  use arg generationArg, aidArg, actorArg
  actionCount += 1
  lastActor = actorArg
  return .TerminalResult~success(self~snapshot)

::requires "TerminalControl.cls"
::requires "WorkLoadUnits.cls"
