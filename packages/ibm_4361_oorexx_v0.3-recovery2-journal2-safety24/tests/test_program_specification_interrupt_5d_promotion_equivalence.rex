/* Safety19: live candidate and permanent specification-exception path must
 * agree from the identical recorded MVT 5D frontier microstate. */
numeric digits 30
storage=.IBM370JournaledStorage~new(131072,2048,'SPEC5D-PROMOTION-RAM')
m=.IBM4361Machine~new(131072,storage); m~powerOn
call resetState
classify="numeric digits 30; use strict arg raw; if raw~length<4 then return .false; return raw~left(2)~translate='5D' & (x2d(raw~substr(3,1))//2=1)"
deliver="expose cpu storage; numeric digits 30; use strict arg inst,ia,len; if cpu~psw~ecMode then return 'UNSUPPORTED'; cpu~psw~setInstructionLength(len); cpu~psw~setInstructionAddress((ia+len)//16777216); old=cpu~psw~rawWithInterruptionCode(6); base=cpu~prefix; storage~storeHex((base+x2d('28'))//16777216,old); new=storage~fetchHex((base+x2d('68'))//16777216,8); cpu~psw~loadRawHex(new); return 'OK'"
call truth m~executor~installLiveMethod('architecturalSpecificationException',classify),'install live classifier'
call truth m~executor~installLiveMethod('programInterruptSpecification',deliver),'install live delivery'
session=.IBM4361JournalSession~new(m)
session~beginInstruction
st=m~executor~step
call eq 'OK',st,'live status'
liveOld=m~storage~fetchHex(x2d('28'),8); livePSW=m~cpu~psw~rawHex; liveIC=m~cpu~instructionCount
session~abortInstruction
call eq '000400016000005E',m~cpu~psw~rawHex,'rewind PSW'
call eq '0000000000000000',m~storage~fetchHex(x2d('28'),8),'rewind old PSW'
session~beginInstruction
call truth m~executor~removeLiveMethod('architecturalSpecificationException'),'remove live classifier'
call truth m~executor~removeLiveMethod('programInterruptSpecification'),'remove live delivery'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('120'),'A55A')
session~abortInstruction
call eq '00000000',d2x(m~cpu~gpr(5),8),'withdrawal rewind GPR'
call eq '0000',m~storage~fetchHex(x2d('120'),2),'withdrawal rewind RAM'
st=m~executor~step
call eq 'OK',st,'permanent status'
call eq liveOld,m~storage~fetchHex(x2d('28'),8),'old PSW equivalence'
call eq livePSW,m~cpu~psw~rawHex,'new PSW equivalence'
call eq liveIC,m~cpu~instructionCount,'IC equivalence'
call eq '00040006A0000062',liveOld,'recorded MVT old PSW'
call eq '00040000000002CA',livePSW,'recorded MVT new PSW'
say 'PASS test_program_specification_interrupt_5d_promotion_equivalence'
exit 0
resetState: procedure expose m
  m~cpu~loadIPLPSW('000400016000005E')
  cs=m~cpu~state; cs['instructionCount']=531376; m~cpu~restoreState(cs)
  m~storage~storeHex(x2d('5E'),'5DB80004'); m~storage~storeHex(x2d('68'),'00040000000002CA'); m~storage~storeHex(x2d('28'),'0000000000000000'); m~storage~storeHex(x2d('1D8'),'00000000')
  m~cpu~setGpr(8,x2d('000001D4')); m~cpu~setGpr(11,x2d('40016614'))
return
eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
truth: procedure
  use arg x,label
  if \x then do; say 'FAIL' label; exit 1; end
return
::requires 'IBM4361Journal.cls'
