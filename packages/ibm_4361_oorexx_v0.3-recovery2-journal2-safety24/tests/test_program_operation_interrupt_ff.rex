/* Safety16 permanent FF BC-mode operation-exception delivery. */
numeric digits 30
m=.IBM4361Machine~new(1048576); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state; cs['psw']='0004000160000020'; cs['stopped']=0; cs['instructionCount']=521152; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('20'),'FF04000D0001')
m~storage~storeHex(x2d('28'),'0004000160000020')
m~storage~storeHex(x2d('68'),'00040000000002CA')
call eq m~tick,'OK','FF operation exception delivered'
call eq m~storage~fetchHex(x2d('28'),8),'00040001E0000026','FF old PSW exact'
call eq m~cpu~psw~rawHex,'00040000000002CA','FF full program-new load'
call eq m~cpu~instructionCount,521153,'FF counted once'
call eq m~executor~hasMethod('OPFF'),0,'no OPFF'
/* unrelated missing opcode must remain unsupported */
m~cpu~psw~loadRawHex('0004000000001000'); m~storage~storeHex(x2d('1000'),'4C00'); ic=m~cpu~instructionCount
call eq m~tick,'UNSUPPORTED','unrelated gap still unsupported'
call eq m~cpu~psw~instructionAddress,x2d('1000'),'unrelated IA atomic'
call eq m~cpu~instructionCount,ic,'unrelated IC atomic'
say 'PASS test_program_operation_interrupt_ff'
exit 0
eq: procedure
  parse arg got,want,label
  if got==want then return
  say 'FAIL' label 'got='got 'want='want
  exit 1
::requires 'IBM4361.cls'
