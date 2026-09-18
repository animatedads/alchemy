/* v0.21 instruction orchestration demo: missing opcode -> rollback -> repair -> retry. */
machine = .TerminalEmulatorStateMachine~new("EMULATOR")
regs = .directory~new
regs["PC"] = 4096
created = machine~createComponent("CPU", regs, "DEMO-CPU")
if \created~ok then raise syntax 88.900 array(created~code, created~detail)
cpu = created~value

pipeline = .DemoInstructionPipeline~new(cpu)
orchestrator = .TerminalEmulatorEventOrchestrator~new(machine, 16)

failed = orchestrator~runInstruction("OP-42", pipeline)
say "first ok:" failed~ok "code:" failed~code "PC:" cpu~at("PC")
failedId = orchestrator~lastEventId

/* A real emulator could use TerminalEmulatorRecoveryCoordinator here.  This
 * example flips the synthetic implementation flag to keep the focus on event
 * orchestration and retry lineage. */
pipeline~installOpcode
retried = orchestrator~retryInstruction(failedId, pipeline, .nil, "PC=4100")
say "retry ok:" retried~ok "PC:" cpu~at("PC")

say "history:"
do entry over orchestrator~history
  say entry~eventId entry~kind entry~name entry~outcome "retryOf="entry~retryOfEventId
  say "  phases:" entry~phases~makeString("L", ", ")
end
exit 0

::class DemoInstructionPipeline public inherit TerminalEmulatorInstructionPipeline
::method init
  expose cpu installed
  use strict arg cpuArg
  cpu = cpuArg
  installed = .false

::method installOpcode
  expose installed
  installed = .true
  return self

::method emulatorFetch
  use strict arg event, context
  return "42"

::method emulatorDecode
  use strict arg event, fetched, context
  return "ADVANCE-PC"

::method emulatorExecute
  expose cpu installed
  use strict arg event, decoded, context
  cpu~put("PC", cpu~at("PC") + 4, "EXECUTE-" || event~eventId)
  if \installed then return .TerminalResult~failure("OPCODE_MISSING", "synthetic opcode 42 is not installed")
  return cpu~at("PC")

::requires "TerminalEmulatorOrchestration.cls"
