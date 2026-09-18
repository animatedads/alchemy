failures = 0

loaded = .KnownStateJsonStore~load("ibmi_known_states_live.json")
call assertTrue loaded~ok, "load live IBM i catalogue"
if \loaded~ok then do; say "FAIL test_broker_orderly_signoff" failures; exit 1; end
catalog = loaded~value
mainState = catalog~state("IBM_I_MAIN_MENU")
signonState = catalog~state("IBM_I_SIGNON")
call assertTrue mainState \== .nil, "main state present"
call assertTrue signonState \== .nil, "signon state present"
mainSnap = mainState~exemplars[1]~snapshot
signonSnap = signonState~exemplars[1]~snapshot

/* Exact MAIN -> ordinary broker control -> literal 90 -> exactly one ENTER ->
 * observation only -> remote close -> broker close. */
broker = .SignoffBrokerFixture~new(mainSnap)
reservation = .SignoffReservationFixture~new("TERMINAL_SERVICE_SIGNOFF")
signoffResult = .TN5250BrokerSignoff~perform(broker, catalog, reservation, "TERMINAL_SERVICE_SIGNOFF", 2, 0)
call assertTrue signoffResult~ok, "broker orderly signoff succeeds"
if signoffResult~ok then do
  call assertEq signoffResult~value~outcome, "REMOTE_CLOSED", "signoff outcome"
  call assertEq signoffResult~value~stateId, "IBM_I_MAIN_MENU", "confirmed state id"
  call assertEq signoffResult~value~commandFieldId, "F1527", "mapped command field"
  call assertEq signoffResult~value~finalBrokerState, "CLOSED", "result reports closed broker"
end
call assertEq broker~lastFieldId, "F1527", "only known command field staged"
call assertEq broker~lastValue, "90", "literal menu option 90 staged"
call assertEq broker~pressCount, 1, "exactly one AID sent"
call assertEq broker~lastAid, "ENTER", "AID is ENTER"
call assertEq broker~mutationCount, 2, "only set-field and ENTER mutate"
call assertEq broker~pumpCount, 1, "host observed after ENTER"
call assertEq broker~closeCount, 1, "broker closed after remote close"
call assertEq broker~attachedClientCount, 0, "local signoff client detached"
call assertTrue \broker~controlActive, "no controller remains"
call assertEq broker~actionLogText, "SET_FIELD|PRESS|PUMP|DETACH|CLOSE", "no post-AID input occurs"

/* Any other semantic host state is fail-closed before control or mutation and
 * leaves the persistent broker open for diagnosis. */
wrongBroker = .SignoffBrokerFixture~new(signonSnap)
wrong = .TN5250BrokerSignoff~perform(wrongBroker, catalog, reservation, "TERMINAL_SERVICE_SIGNOFF", 2, 0)
call assertTrue \wrong~ok, "wrong known state refused"
call assertEq wrong~code, "SIGNOFF_WRONG_STATE", "wrong-state result code"
call assertEq wrongBroker~mutationCount, 0, "wrong state has zero mutations"
call assertEq wrongBroker~pressCount, 0, "wrong state sends no AID"
call assertEq wrongBroker~pumpCount, 0, "wrong state performs no host pump"
call assertEq wrongBroker~closeCount, 0, "wrong state does not close broker"
call assertEq wrongBroker~attachedClientCount, 0, "diagnostic client detached on refusal"
call assertEq wrongBroker~status~state, "OPEN", "wrong-state broker remains open"

/* Once ENTER has been sent, an arbitrary changed screen is evidence only.
 * It must not be treated as successful signoff or converted into a generic
 * broker close.  No more input is sent. */
screenBroker = .SignoffBrokerFixture~new(mainSnap, "SCREEN_CHANGE")
screenChanged = .TN5250BrokerSignoff~perform(screenBroker, catalog, reservation, "TERMINAL_SERVICE_SIGNOFF", 2, 0)
call assertTrue \screenChanged~ok, "unconfirmed changed screen is not successful signoff"
call assertEq screenChanged~code, "SIGNOFF_SCREEN_CHANGED_UNCONFIRMED", "changed-screen refusal code"
call assertEq screenBroker~pressCount, 1, "changed-screen path sends exactly one ENTER"
call assertEq screenBroker~mutationCount, 2, "changed-screen path has only set-field and ENTER mutation"
call assertEq screenBroker~closeCount, 0, "changed screen does not generically close broker"
call assertEq screenBroker~status~state, "OPEN", "changed-screen broker retained for diagnosis"
call assertEq screenBroker~attachedClientCount, 0, "changed-screen diagnostic client detached"
call assertTrue \screenBroker~controlActive, "changed-screen controller released"
call assertEq screenBroker~actionLogText, "SET_FIELD|PRESS|PUMP|DETACH", "changed-screen path sends no post-AID input/close"

/* A bounded observation timeout after ENTER is also not proof of signoff. */
timeoutBroker = .SignoffBrokerFixture~new(mainSnap, "STAY_OPEN")
timedOut = .TN5250BrokerSignoff~perform(timeoutBroker, catalog, reservation, "TERMINAL_SERVICE_SIGNOFF", 1, 0)
call assertTrue \timedOut~ok, "signoff observation timeout surfaces failure"
call assertEq timedOut~code, "SIGNOFF_TIMEOUT", "signoff timeout code"
call assertEq timeoutBroker~pressCount, 1, "timeout path sends exactly one ENTER"
call assertEq timeoutBroker~closeCount, 0, "signoff timeout does not generically close broker"
call assertEq timeoutBroker~status~state, "OPEN", "timed-out broker retained for diagnosis"
call assertEq timeoutBroker~actionLogText, "SET_FIELD|PRESS|PUMP|DETACH", "timeout path sends no post-AID input/close"

/* A post-AID observation error likewise preserves the retained session. */
pumpFailBroker = .SignoffBrokerFixture~new(mainSnap, "PUMP_FAIL")
pumpFailed = .TN5250BrokerSignoff~perform(pumpFailBroker, catalog, reservation, "TERMINAL_SERVICE_SIGNOFF", 1, 0)
call assertTrue \pumpFailed~ok, "signoff observation error surfaces failure"
call assertEq pumpFailed~code, "FIXTURE_PUMP_FAILED", "pump failure code preserved"
call assertEq pumpFailBroker~pressCount, 1, "pump-failure path sends exactly one ENTER"
call assertEq pumpFailBroker~closeCount, 0, "pump failure does not generically close broker"
call assertEq pumpFailBroker~status~state, "OPEN", "pump-failed broker retained for diagnosis"

/* Signoff is not allowed until remote service capabilities have drained. */
busyBroker = .SignoffBrokerFixture~new(mainSnap)
busyBroker~forceAttached(1)
busy = .TN5250BrokerSignoff~perform(busyBroker, catalog, reservation)
call assertTrue \busy~ok, "attached remote client blocks signoff"
call assertEq busy~code, "BROKER_SIGNOFF_SERVICE_NOT_QUIESCED", "quiesce prerequisite code"
call assertEq busyBroker~mutationCount, 0, "busy service untouched"

if failures > 0 then do
  say "FAIL test_broker_orderly_signoff" failures
  exit 1
end
say "PASS test_broker_orderly_signoff"
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

::class SignoffReservationFixture
::attribute identity get
::method init
  expose identity
  use strict arg identityArg
  identity = identityArg~string

::class SignoffBrokerStatusFixture
::attribute state get
::method init
  expose state
  use strict arg stateArg
  state = stateArg~string

::class SignoffPumpFixture
::attribute snapshot get
::method init
  expose snapshot
  use strict arg snapshotArg
  snapshot = snapshotArg

::class SignoffGenerationFixture
::attribute generation get
::method init
  expose generation
  use strict arg generationArg
  generation = generationArg

::class SignoffBrokerFixture
::attribute attachedClientCount get
::attribute controlActive get
::attribute mutationCount get
::attribute pressCount get
::attribute pumpCount get
::attribute closeCount get
::attribute lastFieldId get
::attribute lastValue get
::attribute lastAid get

::method init
  expose snapshotValue attachedClientCount controlActive mutationCount pressCount pumpCount closeCount lastFieldId lastValue lastAid state aidSent actionLog pumpMode
  use strict arg snapshotArg, pumpModeArg = "REMOTE_CLOSE"
  snapshotValue = snapshotArg
  pumpMode = pumpModeArg~string~upper
  attachedClientCount = 0
  controlActive = .false
  mutationCount = 0
  pressCount = 0
  pumpCount = 0
  closeCount = 0
  lastFieldId = ""
  lastValue = ""
  lastAid = ""
  state = "OPEN"
  aidSent = .false
  actionLog = .array~new

::method forceAttached
  expose attachedClientCount
  use strict arg countArg
  attachedClientCount = countArg

::method attachClient
  expose attachedClientCount snapshotValue state
  use strict arg principalArg
  if state \== "OPEN" then return .TerminalResult~failure("BROKER_NOT_OPEN")
  if attachedClientCount \= 0 then return .TerminalResult~failure("BROKER_CLIENT_ALREADY_ATTACHED")
  attachedClientCount = 1
  return .TerminalResult~success(.SignoffClientFixture~new(self, snapshotValue, principalArg))

::method detachClient
  expose attachedClientCount actionLog
  use strict arg clientArg, reasonArg = "DETACHED"
  attachedClientCount = 0
  actionLog~append("DETACH")
  return .TerminalResult~success(.true)

::method acquireControl
  expose controlActive snapshotValue
  use strict arg clientArg, reservationArg, capabilitiesArg
  if controlActive then return .TerminalResult~failure("CONTROL_BUSY")
  if reservationArg == .nil then return .TerminalResult~failure("CONTROL_ADMISSION_REQUIRED")
  controlActive = .true
  return .TerminalResult~success(.SignoffControllerFixture~new(self, snapshotValue))

::method releaseControl
  expose controlActive
  use strict arg controllerArg, reasonArg = "RELEASED"
  controlActive = .false
  return .TerminalResult~success(.true)

::method recordSetField
  expose mutationCount lastFieldId lastValue actionLog
  use strict arg fieldIdArg, valueArg
  mutationCount += 1
  lastFieldId = fieldIdArg~string
  lastValue = valueArg~string
  actionLog~append("SET_FIELD")

::method recordPress
  expose mutationCount pressCount lastAid aidSent actionLog
  use strict arg aidArg
  mutationCount += 1
  pressCount += 1
  lastAid = aidArg~string
  aidSent = .true
  actionLog~append("PRESS")

::method pumpOnce
  expose pumpCount aidSent state snapshotValue actionLog pumpMode
  use strict arg timeoutArg, byteLimitArg
  pumpCount += 1
  actionLog~append("PUMP")
  if pumpMode == "PUMP_FAIL" then return .TerminalResult~failure("FIXTURE_PUMP_FAILED", "synthetic observation failure")
  if pumpMode == "REMOTE_CLOSE" then do
    if aidSent then state = "REMOTE_CLOSED"
    return .TerminalResult~success(.SignoffPumpFixture~new(snapshotValue))
  end
  if pumpMode == "SCREEN_CHANGE" then do
    changed = .SignoffGenerationFixture~new(snapshotValue~generation + 1)
    return .TerminalResult~success(.SignoffPumpFixture~new(changed))
  end
  /* STAY_OPEN deliberately returns the same generation. */
  return .TerminalResult~success(.SignoffPumpFixture~new(snapshotValue))

::method status
  expose state
  return .SignoffBrokerStatusFixture~new(state)

::method close
  expose state closeCount attachedClientCount controlActive actionLog
  state = "CLOSED"
  closeCount += 1
  attachedClientCount = 0
  controlActive = .false
  actionLog~append("CLOSE")
  return .TerminalResult~success(.true)

::method actionLogText
  expose actionLog
  text = ""
  do item over actionLog
    if text \== "" then text ||= "|"
    text ||= item
  end
  return text

::class SignoffClientFixture
::attribute principal get
::method init
  expose broker snapshotValue principal active
  use strict arg brokerArg, snapshotArg, principalArg
  broker = brokerArg
  snapshotValue = snapshotArg
  principal = principalArg~string
  active = .true
::method snapshot
  expose snapshotValue active
  if \active then return .TerminalResult~failure("BROKER_CLIENT_INACTIVE")
  return .TerminalResult~success(snapshotValue)
::method requestControl
  expose broker active
  use strict arg reservationArg, capabilitiesArg
  if \active then return .TerminalResult~failure("BROKER_CLIENT_INACTIVE")
  return broker~acquireControl(self, reservationArg, capabilitiesArg)
::method detach
  expose broker active
  use strict arg reasonArg = "DETACHED"
  if \active then return .TerminalResult~success(.true)
  active = .false
  return broker~detachClient(self, reasonArg)

::class SignoffControllerFixture
::attribute active get
::method init
  expose broker snapshotValue active
  use strict arg brokerArg, snapshotArg
  broker = brokerArg
  snapshotValue = snapshotArg
  active = .true
::method setField
  expose broker snapshotValue active
  use strict arg generationArg, fieldIdArg, valueArg
  if \active then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID")
  if generationArg \= snapshotValue~generation then return .TerminalResult~failure("STALE_SCREEN")
  broker~recordSetField(fieldIdArg, valueArg)
  return .TerminalResult~success(snapshotValue)
::method snapshot
  expose snapshotValue active
  if \active then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID")
  return .TerminalResult~success(snapshotValue)
::method press
  expose broker snapshotValue active
  use strict arg generationArg, aidArg
  if \active then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID")
  if generationArg \= snapshotValue~generation then return .TerminalResult~failure("STALE_SCREEN")
  broker~recordPress(aidArg)
  return .TerminalResult~success(snapshotValue)
::method release
  expose broker active
  use strict arg reasonArg = "RELEASED"
  if \active then return .TerminalResult~success(.true)
  active = .false
  return broker~releaseControl(self, reasonArg)

::requires "TN5250Signoff.cls"
