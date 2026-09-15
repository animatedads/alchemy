/* Safety19: live System/370 specification exception for D with odd R1. */
numeric digits 30
storage=.IBM370JournaledStorage~new(131072,2048,'SPEC5D-LIVE-RAM')
m=.IBM4361Machine~new(131072,storage); m~powerOn
call resetState
call eq 'OK',m~executor~step,'permanent specification baseline'
call eq '00040006A0000062',m~storage~fetchHex(x2d('28'),8),'permanent old PSW'
call resetState
session=.IBM4361JournalSession~new(m)
classify="numeric digits 30; use strict arg raw; if raw~length<4 then return .false; return raw~left(2)~translate='5D' & (x2d(raw~substr(3,1))//2=1)"
deliver="expose cpu storage; numeric digits 30; use strict arg inst,ia,len; if cpu~psw~ecMode then return 'UNSUPPORTED'; cpu~psw~setInstructionLength(len); cpu~psw~setInstructionAddress((ia+len)//16777216); old=cpu~psw~rawWithInterruptionCode(6); base=cpu~prefix; storage~storeHex((base+x2d('28'))//16777216,old); new=storage~fetchHex((base+x2d('68'))//16777216,8); cpu~psw~loadRawHex(new); return 'OK'"
session~beginInstruction
call truth m~executor~installLiveMethod('architecturalSpecificationException',classify),'install classifier'
call truth m~executor~installLiveMethod('programInterruptSpecification',deliver),'install delivery'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('120'),'A55A')
session~abortInstruction
call eq '00000000',d2x(m~cpu~gpr(5),8),'rewind GPR'
call eq '0000',m~storage~fetchHex(x2d('120'),2),'rewind RAM'
call eq '00005E',d2x(m~cpu~psw~instructionAddress,6),'rewind IA'
call eq '531376',m~cpu~instructionCount~string,'rewind IC'
session~beginInstruction
st=m~executor~step
session~commitInstruction
call eq 'OK',st,'specification retry'
call eq '00040006A0000062',m~storage~fetchHex(x2d('28'),8),'program-old PSW'
call eq '00040000000002CA',m~cpu~psw~rawHex,'program-new PSW'
call eq '531377',m~cpu~instructionCount~string,'instruction count'
call eq '40016614',d2x(m~cpu~gpr(11),8),'R11 unchanged'
call eq '00000000',m~storage~fetchHex(x2d('1D8'),4),'divisor unchanged'
call eq 0,m~executor~hasMethod('OP5D'),'no OP5D'
say 'PASS test_program_specification_interrupt_5d_live_trial'
exit 0
resetState: procedure expose m
  m~cpu~loadIPLPSW('000400016000005E')
  cs=m~cpu~state; cs['instructionCount']=531376; m~cpu~restoreState(cs)
  m~storage~storeHex(x2d('5E'),'5DB80004')
  m~storage~storeHex(x2d('68'),'00040000000002CA')
  m~storage~storeHex(x2d('28'),'0000000000000000')
  m~storage~storeHex(x2d('1D8'),'00000000')
  m~cpu~setGpr(8,x2d('000001D4')); m~cpu~setGpr(11,x2d('40016614')); m~cpu~setGpr(12,x2d('000154C8'))
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
