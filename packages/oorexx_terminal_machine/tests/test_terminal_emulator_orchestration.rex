failures = 0

machine = .TerminalEmulatorStateMachine~new("TESTBED")
regs = .directory~new
regs["PC"] = 100
rc = machine~createComponent("CPU", regs, "ORCH-CPU")
call assertTrue rc~ok, "CPU component"
cpu = rc~value

devState = .directory~new
devState["IRQ"] = 0
rc = machine~createComponent("DEV", devState, "ORCH-DEV")
call assertTrue rc~ok, "device component"
dev = rc~value

orchestrator = .TerminalEmulatorEventOrchestrator~new(machine, 5)
pipeline = .OrchestrationPipeline~new(cpu)

/* Fixed fetch/decode/execute instruction phases commit as one attempt. */
r1 = orchestrator~runInstruction("INC-PC", pipeline, .nil, "PC=104")
call assertTrue r1~ok, "successful instruction"
call assertEq cpu~at("PC"), 104, "successful instruction keeps state"
h1 = orchestrator~history
call assertEq h1~items, 1, "one history entry"
e1 = h1[1]
call assertEq e1~outcome, "COMMITTED", "first outcome committed"
call assertEq e1~terminalPhase, "COMMIT", "first terminal phase"
p1 = e1~phases
call assertEq p1~items, 4, "three instruction phases plus commit"
call assertEq p1[1], "FETCH:OK", "fetch trace"
call assertEq p1[2], "DECODE:OK", "decode trace"
call assertEq p1[3], "EXECUTE:OK", "execute trace"
call assertEq p1[4], "COMMIT:OK", "commit trace"
firstId = e1~eventId

/* A handler failure after speculative mutation automatically restores state. */
pipeline~setMode("EXEC_FAIL")
r2 = orchestrator~runInstruction("FAULTING-INC", pipeline)
call assertTrue \r2~ok, "instruction failure returned"
call assertEq r2~code, "EXECUTION_FAULT", "instruction failure code"
call assertEq cpu~at("PC"), 104, "failed execution rolled back mutation"
e2 = orchestrator~eventById(orchestrator~lastEventId)
call assertEq e2~outcome, "ROLLED_BACK", "failed execution history outcome"
call assertEq e2~terminalPhase, "EXECUTE", "failed phase evidence"
call assertEq e2~phases[e2~phases~items], "ROLLBACK:OK", "rollback evidence"

/* Missing instruction remains a retained failed future; explicit retry links a
 * repaired attempt without exposing the exact execution ticket. */
pipeline~setMode("MISSING")
r3 = orchestrator~runInstruction("MISSING-OP", pipeline)
call assertTrue \r3~ok, "missing opcode failure"
call assertEq r3~code, "OPCODE_MISSING", "missing opcode code"
call assertEq cpu~at("PC"), 104, "missing opcode mutation rolled back"
missingId = orchestrator~lastEventId
missingEvidence = orchestrator~eventById(missingId)
missingCheckpoint = missingEvidence~checkpointId

pipeline~setMode("OK")
r4 = orchestrator~retryInstruction(missingId, pipeline, .nil, "PC=108")
call assertTrue r4~ok, "repaired retry commits"
call assertEq cpu~at("PC"), 108, "retry forward state"
retryId = orchestrator~lastEventId
retryEvidence = orchestrator~eventById(retryId)
call assertEq retryEvidence~retryOfEventId, missingId, "retry linked to failed event"
call assertEq retryEvidence~outcome, "COMMITTED", "retry committed"
call assertEq orchestrator~retryCount, 1, "retry count"

/* Failed branch is still materialisable through the v0.20 debugger without
 * moving the current forward head. */
timeline = machine~timeline
old = timeline~materialise(missingCheckpoint)
call assertTrue old~ok, "failed checkpoint remains materialisable"
call assertEq old~value["CPU"]["PC"], 104, "failed checkpoint is exact pre-attempt state"
call assertEq cpu~at("PC"), 108, "historical inspection does not move current state"

/* SYNTAX from a handler is contained and automatically rolled back. */
pipeline~setMode("SYNTAX")
r5 = orchestrator~runInstruction("BAD-HANDLER", pipeline)
call assertTrue \r5~ok, "syntax failure returned"
call assertEq r5~code, "TERMINAL_EMULATOR_HANDLER_SYNTAX", "syntax mapped to bounded fault"
call assertEq cpu~at("PC"), 108, "syntax path rolled back mutation"
syntaxEvidence = orchestrator~eventById(orchestrator~lastEventId)
call assertEq syntaxEvidence~outcome, "ROLLED_BACK", "syntax history rolled back"
call assertEq syntaxEvidence~terminalPhase, "EXECUTE", "syntax phase evidence"

/* Generic non-instruction event uses the same exact checkpoint discipline. */
deviceHandler = .DeviceEventHandler~new(dev)
r6 = orchestrator~runEvent("DEVICE", "RAISE-IRQ", deviceHandler, .nil, "IRQ=1")
call assertTrue r6~ok, "device event commits"
call assertEq dev~at("IRQ"), 1, "device state committed"
deviceEvidence = orchestrator~eventById(orchestrator~lastEventId)
call assertEq deviceEvidence~kind, "DEVICE", "device kind evidence"
call assertEq deviceEvidence~phases[1], "HANDLE:OK", "device handler phase"

/* History is bounded and returned arrays are detached from retained indexing. */
h = orchestrator~history
call assertEq h~items, 5, "bounded history limit"
call assertTrue orchestrator~eventById(firstId) == .nil, "evicted event removed from id index"
h~remove(1)
call assertEq orchestrator~history~items, 5, "caller mutation cannot shrink retained history"

/* A committed attempt is not a legal retry source. */
wrongRetry = orchestrator~retryInstruction(retryId, pipeline)
call assertTrue \wrongRetry~ok, "committed event cannot be retried"
call assertEq wrongRetry~code, "TERMINAL_EMULATOR_RETRY_OUTCOME", "committed retry refusal code"

/* Marker and fixed-method validation happen before any checkpoint is created. */
checkpointsBefore = machine~checkpointCount
dispatchBefore = orchestrator~dispatchCount
bad = orchestrator~runInstruction("UNMARKED", .UnmarkedPipeline~new(cpu))
call assertTrue \bad~ok, "unmarked pipeline denied"
call assertEq bad~code, "TERMINAL_EMULATOR_INSTRUCTION_PIPELINE", "unmarked pipeline code"
call assertEq machine~checkpointCount, checkpointsBefore, "denied handler creates no checkpoint"
call assertEq orchestrator~dispatchCount, dispatchBefore, "denied handler not dispatched"

badKind = orchestrator~runEvent("INSTRUCTION", "WRONG-API", deviceHandler)
call assertTrue \badKind~ok, "instruction cannot bypass fixed pipeline API"
call assertEq badKind~code, "TERMINAL_EMULATOR_EVENT_KIND", "instruction generic-event refusal"

call assertEq orchestrator~committedCount, 3, "committed attempts count"
call assertEq orchestrator~rolledBackCount, 3, "rolled back attempts count"
call assertEq orchestrator~faultCount, 3, "fault count"

if failures > 0 then do
  say "FAIL test_terminal_emulator_orchestration" failures
  exit 1
end
say "PASS test_terminal_emulator_orchestration"
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

::class OrchestrationPipeline public inherit TerminalEmulatorInstructionPipeline
::method init
  expose cpu mode
  use strict arg cpuArg
  cpu = cpuArg
  mode = "OK"

::method setMode
  expose mode
  use strict arg modeArg
  mode = modeArg~string~upper
  return self

::method emulatorFetch
  use strict arg event, context
  return "OPCODE"

::method emulatorDecode
  expose mode
  use strict arg event, fetched, context
  if mode == "DECODE_FAIL" then return .TerminalResult~failure("DECODE_FAULT", "decoder refused opcode")
  return "INC"

::method emulatorExecute
  expose cpu mode
  use strict arg event, decoded, context
  cpu~put("PC", cpu~at("PC") + 4, "EXECUTE-" || event~eventId)
  if mode == "EXEC_FAIL" then return .TerminalResult~failure("EXECUTION_FAULT", "synthetic execution fault")
  if mode == "MISSING" then return .TerminalResult~failure("OPCODE_MISSING", "instruction implementation unavailable")
  if mode == "SYNTAX" then raise syntax 88.900 array("synthetic pipeline syntax fault")
  return cpu~at("PC")

::class DeviceEventHandler public inherit TerminalEmulatorEventHandler
::method init
  expose device
  use strict arg deviceArg
  device = deviceArg

::method emulatorHandleEvent
  expose device
  use strict arg event, context
  device~put("IRQ", device~at("IRQ") + 1, event~eventId)
  return device~at("IRQ")

::class UnmarkedPipeline public
::method init
  expose cpu
  use strict arg cpuArg
  cpu = cpuArg
::method emulatorFetch
  return "OPCODE"
::method emulatorDecode
  return "INC"
::method emulatorExecute
  return 1

::requires "TerminalEmulatorOrchestration.cls"
