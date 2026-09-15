/* Safety16 pre-promotion trial: X'FF' is an architectural operation exception,
 * not OPFF.  The six-byte ILC must advance old-PSW IA to X'26'. */
numeric digits 30
storage=.IBM370JournaledStorage~new(1048576,2048,'S16-FF-PGMOP-RAM')
m=.IBM4361Machine~new(1048576,storage); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state; cs['psw']='0004000160000020'; cs['stopped']=0; cs['instructionCount']=521152; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('20'),'FF04000D0001')
m~storage~storeHex(x2d('28'),'0004000160000020')
m~storage~storeHex(x2d('68'),'00040000000002CA')
pre=m~cpu~psw~rawHex; preic=m~cpu~instructionCount; preold=m~storage~fetchHex(x2d('28'),8)
/* Shadow promoted safety16 classifier with safety15's pre-promotion 00-only behavior. */
m~executor~installLiveMethod('architecturalOperationException',"use strict arg raw; return raw~left(2)~translate='00'")
first=m~tick
call eq first,'UNSUPPORTED','FF pre-promotion unsupported'
call eq m~cpu~psw~rawHex,pre,'FF unsupported PSW atomic'
call eq m~cpu~instructionCount,preic,'FF unsupported IC atomic'
s=.IBM4361JournalSession~new(m); s~beginInstruction
classifier="numeric digits 30; use strict arg raw; op=raw~left(2)~translate; return op='00' | op='FF'"
call eq m~executor~installLiveMethod('architecturalOperationException',classifier),1,'classifier installed'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A'); s~abortInstruction
call eq m~cpu~psw~rawHex,pre,'rewind PSW'
call eq m~cpu~instructionCount,preic,'rewind IC'
call eq m~storage~fetchHex(x2d('28'),8),preold,'rewind old PSW'
call eq m~cpu~gpr(5),0,'rewind GPR dirt'
call eq m~storage~fetchHex(x2d('1234'),2),'0000','rewind RAM dirt'
s~beginInstruction; retry=m~tick; s~commitInstruction
call eq retry,'OK','FF operation exception delivered'
call eq m~storage~fetchHex(x2d('28'),8),'00040001E0000026','FF program-old exact'
call eq m~cpu~psw~rawHex,'00040000000002CA','FF program-new full load'
call eq m~cpu~instructionCount,preic+1,'FF counted once'
call eq m~executor~hasMethod('OPFF'),0,'no synthetic OPFF'
say 'PASS test_program_operation_interrupt_ff_live_trial'
exit 0
eq: procedure
  parse arg got,want,label
  if got==want then return
  say 'FAIL' label 'got='got 'want='want
  exit 1
::requires 'IBM4361Journal.cls'
