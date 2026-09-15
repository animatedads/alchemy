/* Safety18 permanent System/370 primary X'62' BC-mode operation exception. */
numeric digits 30
m=.IBM4361Machine~new(1048576); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state; cs['psw']='00040001E0000050'; cs['stopped']=0; cs['instructionCount']=529092; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('50'),'62E050000001'); m~storage~storeHex(x2d('28'),'00040001E0000050'); m~storage~storeHex(x2d('68'),'00040000000002CA')
call eq m~tick,'OK','62 operation exception delivered'; call eq m~storage~fetchHex(x2d('28'),8),'00040001A0000054','62 old exact'; call eq m~cpu~psw~rawHex,'00040000000002CA','62 full new'; call eq m~cpu~instructionCount,529093,'62 counted once'; call eq m~executor~hasMethod('OP62'),0,'no OP62'
m~cpu~psw~loadRawHex('0004000000001000'); m~storage~storeHex(x2d('1000'),'5D00'); ic=m~cpu~instructionCount; call eq m~tick,'UNSUPPORTED','unrelated gap unsupported'; call eq m~cpu~instructionCount,ic,'unrelated gap atomic'
say 'PASS test_program_operation_interrupt_62'; exit 0
eq: procedure; parse arg got,want,label; if got==want then return; say 'FAIL' label 'got='got 'want='want; exit 1
::requires 'IBM4361.cls'
