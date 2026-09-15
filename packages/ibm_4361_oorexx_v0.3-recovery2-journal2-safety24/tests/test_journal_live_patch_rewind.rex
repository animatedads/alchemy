storage=.IBM370JournaledStorage~new(65536,2048,"PATCH-RAM")
m=.IBM4361Machine~new(65536,storage)
m~powerOn
front=.PatchFrontEnd~new
session=.IBM4361JournalSession~new(m,front)
worker=.PatchWorker~new

session~beginInstruction
m~cpu~setGpr(2,222)
m~storage~storeHex(512,"AABBCCDD")
result=session~recoverInstruction("MISSING_INSTRUCTION",worker,"OPD5")
call truth result~installed,"patch installed"
call eq 0,m~cpu~gpr(2),"CPU speculative write rewound"
call eq "00000000",m~storage~fetchHex(512,4),"RAM speculative write rewound"
call eq 42,worker~opD5(20,22),"new code remains installed"
say "PASS test_journal_live_patch_rewind"
exit 0

eq: procedure
  use arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
  return
truth: procedure
  use arg actual,label
  if \actual then raise syntax 88.900 array("ASSERT_TRUE",label)
  return

::class PatchWorker public inherit LiveMethodPatchable

::class PatchFrontEnd public
::method stateRecoveryRequest
  use arg request
  return "use strict arg a,b; return a+b"

::requires "IBM4361Journal.cls"
