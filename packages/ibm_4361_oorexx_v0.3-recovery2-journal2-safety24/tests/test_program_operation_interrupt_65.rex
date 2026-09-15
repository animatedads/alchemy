/* Safety21 permanent System/370 primary X'65' BC-mode operation exception. */
numeric digits 30
m=.IBM4361Machine~new(1048576); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state; cs['psw']='0004000160000066'; cs['stopped']=0; cs['instructionCount']=532961; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('66'),'65F000040000'); m~storage~storeHex(x2d('28'),'0004000160000066'); m~storage~storeHex(x2d('68'),'00040000000002CA')
call eq m~tick,'OK','65 operation exception delivered'; call eq m~storage~fetchHex(x2d('28'),8),'00040001A000006A','65 old exact'; call eq m~cpu~psw~rawHex,'00040000000002CA','65 full new'; call eq m~cpu~instructionCount,532962,'65 counted once'; call eq m~executor~hasMethod('OP65'),0,'no OP65'
m~cpu~psw~loadRawHex('0004000000001000'); m~storage~storeHex(x2d('1000'),'5D00'); ic=m~cpu~instructionCount; call eq m~tick,'UNSUPPORTED','unrelated gap unsupported'; call eq m~cpu~instructionCount,ic,'unrelated gap atomic'
say 'PASS test_program_operation_interrupt_65'; exit 0
eq: procedure; parse arg got,want,label; if got==want then return; say 'FAIL' label 'got='got 'want='want; exit 1
::requires 'IBM4361.cls'
