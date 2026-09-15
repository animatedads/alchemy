/* Object-scope method removal is executable-hypothesis state, not machine state. */
numeric digits 30
storage=.IBM370JournaledStorage~new(65536,2048,'REMOVE-METHOD-RAM')
m=.IBM4361Machine~new(65536,storage)
m~powerOn
m~cpu~loadIPLPSW('0000000000000100')
m~storage~storeHex(x2d('100'),'1412')
m~cpu~setGpr(1,x2d('F0F0F0F0')); m~cpu~setGpr(2,x2d('0F0F0F0F'))
session=.IBM4361JournalSession~new(m)

/* Install a deliberately wrong object override of permanent OP14. */
source="expose cpu; numeric digits 30; use strict arg i,ia,t=0; cpu~setGprFast(1,x2d('DEADBEEF')); cpu~psw~setConditionCode(3); return ia+2"
call truth m~executor~installLiveMethod('OP14',source),'install override'
st=m~executor~step
call eq 'OK',st,'override status'
call eq 'DEADBEEF',d2x(m~cpu~gpr(1),8),'override active'

/* Restore the instruction state, remove the override under a journal event,
 * dirty machine state, then abort.  Removal must survive while machine dirt
 * rewinds. */
m~cpu~loadIPLPSW('0000000000000100')
m~cpu~setGpr(1,x2d('F0F0F0F0')); m~cpu~setGpr(2,x2d('0F0F0F0F'))
session~beginInstruction
call truth m~executor~removeLiveMethod('OP14'),'remove override'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('300'),'A55A')
session~abortInstruction
call eq '00000000',d2x(m~cpu~gpr(5),8),'GPR dirt rewound'
call eq '0000',m~storage~fetchHex(x2d('300'),2),'RAM dirt rewound'

/* Dispatch must now fall through to permanent class OP14. */
st=m~executor~step
call eq 'OK',st,'permanent fallback status'
call eq '00000000',d2x(m~cpu~gpr(1),8),'permanent OP14 result'
call eq 0,m~cpu~psw~conditionCode,'permanent OP14 cc'

say 'PASS test_executor_live_method_removal'
exit 0

eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
truth: procedure
  use arg x,label
  if \x then do; say 'FAIL' label; exit 1; end
return
::requires 'IBM4361Journal.cls'
