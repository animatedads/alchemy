/* Safety22 pre-promotion replay: System/370 primary X'02' operation exception. */
numeric digits 30
storage=.IBM370JournaledStorage~new(1048576,2048,'S22-02-PGMOP-RAM')
m=.IBM4361Machine~new(1048576,storage); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state; cs['psw']='000400016000006E'; cs['stopped']=0; cs['instructionCount']=534665; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('6E'),'02CA00020000'); m~storage~storeHex(x2d('28'),'000400016000006E'); m~storage~storeHex(x2d('68'),'00040000000002CA')
pre=m~cpu~psw~rawHex; preic=m~cpu~instructionCount; preold=m~storage~fetchHex(x2d('28'),8)
/* Shadow Safety22 with Safety21's classifier for pre-promotion phase. */
m~executor~installLiveMethod('architecturalOperationException',"numeric digits 30; use strict arg raw; op=raw~left(2)~translate; return op='00' | op='FF' | op='C4' | op='62' | op='65'")
call eq m~tick,'UNSUPPORTED','02 pre-promotion unsupported'
call eq m~cpu~psw~rawHex,pre,'02 unsupported PSW atomic'; call eq m~cpu~instructionCount,preic,'02 unsupported IC atomic'
s=.IBM4361JournalSession~new(m); s~beginInstruction
classifier="numeric digits 30; use strict arg raw; op=raw~left(2)~translate; return op='00' | op='FF' | op='C4' | op='62' | op='65' | op='02'"
call eq m~executor~installLiveMethod('architecturalOperationException',classifier),1,'classifier installed'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A'); s~abortInstruction
call eq m~cpu~psw~rawHex,pre,'rewind PSW'; call eq m~cpu~instructionCount,preic,'rewind IC'; call eq m~storage~fetchHex(x2d('28'),8),preold,'rewind old'; call eq m~cpu~gpr(5),0,'rewind GPR'; call eq m~storage~fetchHex(x2d('1234'),2),'0000','rewind RAM'
s~beginInstruction; call eq m~tick,'OK','02 operation exception delivered'; s~commitInstruction
call eq m~storage~fetchHex(x2d('28'),8),'0004000160000070','02 old PSW exact'; call eq m~cpu~psw~rawHex,'00040000000002CA','02 full new PSW'; call eq m~cpu~instructionCount,preic+1,'02 counted once'; call eq m~executor~hasMethod('OP02'),0,'no OP02'
say 'PASS test_program_operation_interrupt_02_live_trial'; exit 0
eq: procedure; parse arg got,want,label; if got==want then return; say 'FAIL' label 'got='got 'want='want; exit 1
::requires 'IBM4361Journal.cls'
