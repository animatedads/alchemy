s=.JournalPointedState~new(.nil,"BRANCH-JOURNAL")
p0=s~journalPoint
p1=s~put("PC",100,"boot")
p2=s~put("PC",104,"failed-speculation")
failed=s~journalPoint

s~moveTo(p1)
edit=s~beginEdit("patched-retry")
edit~put("PC",106)
edit~put("R1",42)
retry=edit~commit

call assertEq 3,s~retainedNodeCount,"old future retained plus new branch"
call assertEq 106,s~at("PC"),"retry branch is active"
call assertEq 42,s~at("R1"),"batched register update"

old=s~reconstruct(failed)
call assertEq 104,old["PC"],"failed future still reconstructible"
call assertFalse old~hasIndex("R1"),"failed future does not see patched branch register"

fresh=s~reconstruct(retry)
call assertEq 106,fresh["PC"],"retry future reconstructible"
call assertEq 42,fresh["R1"],"retry future register reconstructible"

d=s~diff(failed,retry)
call assertEq 1,d["undo"]~items,"branch diff backs out failed node"
call assertEq 1,d["redo"]~items,"branch diff applies retry node"

say "PASS test_branching"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::routine assertFalse
  use strict arg actual,label
  if actual then raise syntax 88.900 array("ASSERT_FALSE",label)

::requires "src/JournalPointedState.cls"
