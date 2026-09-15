/* A complete IPL loads the PSW only after the final channel command ends. */
iplPsw="0008000000001000"
ccw1="0200020000000004"
ccw2="0000000000000000"
records=.array~of(iplPsw||ccw1||ccw2,"CAFEBABE")
m=.IBM4361Machine~new(1048576)
m~powerOn
d=.IBM370IPLMemoryDevice~new(x2d("148"),records,"COMPLETE-IPL","fixture-v2")
m~attachDevice(d)
m~initialProgramLoad(x2d("148"))
call eq m~storage~fetchHex(512,4),"CAFEBABE","CCW data transfer"
call eq m~cpu~psw~rawHex,iplPsw,"IPL PSW loaded at channel completion"
call eq m~cpu~stopped,0,"CPU started"
call eq m~machinePhase,"GUEST_STARTED","phase"
call eq d~readCount,2,"device record reads"
call eq d~recordIndex,2,"device media position"
call truth \m~channels~hasActiveProgram(x2d("148")),"channel program retired"
say "PASS test_ipl_completion"
exit 0

eq: procedure
  parse arg a,b,label
  if a \== b then do
    say "FAIL" label "expected=" || b || " actual=" || a
    exit 1
  end
  return
truth: procedure
  parse arg ok,label
  if \ok then do
    say "FAIL" label
    exit 1
  end
  return

::requires "IBM4361State.cls"
