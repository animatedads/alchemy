/* Safety8: exact BAL alias microstate used to validate live insertion + rewind
 * before permanent OP45 promotion. */
numeric digits 30
ram=.IBM370JournaledStorage~new(1048576,2048,'BAL-TRIAL-RAM')
m=.IBM4361Machine~new(1048576,ram)
m~powerOn
m~cpu~loadIPLPSW('00040000B0018984')
m~cpu~setGpr(10,x2d('00018980'))
cs=m~cpu~state; cs['instructionCount']=511781; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('018984'),'45A0A0EA')
s=.IBM4361JournalSession~new(m)
pre=m~cpu~state

s~beginInstruction
st=m~executor~step
call eq 'OK',st,'old BAL executes'
call eq x2d('018A72'),m~cpu~psw~instructionAddress,'old BAL reproduces alias defect'
s~abortInstruction
call eq x2d('018984'),m~cpu~psw~instructionAddress,'rewind old BAL IA'
call eq x2d('00018980'),m~cpu~gpr(10),'rewind old BAL R10'
call eq 511781,m~cpu~instructionCount,'rewind old BAL IC'

source="expose cpu; numeric digits 30; use strict arg i,ia,t=0; r=x2d(i~substr(3,1)); x=x2d(i~substr(4,1)); b=x2d(i~substr(5,1)); d=x2d(i~substr(6,3)); target=d; if x<>0 then target=target+cpu~gprFast(x); if b<>0 then target=target+cpu~gprFast(b); target=target//16777216; high=128+cpu~psw~conditionCode*16+cpu~psw~programMask; cpu~setGprFast(r,high*16777216+((ia+4)//16777216)); return target"
s~beginInstruction
call truth m~executor~installLiveMethod('OP45',source),'OP45 live insertion'
m~cpu~setGpr(0,x2d('DEADBEEF'))
m~storage~storeHex(x2d('1000'),'AABBCCDD')
s~abortInstruction
/* R0 was not initialized in this microstate: rewind must restore zero. */
call eq 0,m~cpu~gpr(0),'journal restored dirtied GPR'
call eq '00000000',m~storage~fetchHex(x2d('1000'),4),'journal restored dirtied RAM'
call truth m~executor~hasMethod('OP45'),'live OP45 survives rewind'

s~beginInstruction
st=m~executor~step
s~commitInstruction
call eq 'OK',st,'live BAL retry status'
call eq x2d('018A6A'),m~cpu~psw~instructionAddress,'live BAL uses old base value'
call eq x2d('B0018988'),m~cpu~gpr(10),'live BAL link'
call eq 511782,m~cpu~instructionCount,'live BAL IC'

say 'PASS test_cpu_bal_live_journal_trial'
exit 0

eq: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
truth: procedure
  use arg actual,label
  if \actual then do; say 'FAIL' label; exit 1; end
return

::requires 'IBM4361Journal.cls'
