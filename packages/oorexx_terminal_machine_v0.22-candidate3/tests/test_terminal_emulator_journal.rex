failures = 0

machine = .TerminalEmulatorStateMachine~new("EMULATOR")
regs0 = .directory~new
regs0["PC"] = 4096
regs0["ACC"] = 0
mem0 = .directory~new
mem0["2000"] = "00"

r = machine~createComponent("CPU", regs0, "TEST-CPU")
call assertTrue r~ok, "create CPU component"
cpuState = r~value
r = machine~createComponent("MEM", mem0, "TEST-MEM")
call assertTrue r~ok, "create MEM component"
memState = r~value

cp0 = machine~checkpoint("before instruction", "INSTRUCTION")
call assertEq machine~checkpointCount, 1, "checkpoint count"

/* One batched register edit is one meaningful journal node. */
edit = cpuState~beginEdit("OP-CAFE")
edit~put("PC", 4100)
edit~put("ACC", 7)
p = edit~commit
call assertEq cpuState~retainedNodeCount, 1, "batched CPU edit creates one node"
memState~put("2000", "AA", "STORE")
failedCpuPoint = cpuState~journalPoint
failedMemPoint = memState~journalPoint
cpFailed = machine~checkpoint("failed future", "SPECULATIVE")

call assertEq cpuState~at("PC"), 4100, "speculative PC"
call assertEq memState~at("2000"), "AA", "speculative memory"

restored = machine~restore(cp0)
call assertTrue restored~ok, "State-of-the-Nation restore"
call assertEq cpuState~at("PC"), 4096, "CPU restored"
call assertEq cpuState~at("ACC"), 0, "ACC restored"
call assertEq memState~at("2000"), "00", "memory restored"

/* New execution forks; the abandoned failed future remains reconstructible. */
cpuState~put("PC", 4104, "REPAIRED")
memState~put("2000", "BB", "REPAIRED")
oldCpu = cpuState~reconstruct(failedCpuPoint)
oldMem = memState~reconstruct(failedMemPoint)
call assertEq oldCpu["PC"], 4100, "abandoned CPU future retained"
call assertEq oldMem["2000"], "AA", "abandoned memory future retained"
call assertEq cpuState~at("PC"), 4104, "new CPU branch active"
call assertEq memState~at("2000"), "BB", "new memory branch active"

nation = machine~stateOfNation
call assertTrue nation["CPU"]~isA(.JournalPoint), "State-of-the-Nation exposes pointer only"
call assertTrue nation["MEM"]~isA(.JournalPoint), "memory pointer only"
call assertTrue machine~checkpointBack(0) == cpFailed, "latest retained checkpoint indexed"
call assertTrue machine~checkpointBack(1) == cp0, "previous retained checkpoint indexed"

watcher = machine~progressWatcher("cpu-loop", 2)
call assertTrue watcher~poll = .false, "first absent progress poll does not yet stall"
call assertTrue watcher~poll = .true, "second unchanged poll identifies stall"
machine~noteProgress("cpu-loop", 1)
call assertTrue watcher~poll = .false, "new progress clears stall observation"

/* Code-forward/state-backward recovery. */
machine2 = .TerminalEmulatorStateMachine~new("TESTBED")
initial = .directory~new
initial["PC"] = 8192
rr = machine2~createComponent("CPU", initial, "REPAIR-CPU")
state2 = rr~value
front = .RepairFrontEnd~new
recovery = .TerminalEmulatorRecoveryCoordinator~new(machine2, front)
worker = .RepairCPU~new
cpRepair = recovery~arm("before missing opcode")
state2~put("PC", 8196, "SPECULATIVE")
fixed = recovery~recover("MISSING_INSTRUCTION", worker, "OPCAFE")
call assertTrue fixed~ok, "marked emulator target repaired"
call assertEq worker~opCafe(20, 22), 42, "new code remains live"
call assertEq state2~at("PC"), 8192, "machine state rewound under new code"

/* Merely looking patchable is not sufficient. */
lookalike = .PatchLookalike~new
state2~put("PC", 8200, "SPECULATIVE-2")
recovery~arm("before denied target")
state2~put("PC", 8204, "SPECULATIVE-3")
denied = recovery~recover("MISSING_INSTRUCTION", lookalike, "DANGER")
call assertTrue \denied~ok, "unmarked patch target denied"
call assertEq denied~code, "TERMINAL_EMULATOR_PATCH_TARGET_DENIED", "target denial code"
call assertEq state2~at("PC"), 8204, "denied patch does not rewind state"

/* A front end cannot smuggle a different unmarked target through response. */
front~overrideTarget(lookalike)
recovery~arm("before override attack")
state2~put("PC", 8208, "SPECULATIVE-4")
overrideDenied = recovery~recover("MISSING_INSTRUCTION", worker, "ANOTHER")
call assertTrue \overrideDenied~ok, "response target override is revalidated"
call assertEq overrideDenied~code, "TERMINAL_EMULATOR_PATCH_TARGET_DENIED", "override denial code"
call assertEq state2~at("PC"), 8208, "override denial leaves speculative branch intact"

/* Live-host mode is not constructible. */
call expectSyntaxLiveMode

if failures > 0 then do
  say "FAIL test_terminal_emulator_journal" failures
  exit 1
end
say "PASS test_terminal_emulator_journal"
exit 0

expectSyntaxLiveMode: procedure expose failures
  signal on syntax name denied
  bad = .TerminalEmulatorStateMachine~new("LIVE_HOST")
  failures += 1
  say "ASSERT FAIL: LIVE_HOST mode unexpectedly constructed"
  return
denied:
  return

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

::class RepairCPU public inherit TerminalEmulatorPatchable

::class RepairFrontEnd public
::method init
  expose override
  override = .nil
::method overrideTarget
  expose override
  use strict arg targetArg
  override = targetArg
::method stateRecoveryRequest
  expose override
  use strict arg request
  if override == .nil then return "use strict arg a,b; return a+b"
  d = .directory~new
  d["target"] = override
  d["methodName"] = request~methodName
  d["source"] = "return 99"
  return d

::class PatchLookalike public
::method installLiveMethod
  use strict arg methodName, source
  self~setMethod(methodName, source, "OBJECT")
  return .true

::requires "TerminalEmulatorJournal.cls"
