/* Terminal Machine v0.20 time-travel/debugger example. */
machine = .TerminalEmulatorStateMachine~new("EMULATOR")
initial = .directory~new
initial["PC"] = 4096
created = machine~createComponent("CPU", initial, "DEBUG-CPU")
if \created~ok then do
  say created~code created~detail
  exit 1
end
cpu = created~value
boundary = .TerminalEmulatorExecutionBoundary~new(machine)
timeline = machine~timeline

attempt = boundary~begin("OPCAFE", "before opcode CAFE")
if \attempt~ok then do
  say attempt~code attempt~detail
  exit 2
end
ticket = attempt~value
cpu~put("PC", 4100, "FETCH")
failed = machine~checkpoint("failed future", "FAULT")

rolled = boundary~rollback(ticket, "missing opcode")
if \rolled~ok then do
  say rolled~code rolled~detail
  exit 3
end

retry = boundary~begin("OPCAFE", "retry opcode CAFE")
cpu~put("PC", 4104, "REPAIRED")
boundary~commit(retry~value, "PC=4104")
repaired = machine~checkpoint("repaired future", "COMMIT")

branch = timeline~branch(failed, repaired)
if \branch~ok then do
  say branch~code branch~detail
  exit 4
end
evidence = branch~value
say "failed checkpoint:" evidence~fromCheckpointId
say "repaired checkpoint:" evidence~toCheckpointId
say "undo nodes:" evidence~undoNodeCount "redo nodes:" evidence~redoNodeCount

oldState = timeline~materialise(failed)
newState = timeline~materialise(repaired)
say "failed PC:" oldState~value["CPU"]["PC"]
say "repaired PC:" newState~value["CPU"]["PC"]
say "current PC:" cpu~at("PC")

::requires "TerminalEmulatorJournal.cls"
