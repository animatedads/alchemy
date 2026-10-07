sealer = .JournalRefEvidenceSealer~new
authority = .JournalRefCapabilityAuthority~new

machine = .TerminalEmulatorStateMachine~new("EMULATOR", sealer, authority)
initial = .directory~new
initial["PC"] = 1
created = machine~createComponent("CPU", initial, "REF-JOURNAL", sealer, authority)
if \created~ok then raise syntax 88.900 array("fixture component creation failed")
component = created~value
machine~checkpoint("ref", "INSTRUCTION")

ms = fullState(machine, authority)
call assertMissing ms, "CONTROLLER"
call assertMissing ms, "COMPONENTS"
call assertMissing ms, "CHECKPOINTHISTORY"
call assertEq ms["MODE"], "EMULATOR", "safe mode remains inspectable"
call assertEq ms["CHECKPOINTCOUNT"], 1, "safe checkpoint count remains inspectable"

cs = fullState(component, authority)
call assertMissing cs, "JOURNALSTATE"
call assertEq cs["COMPONENTID"], "CPU", "safe component id remains inspectable"
call assertEq cs["JOURNALID"], "REF-JOURNAL", "safe journal id remains inspectable"

front = .JournalRefFront~new
recovery = .TerminalEmulatorRecoveryCoordinator~new(machine, front, sealer, authority)
recovery~arm("repair")
rs = fullState(recovery, authority)
call assertMissing rs, "MACHINE"
call assertMissing rs, "FRONTEND"
call assertMissing rs, "ARMEDCHECKPOINT"

timeline = machine~timeline(sealer, authority)
ts = fullState(timeline, authority)
call assertMissing ts, "MACHINE"
call assertEq ts["INSPECTIONCOUNT"], 0, "timeline safe inspection count"

boundary = .TerminalEmulatorExecutionBoundary~new(machine, sealer, authority)
begun = boundary~begin("ALCHEMY-TEST")
if \begun~ok then raise syntax 88.900 array("execution boundary begin failed")
bs = fullState(boundary, authority)
call assertMissing bs, "MACHINE"
call assertMissing bs, "ACTIVETICKET"
call assertMissing bs, "ACTIVECHECKPOINT"
call assertEq bs["STATE"], "ACTIVE", "boundary scalar state visible"
call assertEq bs["STARTEDCOUNT"], 1, "boundary scalar count visible"
ignore = boundary~rollback(begun~value, "TEST-CLEANUP")

/* v0.21 orchestration retains the exact execution boundary/ticket/history only
 * as private capability/context references. */
orchestrator = .TerminalEmulatorEventOrchestrator~new(machine, 8, sealer, authority)
os = fullState(orchestrator, authority)
call assertMissing os, "MACHINE"
call assertMissing os, "BOUNDARY"
call assertMissing os, "HISTORY"
call assertMissing os, "HISTORYBYID"
call assertEq os["HISTORYLIMIT"], 8, "orchestration bounded history scalar visible"
call assertEq os["DISPATCHCOUNT"], 0, "orchestration safe dispatch count visible"

say "PASS test_terminal_emulator_journal_alchemy"
exit 0

fullState: procedure
  use strict arg object, authority
  sealed = object~sealedIntrospection("FULL", .nil)
  return sealed~payload["state"]

assertMissing: procedure
  use strict arg state, key
  if state~hasIndex(key) then raise syntax 88.900 array("assertMissing failed key=" || key)
  return

assertEq: procedure
  use strict arg actual, expected, label
  if actual \== expected then raise syntax 88.900 array("assertEq failed " || label || " expected=" || expected || " actual=" || actual)
  return

::class JournalRefEvidenceEnvelope
::attribute payload get
::method init
  expose payload
  use strict arg payloadArg
  payload = payloadArg

::class JournalRefEvidenceSealer
::method seal
  use strict arg subject, payload
  return .JournalRefEvidenceEnvelope~new(payload)

::class JournalRefCapabilityAuthority
::method verify
  use arg capability, objectId, operation, purpose, requireActive = .true
  return .true

::class JournalRefFront
::method stateRecoveryRequest
  use strict arg request
  return .nil

::requires "TerminalEmulatorOrchestration.cls"
