call assertTrue .JournalPointedState \== .nil,"class loaded"
initial=.directory~new
initial["A"]=1
s=.JournalPointedState~new(initial,"TEST-JOURNAL")
root=s~rootPoint
call assertEq 1,s~at("A"),"initial value"

p1=s~put("A",2,"first")
p2=s~put("B",9,"second")
call assertEq 2,s~at("A"),"current A"
call assertEq 9,s~at("B"),"current B"
call assertEq 2,s~retainedNodeCount,"two change nodes"

s~moveTo(p1)
call assertEq 2,s~at("A"),"rewind keeps A at p1"
call assertFalse s~hasIndex("B"),"rewind removes B"

s~moveTo(root)
call assertEq 1,s~at("A"),"root reconstructs initial A"

s~moveTo(p2)
call assertEq 2,s~at("A"),"forward restores A"
call assertEq 9,s~at("B"),"forward restores B"

hist=s~reconstruct(p1)
call assertEq 2,hist["A"],"non-mutating reconstruction A"
call assertFalse hist~hasIndex("B"),"non-mutating reconstruction excludes later B"
call assertEq p2~nodeId,s~journalPoint~nodeId,"reconstruct does not move live head"

-- Same-value puts are intentionally journal-free.
p2b=s~put("B",9,"same")
call assertEq p2~nodeId,p2b~nodeId,"same-value put returns current point"
call assertEq 2,s~retainedNodeCount,"same-value put adds no node"

say "PASS test_journal_basic"
exit 0

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
