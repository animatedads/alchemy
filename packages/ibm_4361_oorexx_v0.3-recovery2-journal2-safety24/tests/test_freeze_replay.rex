/* Completed-machine architectural freeze -> fresh load -> byte-identical state. */
statePath="/tmp/ibm4361-v02.state"
iplPsw="0008000000001000"
ccw1="0200020000000004"
ccw2="0000000000000000"
records=.array~of(iplPsw||ccw1||ccw2,"CAFEBABE")
m=.IBM4361Machine~new(1048576)
m~powerOn
d=.IBM370IPLMemoryDevice~new(x2d("148"),records,"TEST-IPL","fixture-v2")
m~attachDevice(d)
m~initialProgramLoad(x2d("148"))
m~cpu~setGpr(7,777)
m~storage~storeHex(640,"1122334455667788")
m~storage~setStorageKeyRaw(0,14)
m~clock~setTodHex("0123456789ABCDEF")
state=.IBM4361State~new
f=state~freeze(m)
call truth f~recordCount>40,"nontrivial state"
f~save(statePath)

m~cpu~setGpr(7,999)
m~storage~storeHex(640,"FFFFFFFFFFFFFFFF")
m~clock~setTodHex("FFFFFFFFFFFFFFFF")

r=state~load(statePath)
call eq r~cpu~gpr(7),777,"GPR restored"
call eq r~storage~fetchHex(640,8),"1122334455667788","storage restored"
call eq r~storage~storageKeyRaw(0),14,"storage key restored"
call eq r~clock~todHex,"0123456789ABCDEF","TOD restored without host-time jump"
call eq r~cpu~psw~rawHex,iplPsw,"PSW restored"
call eq r~channels~device(x2d("148"))~readCount,2,"device state restored"
call eq r~channels~device(x2d("148"))~recordIndex,2,"media position restored"
call eq state~freeze(r)~encoded,f~encoded,"fresh-machine state is byte-identical"
call sysFileDelete statePath
say "PASS test_freeze_replay"
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
