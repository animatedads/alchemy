failures = 0

machine = .TerminalEmulatorStateMachine~new("EMULATOR")
regs = .directory~new
regs["PC"] = 4096
mem = .directory~new
mem["2000"] = "00"
rc = machine~createComponent("CPU", regs, "TIMELINE-CPU")
call assertTrue rc~ok, "CPU create"
cpu = rc~value
rc = machine~createComponent("MEM", mem, "TIMELINE-MEM")
call assertTrue rc~ok, "MEM create"
memory = rc~value

cp0 = machine~checkpoint("before", "INSTRUCTION")
cpu~put("PC", 4100, "FETCH")
memory~put("2000", "AA", "STORE")
meta1 = .directory~new
meta1["phase"] = "speculative"
meta1["authorityLike"] = .directory~new
cp1 = machine~checkpoint("speculative-1", "INSTRUCTION", meta1)
cpu~put("PC", 4200, "NEXT")
cp2 = machine~checkpoint("speculative-2", "INSTRUCTION")

timeline = machine~timeline
summary = timeline~checkpoint(cp1~checkpointId)
call assertTrue summary~ok, "checkpoint evidence by id"
evidence = summary~value
call assertEq evidence~checkpointId, cp1~checkpointId, "checkpoint evidence id"
call assertEq evidence~label, "speculative-1", "checkpoint evidence label"
call assertEq evidence~componentCount, 2, "checkpoint component count"
safeMeta = evidence~metadata
call assertEq safeMeta["phase"], "speculative", "string checkpoint metadata retained"
call assertEq safeMeta["authorityLike"], "<OBJECT>", "object checkpoint metadata not exported"

material = timeline~materialise(cp1)
call assertTrue material~ok, "materialise old checkpoint"
states = material~value
call assertEq states["CPU"]["PC"], 4100, "materialised CPU value"
call assertEq states["MEM"]["2000"], "AA", "materialised memory value"
call assertEq cpu~at("PC"), 4200, "materialise does not move current CPU head"

forward = timeline~branch(cp0, cp1)
call assertTrue forward~ok, "forward branch evidence"
fb = forward~value
call assertEq fb~fromCheckpointId, cp0~checkpointId, "forward from id"
call assertEq fb~toCheckpointId, cp1~checkpointId, "forward to id"
call assertEq fb~undoNodeCount, 0, "forward undo node count"
call assertEq fb~redoNodeCount, 2, "forward redo node count"
plans = fb~componentPlans
call assertEq plans["CPU"]["redoCount"], 1, "CPU one redo"
call assertEq plans["MEM"]["redoCount"], 1, "MEM one redo"
call assertEq plans["CPU"]["redo"][1]["changedKeys"][1], "PC", "CPU structural key evidence"
call assertTrue \plans["CPU"]["redo"][1]~hasIndex("oldValue"), "branch evidence omits old value"
call assertTrue \plans["CPU"]["redo"][1]~hasIndex("newValue"), "branch evidence omits new value"

/* Returned branch plans are detached copies rather than mutable evidence internals. */
plans["CPU"]["redo"][1]["tag"] = "TAMPERED"
plansAgain = fb~componentPlans
call assertEq plansAgain["CPU"]["redo"][1]["tag"], "FETCH", "branch evidence resists caller mutation"

reverse = timeline~branch(cp1, cp0)
call assertTrue reverse~ok, "reverse branch evidence"
rb = reverse~value
call assertEq rb~undoNodeCount, 2, "reverse undo node count"
call assertEq rb~redoNodeCount, 0, "reverse redo node count"

/* Fork from cp0 and prove the abandoned old future remains inspectable. */
restored = machine~restore(cp0)
call assertTrue restored~ok, "restore for fork"
cpu~put("PC", 4300, "FORK")
cpFork = machine~checkpoint("repaired-fork", "INSTRUCTION")

cross = timeline~branch(cp2, cpFork)
call assertTrue cross~ok, "cross-branch evidence"
cb = cross~value
call assertEq cb~undoNodeCount, 3, "cross branch undoes old CPU and memory paths"
call assertEq cb~redoNodeCount, 1, "cross branch redoes fork"

oldFuture = timeline~materialise(cp2)
call assertTrue oldFuture~ok, "abandoned old future still materialisable"
call assertEq oldFuture~value["CPU"]["PC"], 4200, "old future CPU reconstructed"
call assertEq cpu~at("PC"), 4300, "old-future inspection leaves fork current"

missing = timeline~checkpoint("SOTN-999999")
call assertTrue \missing~ok, "unknown checkpoint denied"
call assertEq missing~code, "TERMINAL_JOURNAL_CHECKPOINT_NOT_FOUND", "unknown checkpoint code"

if failures > 0 then do
  say "FAIL test_terminal_emulator_timeline" failures
  exit 1
end
say "PASS test_terminal_emulator_timeline"
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

::requires "TerminalEmulatorJournal.cls"
