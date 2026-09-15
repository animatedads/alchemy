state=.JournalPointedState~new(.nil,"CPU-STATE")
state~put("PC",100)
ctl=.StateOfNationController~new
ctl~register("cpu",state)
front=.TestFrontEnd~new
coord=.LiveStateRecoveryCoordinator~new(ctl,front)
target=.InstructionTarget~new

pre=coord~arm("before-op-42")
state~put("PC",104,"speculative-fetch")
failedPoint=state~journalPoint
call assertFalse target~hasMethod("OP42"),"instruction initially missing"

result=coord~recover("MISSING_INSTRUCTION",target,"OP42")
call assertTrue result~installed,"method installed"
call assertTrue target~hasMethod("OP42"),"target now has live method"
call assertEq 100,state~at("PC"),"machine state rewound to pre-instruction point"
call assertEq 42,target~op42(41),"new method executes without restart"

-- Execute the instruction again, producing a new branch from the same point.
state~put("PC",106,"patched-op-retired")
retryPoint=state~journalPoint
call assertEq 3,state~retainedNodeCount,"initial state change plus failed and repaired futures are retained"
failed=state~reconstruct(failedPoint)
retry=state~reconstruct(retryPoint)
call assertEq 104,failed["PC"],"failed speculative future remains inspectable"
call assertEq 106,retry["PC"],"patched future is independently reconstructible"

say "PASS test_live_recovery"
exit 0

::class InstructionTarget public inherit LiveMethodPatchable

::class TestFrontEnd public
::method stateRecoveryRequest
  use strict arg request
  d=.directory~new
  d["source"]="use strict arg value; return value+1"
  d["methodName"]=request~methodName
  d["target"]=request~target
  d["scope"]="OBJECT"
  return d

::routine assertEq
  use strict arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::routine assertTrue
  use strict arg actual,label
  if \actual then raise syntax 88.900 array("ASSERT_TRUE",label)

::routine assertFalse
  use strict arg actual,label
  if actual then raise syntax 88.900 array("ASSERT_FALSE",label)

::requires "src/JournalPointedState.cls"
