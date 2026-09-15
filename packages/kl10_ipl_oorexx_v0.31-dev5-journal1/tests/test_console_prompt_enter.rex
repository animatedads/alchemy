/* The saved MTBOOT prompt accepts a real CR through DTE20.  Execution then
 * reaches the next honest CPU boundary; the console facade reports it rather
 * than claiming a completed command. */
numeric digits 30
parse arg statePath
if statePath = "" then do; say "usage: rexx test_console_prompt_enter.rex prompt.state"; exit 2; end
cpu=.KL10State~new~load(statePath)
console=.KL10Console~new(cpu)
token=console~snapshot~stateToken
r=console~keyboard~press("ENTER",token)
call eq r~ok,.true,"queue ENTER"
call eq cpu~dte~rxHex,"0D","CR queued"

p=console~pump(200,"WAIT")
call eq p~ok,.false,"bounded machine reaches unattached hardware boundary"
call eq p~reason,"EXECUTION_REFUSED","refusal reason"
call eq p~steps,102,"ENTER processing steps to RH20 boundary"
call eq p~outputDeltaHex,"0D0D0A","MTBOOT CR plus line transition"
call contains p~conditionMessage,"352","first RH20 device code"
call eq cpu~pc,oct("772646"),"refused RH20 CONO PC"
proposal=cpu~preview
call eq proposal["mnemonic"],"CONO","RH20 boundary mnemonic"
call eq proposal["deviceName"],"RH20","RH20 boundary device"
call eq proposal["device"],oct("540"),"RH20 boundary code"
call eq proposal["effectiveAddress"],oct("2000"),"RH20 CLR MBC control"
call eq cpu~dte~rxHex,"","CR consumed before hardware boundary"
call eq p~snapshot~sessionState,"EXECUTION_REFUSED","snapshot refusal state"

say "PASS test_console_prompt_enter"
exit 0

oct: procedure
 use arg t
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
contains: procedure
 use arg hay,needle,l
 if pos(needle,hay)=0 then do; say "FAIL" l "missing="needle "in="hay; exit 1; end
 return
::requires "../KL10Console.cls"
