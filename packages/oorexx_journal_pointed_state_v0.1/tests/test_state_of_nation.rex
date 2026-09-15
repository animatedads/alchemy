cpu=.JournalPointedState~new(.nil,"CPU")
mem=.JournalPointedState~new(.nil,"MEM")
ctl=.StateOfNationController~new
ctl~register("cpu",cpu)
ctl~register("memory",mem)

cpu~put("PC",100)
mem~put(100,170)
cp0=ctl~checkpoint("before-instruction","INSTRUCTION")

cpu~put("PC",104)
mem~put(101,187)
cp1=ctl~checkpoint("after-instruction","INSTRUCTION")

ctl~restore(cp0)
call assertEq 100,cpu~at("PC"),"global restore CPU"
call assertFalse mem~hasIndex(101),"global restore memory"
call assertEq 170,mem~at(100),"global restore keeps earlier memory"

ctl~restore(cp1)
call assertEq 104,cpu~at("PC"),"global forward CPU"
call assertEq 187,mem~at(101),"global forward memory"

ctl~setCheckpointPolicy("ANY_CHANGE")
before=ctl~checkpointCount
cpu~put("R2",7,"register-write")
call assertEq before+1,ctl~checkpointCount,"any-change automatically checkpoints"

ctl~setCheckpointPolicy("EVENT","instruction-retired")
before=ctl~checkpointCount
ctl~noteEvent("other-event")
call assertEq before,ctl~checkpointCount,"unmatched fixed event does not checkpoint"
ctl~noteEvent("instruction-retired")
call assertEq before+1,ctl~checkpointCount,"matched fixed event checkpoints"

say "PASS test_state_of_nation"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::routine assertFalse
  use strict arg actual,label
  if actual then raise syntax 88.900 array("ASSERT_FALSE",label)

::requires "src/JournalPointedState.cls"
