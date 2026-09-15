/* Safety22 permanent System/370 primary X'02' BC-mode operation exception. */
numeric digits 30
m=.IBM4361Machine~new(1048576); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state; cs['psw']='000400016000006E'; cs['stopped']=0; cs['instructionCount']=534665; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('6E'),'02CA00020000'); m~storage~storeHex(x2d('28'),'000400016000006E'); m~storage~storeHex(x2d('68'),'00040000000002CA')
call eq m~tick,'OK','02 operation exception delivered'; call eq m~storage~fetchHex(x2d('28'),8),'0004000160000070','02 old exact'; call eq m~cpu~psw~rawHex,'00040000000002CA','02 full new'; call eq m~cpu~instructionCount,534666,'02 counted once'; call eq m~executor~hasMethod('OP02'),0,'no OP02'
m~cpu~psw~loadRawHex('0004000000001000'); m~storage~storeHex(x2d('1000'),'5D00'); ic=m~cpu~instructionCount; call eq m~tick,'UNSUPPORTED','unrelated gap unsupported'; call eq m~cpu~instructionCount,ic,'unrelated gap atomic'
say 'PASS test_program_operation_interrupt_02'; exit 0
eq: procedure; parse arg got,want,label; if got==want then return; say 'FAIL' label 'got='got 'want='want; exit 1
::requires 'IBM4361.cls'
