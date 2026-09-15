/* Minimal shape of the intended emulator repair loop. */
state=.JournalPointedState~new(.nil,"demo-cpu")
state~put("PC",4096)
controller=.StateOfNationController~new
controller~register("cpu",state)
front=.DemoFrontEnd~new
recovery=.LiveStateRecoveryCoordinator~new(controller,front)
cpu=.DemoCPU~new

checkpoint=recovery~arm("instruction 0x1000")
state~put("PC",4100,"fetch")
if \cpu~hasMethod("OPCAFE") then recovery~recover("MISSING_INSTRUCTION",cpu,"OPCAFE")
say "retry result:" cpu~opCafe(20,22)
say "PC after recovery:" state~at("PC")

::class DemoCPU public inherit LiveMethodPatchable

::class DemoFrontEnd public
::method stateRecoveryRequest
  use strict arg request
  say "front end asked to repair" request~reason request~methodName
  return "use strict arg a,b; return a+b"

::requires "src/JournalPointedState.cls"
