/* Basic object/state nucleus. */
m=.IBM4361Machine~new(1048576)
call eq m~model,"IBM 4361","model"
call eq m~machinePhase,"POWERED_OFF","initial phase"
m~powerOn
call eq m~machinePhase,"OPERATOR_READY","power-on phase"
m~cpu~setGpr(3,123456)
m~storage~storeHex(256,"DEADBEEF")
m~storage~setStorageKeyRaw(0,6)
call eq m~cpu~gpr(3),123456,"GPR"
call eq m~storage~fetchHex(256,4),"DEADBEEF","storage"
call eq m~storage~storageKeyRaw(0),6,"storage key"
say "PASS test_nucleus"
exit 0

eq: procedure
  parse arg a,b,label
  if a \== b then do
    say "FAIL" label "expected=" || b || " actual=" || a
    exit 1
  end
  return

::requires "IBM4361State.cls"
