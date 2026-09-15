numeric digits 30
/* Historical AF invocation microstate from real MVT after the proven UNPK
 * retry.  Only fields actually observed/proved are asserted here: IA,
 * instruction bytes, instruction count, and reset-zero CR8.  This is not a
 * synthetic substitute for a whole-machine guest replay. */
storage=.IBM370JournaledStorage~new(2097152,2048,'MC-TRIAL-RAM')
m=.IBM4361Machine~new(2097152,storage)
m~powerOn
m~cpu~loadIPLPSW('0000000000016606')
m~cpu~psw~setConditionCode(3)
cs=m~cpu~state
cs['instructionCount']=511776
m~cpu~restoreState(cs)
m~storage~storeHex(x2d('016606'),'AF030FFF4703')
session=.IBM4361JournalSession~new(m)

call eq 0,m~cpu~cr(8),'CR8 reset mask'
call eq 'OK',m~executor~step,'permanent masked baseline'
call eq x2d('01660A'),m~cpu~psw~instructionAddress,'permanent baseline next IA'
call eq 511777,m~cpu~instructionCount,'permanent baseline IC'
/* Restore the observed invocation before exercising object-scope overrides. */
m~cpu~loadIPLPSW('0000000000016606')
m~cpu~psw~setConditionCode(3)
cs=m~cpu~state; cs['instructionCount']=511776; m~cpu~restoreState(cs)

/* Candidate A is intentionally narrow: it replays the historical reset-mask
 * case through an object-scope override after permanent promotion.  Code itself is outside the architectural journal, so it must
 * survive abort/retry while CR8/RAM/PSW rewind. */
sourceA="expose cpu; use strict arg i,ia,t=0; f=self~siFields(i); imm=f[1]; if imm % 16 <> 0 then raise syntax 40.900 array('MC reserved bits 8-11 nonzero'); class=imm//16; if cpu~cr(8)=0 then return ia+4; raise syntax 40.900 array('MC candidate A only proves reset-zero monitor mask',class)"
session~beginInstruction
call truth m~executor~installLiveMethod('OPAF',sourceA),'candidate A installed'
m~cpu~setCr(8,x2d('1000'))
m~cpu~setGpr(1,111)
m~storage~storeHex(x2d('180000'),'AABBCCDD')
session~abortInstruction
call eq 0,m~cpu~cr(8),'CR8 rewound after insertion'
call eq 0,m~cpu~gpr(1),'GPR rewound after insertion'
call eq '00000000',m~storage~fetchHex(x2d('180000'),4),'RAM rewound after insertion'
call eq 'OK',m~executor~step,'candidate A retry'
call eq x2d('01660A'),m~cpu~psw~instructionAddress,'candidate A next IA'
call eq 511777,m~cpu~instructionCount,'candidate A IC'
call eq 3,m~cpu~psw~conditionCode,'candidate A CC unchanged'

/* Replace A in place with the actual class-selective mask interpretation.
 * Rewind the architectural invocation and prove that B, not A, executes. */
m~cpu~loadIPLPSW('0000000000016606')
m~cpu~psw~setConditionCode(3)
cs=m~cpu~state
cs['instructionCount']=511776
m~cpu~restoreState(cs)
sourceB="expose cpu; use strict arg i,ia,t=0; f=self~siFields(i); imm=f[1]; if imm % 16 <> 0 then raise syntax 40.900 array('MC reserved bits 8-11 nonzero'); class=imm//16; weight=32768 % (2**class); enabled=(cpu~cr(8) % weight)//2; if enabled=0 then return ia+4; raise syntax 40.900 array('MC monitor event deliberately fail-closed in live trial',class)"
session~beginInstruction
call truth m~executor~installLiveMethod('OPAF',sourceB),'candidate B replaced A'
m~cpu~setCr(8,x2d('8000')) /* class 0 only; class 3 remains masked */
m~cpu~setGpr(2,222)
session~abortInstruction
call eq 0,m~cpu~cr(8),'CR8 rewound after replacement'
call eq 0,m~cpu~gpr(2),'GPR rewound after replacement'
call eq 'OK',m~executor~step,'candidate B exact retry'
call eq x2d('01660A'),m~cpu~psw~instructionAddress,'candidate B next IA'
call eq 511777,m~cpu~instructionCount,'candidate B IC'
call eq 3,m~cpu~psw~conditionCode,'candidate B CC unchanged'

/* Show that candidate B really is the replacement by selecting class 3.
 * The unimplemented interrupt path must fail closed rather than silently
 * behaving as a no-op. */
m~cpu~loadIPLPSW('0000000000016606')
m~cpu~setCr(8,x2d('1000'))
signal on syntax name expected_enabled
st=m~executor~step
say 'FAIL enabled class 3 did not fail closed status='st
exit 1
expected_enabled:
signal off syntax
say 'PASS test_mvt_mc_live_journal_trial'
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
