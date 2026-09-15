numeric digits 30
storage=.IBM370JournaledStorage~new(65536,2048,'LIVE-METHOD-RAM')
m=.IBM4361Machine~new(65536,storage)
m~powerOn
m~cpu~loadIPLPSW('0000000000000100')
m~storage~storeHex(x2d('100'),'4C000000')
session=.IBM4361JournalSession~new(m)

/* Unsupported dispatch is atomic before any patch exists. */
st=m~executor~step
call eq 'UNSUPPORTED',st,'pre-patch unsupported'
call eq x2d('100'),m~cpu~psw~instructionAddress,'unsupported IA unchanged'
call eq 0,m~cpu~instructionCount,'unsupported IC unchanged'

/* Install a method while an instruction checkpoint is active, then rewind.
 * The machine state returns to the checkpoint; object-scope executable code
 * intentionally does not, so the trial remains available for exact retry. */
source1="expose cpu; use strict arg i,ia,t=0; cpu~setGprFast(1,111); return ia+4"
session~beginInstruction
call truth m~executor~installLiveMethod('OP4C',source1),'first live method installed'
m~cpu~setGpr(2,222)
m~storage~storeHex(x2d('300'),'AABBCCDD')
session~abortInstruction
call eq 0,m~cpu~gpr(2),'CPU rewind after insertion'
call eq '00000000',m~storage~fetchHex(x2d('300'),4),'RAM rewind after insertion'
st=m~executor~step
call eq 'OK',st,'first live retry status'
call eq 111,m~cpu~gpr(1),'first live method executed'

/* Rewind to the original architectural state and replace the same object
 * method in-place.  Re-installing the same name is a replacement, not a
 * second dispatch entry. */
m~cpu~loadIPLPSW('0000000000000100')
m~cpu~setGpr(1,0)
source2="expose cpu; use strict arg i,ia,t=0; cpu~setGprFast(1,222); return ia+4"
session~beginInstruction
call truth m~executor~installLiveMethod('OP4C',source2),'replacement live method installed'
m~cpu~setGpr(3,333)
session~abortInstruction
call eq 0,m~cpu~gpr(3),'CPU rewind after replacement'
st=m~executor~step
call eq 'OK',st,'replacement live retry status'
call eq 222,m~cpu~gpr(1),'replacement superseded prior method'

say 'PASS test_executor_live_method_replacement'
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
