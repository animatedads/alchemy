/* Safety21 pre-promotion replay: System/370 primary X'65' operation exception. */
numeric digits 30
storage=.IBM370JournaledStorage~new(1048576,2048,'S21-65-PGMOP-RAM')
m=.IBM4361Machine~new(1048576,storage); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state; cs['psw']='0004000160000066'; cs['stopped']=0; cs['instructionCount']=532961; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('66'),'65F000040000'); m~storage~storeHex(x2d('28'),'0004000160000066'); m~storage~storeHex(x2d('68'),'00040000000002CA')
pre=m~cpu~psw~rawHex; preic=m~cpu~instructionCount; preold=m~storage~fetchHex(x2d('28'),8)
/* Shadow Safety21 with Safety20's classifier for pre-promotion phase. */
m~executor~installLiveMethod('architecturalOperationException',"numeric digits 30; use strict arg raw; op=raw~left(2)~translate; return op='00' | op='FF' | op='C4' | op='62'")
call eq m~tick,'UNSUPPORTED','65 pre-promotion unsupported'
call eq m~cpu~psw~rawHex,pre,'65 unsupported PSW atomic'; call eq m~cpu~instructionCount,preic,'65 unsupported IC atomic'
s=.IBM4361JournalSession~new(m); s~beginInstruction
classifier="numeric digits 30; use strict arg raw; op=raw~left(2)~translate; return op='00' | op='FF' | op='C4' | op='62' | op='65'"
call eq m~executor~installLiveMethod('architecturalOperationException',classifier),1,'classifier installed'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A'); s~abortInstruction
call eq m~cpu~psw~rawHex,pre,'rewind PSW'; call eq m~cpu~instructionCount,preic,'rewind IC'; call eq m~storage~fetchHex(x2d('28'),8),preold,'rewind old'; call eq m~cpu~gpr(5),0,'rewind GPR'; call eq m~storage~fetchHex(x2d('1234'),2),'0000','rewind RAM'
s~beginInstruction; call eq m~tick,'OK','65 operation exception delivered'; s~commitInstruction
call eq m~storage~fetchHex(x2d('28'),8),'00040001A000006A','65 old PSW exact'; call eq m~cpu~psw~rawHex,'00040000000002CA','65 full new PSW'; call eq m~cpu~instructionCount,preic+1,'65 counted once'; call eq m~executor~hasMethod('OP65'),0,'no OP65'
say 'PASS test_program_operation_interrupt_65_live_trial'; exit 0
eq: procedure; parse arg got,want,label; if got==want then return; say 'FAIL' label 'got='got 'want='want; exit 1
::requires 'IBM4361Journal.cls'
