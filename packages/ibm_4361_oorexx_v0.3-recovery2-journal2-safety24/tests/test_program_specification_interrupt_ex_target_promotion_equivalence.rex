/* Safety24: live candidate and permanent source agree from identical state. */
numeric digits 30
storage=.IBM370JournaledStorage~new(131072,2048,'S24-EX-EQUIV-RAM')
m=.IBM4361Machine~new(131072,storage); m~powerOn
call resetState
session=.IBM4361JournalSession~new(m); session~beginInstruction
newStep=readText('evidence/safety24_step_candidate.rexsrc')
call truth m~executor~installLiveMethod('step',newStep),'install candidate'
st1=m~executor~step
snap1=m~cpu~psw~rawHex||'|'||m~storage~fetchHex(x2d('28'),8)||'|'||m~cpu~instructionCount||'|'||m~executor~lastInstruction
session~abortInstruction
call truth m~executor~removeLiveMethod('step'),'remove candidate'
call eq '0004B6',d2x(m~cpu~psw~instructionAddress,6),'rewound IA'
call eq 539205,m~cpu~instructionCount,'rewound IC'
st2=m~executor~step
snap2=m~cpu~psw~rawHex||'|'||m~storage~fetchHex(x2d('28'),8)||'|'||m~cpu~instructionCount||'|'||m~executor~lastInstruction
call eq st1,st2,'status equivalence'
call eq snap1,snap2,'architectural equivalence'
call eq '00040000000002CA|00040006800004BA|539206|440004F4->70E005C84780',snap2,'expected permanent result'
call eq 0,m~executor~hasMethod('OP70'),'no OP70'
say 'PASS test_program_specification_interrupt_ex_target_promotion_equivalence'
exit 0
resetState: procedure expose m
  m~cpu~loadIPLPSW('00040000800004B6')
  cs=m~cpu~state; cs['instructionCount']=539205; m~cpu~restoreState(cs)
  m~storage~storeHex(x2d('4B6'),'440004F4')
  m~storage~storeHex(x2d('4F4'),'70E005C84780')
  m~storage~storeHex(x2d('68'),'00040000000002CA')
  m~storage~storeHex(x2d('28'),'0000000000000000')
return
readText: procedure
  use arg path
  text=''
  do while lines(path)>0; text=text||linein(path)||';'; end
  call lineout path
  return text
eq: procedure
  use arg expected,actual,label
  if expected\==actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
return
truth: procedure
  use arg x,label
  if \x then do; say 'FAIL' label; exit 1; end
return
::requires 'IBM4361Journal.cls'
