/* Freeze in the middle of an IPL channel program and resume on a fresh machine. */
path="/tmp/ibm4361-v02-active-channel.state"
iplPsw="0008000000001000"
ccw1="0200020040000020"  /* read 32 bytes to 0x200, command chain */
ccw2="0200022000000010"  /* read 16 bytes to 0x220, end chain */
r1=iplPsw||ccw1||ccw2
r2=copies("AA",32)
r3=copies("BB",16)
records=.array~of(r1,r2,r3)

m=.IBM4361Machine~new(1048576)
m~powerOn
d=.IBM370IPLMemoryDevice~new(x2d("148"),records,"ACTIVE-CHANNEL","fixture-v2")
m~attachDevice(d)
m~beginInitialProgramLoad(x2d("148"))
m~stepInitialProgramLoad
call eq m~machinePhase,"IPL_IN_PROGRESS","still IPL after CCW1"
call eq m~channels~activeProgram(x2d("148"))~currentCCWAddress,16,"pending CCW2"
call eq m~storage~fetchHex(512,32),r2,"CCW1 data"
call eq d~recordIndex,2,"media position after CCW1"

state=.IBM4361State~new
mid=state~freeze(m)
mid~save(path)
r=state~load(path)
call eq r~machinePhase,"IPL_IN_PROGRESS","fresh machine phase"
call eq r~channels~activeProgram(x2d("148"))~currentCCWAddress,16,"fresh pending CCW2"
call eq r~channels~device(x2d("148"))~recordIndex,2,"fresh media position"
call eq state~freeze(r)~encoded,mid~encoded,"mid-channel round trip"

/* Continue both branches from exactly the same state and demand convergence. */
m~stepInitialProgramLoad
r~stepInitialProgramLoad
call eq m~storage~fetchHex(544,16),r3,"original CCW2 data"
call eq r~storage~fetchHex(544,16),r3,"replayed CCW2 data"
call eq m~cpu~psw~rawHex,iplPsw,"original PSW"
call eq r~cpu~psw~rawHex,iplPsw,"replayed PSW"
call eq state~freeze(r)~encoded,state~freeze(m)~encoded,"post-replay machine convergence"
call sysFileDelete path
say "PASS test_ipl_channel_replay"
exit 0

eq: procedure
  parse arg a,b,label
  if a \== b then do
    say "FAIL" label "expected=" || b || " actual=" || a
    exit 1
  end
  return

::requires "IBM4361State.cls"
