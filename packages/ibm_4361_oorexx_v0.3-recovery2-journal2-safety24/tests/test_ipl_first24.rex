/* The implied Read IPL CCW deposits 24 bytes, but the PSW is not loaded until
 * the chained IPL channel program has completed. */
iplPsw="0008000000001000"
ccw1="0200020000000004"
ccw2="0000000000000000"
first=iplPsw||ccw1||ccw2
records=.array~of(first,"CAFEBABE")
m=.IBM4361Machine~new(1048576)
m~powerOn
d=.IBM370IPLMemoryDevice~new(x2d("148"),records,"TEST-IPL","fixture-v2")
m~attachDevice(d)
m~beginInitialProgramLoad(x2d("148"))
call eq m~storage~fetchHex(0,24),first,"low core first record"
call eq m~cpu~psw~rawHex,"0000000000000000","PSW remains reset while channel active"
call eq m~cpu~stopped,1,"CPU remains stopped"
call eq m~machinePhase,"IPL_IN_PROGRESS","phase"
call eq m~channels~activeProgram(x2d("148"))~currentCCWAddress,8,"next CCW"
call eq d~readCount,1,"implied Read IPL count"
call eq d~recordIndex,1,"media record position"
say "PASS test_ipl_first24"
exit 0

eq: procedure
  parse arg a,b,label
  if a \== b then do
    say "FAIL" label "expected=" || b || " actual=" || a
    exit 1
  end
  return

::requires "IBM4361State.cls"
