/* TIC changes channel-program control flow without touching the device. */
iplPsw="0008000000001000"
tic="0800002000000000"
filler="0000000000000000"
records=.array~of(iplPsw||tic||filler,"11223344")
m=.IBM4361Machine~new(1048576)
m~powerOn
d=.IBM370IPLMemoryDevice~new(x2d("148"),records,"TIC-IPL","fixture-v2")
m~attachDevice(d)
/* Target CCW at absolute X'20'. */
m~storage~storeHex(32,"0200030000000004")
m~beginInitialProgramLoad(x2d("148"))
m~stepInitialProgramLoad
call eq m~channels~activeProgram(x2d("148"))~currentCCWAddress,32,"TIC target"
call eq d~recordIndex,1,"TIC performs no device transfer"
m~stepInitialProgramLoad
call eq m~storage~fetchHex(768,4),"11223344","target read"
call eq m~machinePhase,"GUEST_STARTED","IPL completed"
say "PASS test_tic"
exit 0

eq: procedure
  parse arg a,b,label
  if a \== b then do
    say "FAIL" label "expected=" || b || " actual=" || a
    exit 1
  end
  return

::requires "IBM4361State.cls"
