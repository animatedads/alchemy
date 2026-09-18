/* Terminal Machine v0.19 journal-pointed emulator repair example. */
machine = .TerminalEmulatorStateMachine~new("EMULATOR")
initial = .directory~new
initial["PC"] = 4096
created = machine~createComponent("CPU", initial, "EXAMPLE-CPU")
if \created~ok then do
  say created~code created~detail
  exit 1
end
state = created~value
cpu = .ExampleCPU~new
front = .ExampleFrontEnd~new
recovery = .TerminalEmulatorRecoveryCoordinator~new(machine, front)

checkpoint = recovery~arm("before opcode CAFE")
state~put("PC", 4100, "SPECULATIVE")
result = recovery~recover("MISSING_INSTRUCTION", cpu, "OPCAFE")
if \result~ok then do
  say result~code result~detail
  exit 2
end

say "retry result:" cpu~opCafe(20, 22)
say "PC after recovery:" state~at("PC")
say "retained nodes:" state~retainedNodeCount

::class ExampleCPU public inherit TerminalEmulatorPatchable

::class ExampleFrontEnd public
::method stateRecoveryRequest
  use strict arg request
  say "repair requested:" request~reason request~methodName
  return "use strict arg a,b; return a+b"

::requires "TerminalEmulatorJournal.cls"
