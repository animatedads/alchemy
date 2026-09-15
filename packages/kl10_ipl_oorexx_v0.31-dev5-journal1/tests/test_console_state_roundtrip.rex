/* Keyboard queue remains ordinary KL10_DTE_STATE/4 architectural state; the
 * console facade adds no hidden serialization state. */
numeric digits 30
parse arg statePath
if statePath = "" then do; say "usage: rexx test_console_state_roundtrip.rex prompt.state"; exit 2; end
reader=.KL10State~new
cpu=reader~load(statePath)
console=.KL10Console~new(cpu)
r=console~keyboard~type("AB",console~snapshot~stateToken)
call eq r~ok,.true,"queue AB"
call eq cpu~dte~rxHex,"4142","architectural RX"

out=statePath || ".console-roundtrip.tmp"
writer=.KL10State~new
ignored=writer~save(cpu,out,reader~metadata)
verify=.KL10State~new~load(out)
call eq verify~dte~rxHex,"4142","reloaded RX"
view=.KL10Console~new(verify)~snapshot
call eq view~queuedInputBytes,2,"snapshot count"
call eq pos("AB",view~visibleText),0,"pending input not exposed as output"
call sysFileDelete out
say "PASS test_console_state_roundtrip"
exit 0

eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10Console.cls"
