/* Safe keyboard facade over the existing DTE20 monitor input path. */
numeric digits 30
parse arg statePath
if statePath = "" then do; say "usage: rexx test_console_keyboard.rex prompt.state"; exit 2; end

reader=.KL10State~new
cpu=reader~load(statePath)
console=.KL10Console~new(cpu)
call eq console~hasMethod("CPU"),0,"no CPU getter"
call eq console~hasMethod("DTE"),0,"no DTE getter"
call eq console~keyboard~hasMethod("DTE"),0,"keyboard has no DTE getter"

snap=console~snapshot
call eq snap~terminalType,"DEC-KL10-DTE20","terminal type"
call eq snap~keyboardState,"UNLOCKED","keyboard state"
call eq snap~sessionState,"OPERATOR_WAIT","prompt wait state"
call eq snap~guestWaitingForInput,.true,"guest wait"
call eq snap~queuedInputBytes,0,"empty queue"
call contains snap~visibleText,"BOOT V11.0(315)","banner visible"
call contains snap~visibleText,"MTBOOT>","prompt visible"
call eq snap~rows,4,"stream rows"
call eq snap~rowText(4),"MTBOOT>","prompt row"
caps=snap~capabilities
call eq caps~items,5,"capability count"

oldToken=snap~stateToken
r=console~keyboard~type("N",oldToken)
call eq r~ok,.true,"type N"
call eq cpu~dte~rxHex,"4E","N queued architecturally"
call neq r~stateToken,oldToken,"token changes on queue"
stale=console~keyboard~press("ENTER",oldToken)
call eq stale~ok,.false,"stale rejected"
call eq stale~code,"STALE_STATE","stale code"
call eq cpu~dte~rxHex,"4E","stale did not queue"

p=console~pump(4,"STEPS")
call eq p~ok,.true,"four-step pump"
call eq p~steps,4,"four steps"
call eq cpu~accumulator(5),c2d("N"),"MTBOOT consumed N"
call eq cpu~dte~rxHex,"","queue consumed"

/* Named/control keys use explicit 7-bit values and BREAK is not fabricated. */
cpu2=.KL10State~new~load(statePath)
c2=.KL10Console~new(cpu2)
r=c2~keyboard~control("C",c2~snapshot~stateToken)
call eq r~ok,.true,"control C"
call eq cpu2~dte~rxHex,"03","control C byte"

cpu3=.KL10State~new~load(statePath)
c3=.KL10Console~new(cpu3)
r=c3~keyboard~press("RUBOUT",c3~snapshot~stateToken)
call eq r~ok,.true,"rubout"
call eq cpu3~dte~rxHex,"7F","rubout byte"

cpu4=.KL10State~new~load(statePath)
c4=.KL10Console~new(cpu4)
r=c4~keyboard~press("BREAK",c4~snapshot~stateToken)
call eq r~ok,.false,"break rejected"
call eq r~code,"UNSUPPORTED_SIGNAL_KEY","break explicit boundary"
call eq cpu4~dte~rxHex,"","break did not invent bytes"

say "PASS test_console_keyboard"
exit 0

eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
neq: procedure
 use arg a,e,l
 if a = e then do; say "FAIL" l "unexpected="e; exit 1; end
 return
contains: procedure
 use arg hay,needle,l
 if pos(needle,hay)=0 then do; say "FAIL" l "missing="needle; exit 1; end
 return
::requires "../KL10Console.cls"
