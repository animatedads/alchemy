/* Safety17 pre-promotion trial: System/370 primary X'C4' operation exception. */
numeric digits 30
storage=.IBM370JournaledStorage~new(1048576,2048,'S17-C4-PGMOP-RAM')
m=.IBM4361Machine~new(1048576,storage); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state; cs['psw']='0004000160000042'; cs['stopped']=0; cs['instructionCount']=527364; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('42'),'C4E80C000000'); m~storage~storeHex(x2d('28'),'0004000160000042'); m~storage~storeHex(x2d('68'),'00040000000002CA')
pre=m~cpu~psw~rawHex; preic=m~cpu~instructionCount; preold=m~storage~fetchHex(x2d('28'),8)
/* Shadow safety17 with safety16's 00|FF classifier for the pre-promotion phase. */
m~executor~installLiveMethod('architecturalOperationException',"numeric digits 30; use strict arg raw; op=raw~left(2)~translate; return op='00' | op='FF'")
call eq m~tick,'UNSUPPORTED','C4 pre-promotion unsupported'
call eq m~cpu~psw~rawHex,pre,'C4 unsupported PSW atomic'; call eq m~cpu~instructionCount,preic,'C4 unsupported IC atomic'
s=.IBM4361JournalSession~new(m); s~beginInstruction
classifier="numeric digits 30; use strict arg raw; op=raw~left(2)~translate; return op='00' | op='FF' | op='C4'"
call eq m~executor~installLiveMethod('architecturalOperationException',classifier),1,'classifier installed'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A'); s~abortInstruction
call eq m~cpu~psw~rawHex,pre,'rewind PSW'; call eq m~cpu~instructionCount,preic,'rewind IC'; call eq m~storage~fetchHex(x2d('28'),8),preold,'rewind old'; call eq m~cpu~gpr(5),0,'rewind GPR'; call eq m~storage~fetchHex(x2d('1234'),2),'0000','rewind RAM'
s~beginInstruction; call eq m~tick,'OK','C4 operation exception delivered'; s~commitInstruction
call eq m~storage~fetchHex(x2d('28'),8),'00040001E0000048','C4 old PSW exact'; call eq m~cpu~psw~rawHex,'00040000000002CA','C4 full new PSW'; call eq m~cpu~instructionCount,preic+1,'C4 counted once'; call eq m~executor~hasMethod('OPC4'),0,'no OPC4'
say 'PASS test_program_operation_interrupt_c4_live_trial'
exit 0
eq: procedure; parse arg got,want,label; if got==want then return; say 'FAIL' label 'got='got 'want='want; exit 1
::requires 'IBM4361Journal.cls'
