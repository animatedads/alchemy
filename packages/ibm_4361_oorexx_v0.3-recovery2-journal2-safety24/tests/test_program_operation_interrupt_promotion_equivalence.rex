/* Same microstate: live archaeology candidate -> rewind -> remove -> permanent. */
numeric digits 30
storage=.IBM370JournaledStorage~new(1048576,2048,'S14-PROMO-RAM')
m=.IBM4361Machine~new(1048576,storage); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state; cs['psw']='0004000A60000000'; cs['stopped']=0; cs['instructionCount']=513272; m~cpu~restoreState(cs)
m~storage~storeHex(0,'0000'); m~storage~storeHex(x2d('68'),'00040000000002CA')
prePsw=m~cpu~psw~rawHex; preIc=m~cpu~instructionCount; preOld=m~storage~fetchHex(x2d('28'),8)
classifier="numeric digits 30; use strict arg raw; return raw~left(2)~translate='00'"
interrupt="expose cpu storage; numeric digits 30; use strict arg inst,ia,len; if cpu~psw~ecMode then raise syntax 40.900 array('BC-mode operation-interruption trial only'); cpu~psw~setInstructionLength(len); cpu~psw~setInstructionAddress((ia+len)//16777216); old=cpu~psw~rawWithInterruptionCode(1); base=cpu~prefix; storage~storeHex((base+x2d('28'))//16777216,old); new=storage~fetchHex((base+x2d('68'))//16777216,8); cpu~psw~loadRawHex(new); return 'OK'"
session=.IBM4361JournalSession~new(m)
session~beginInstruction
m~executor~installLiveMethod('architecturalOperationException',classifier)
m~executor~installLiveMethod('programInterruptOperation',interrupt)
call eq m~tick,'OK','live candidate executes'
livePsw=m~cpu~psw~rawHex; liveOld=m~storage~fetchHex(x2d('28'),8); liveIc=m~cpu~instructionCount
session~abortInstruction
call eq m~cpu~psw~rawHex,prePsw,'rewind candidate PSW'
call eq m~cpu~instructionCount,preIc,'rewind candidate IC'
call eq m~storage~fetchHex(x2d('28'),8),preOld,'rewind candidate old PSW'
call eq m~executor~hasMethod('architecturalOperationException'),1,'candidate survives rewind'
call eq m~executor~hasMethod('programInterruptOperation'),1,'candidate interrupt survives rewind'
m~executor~removeLiveMethod('architecturalOperationException'); m~executor~removeLiveMethod('programInterruptOperation')
call eq m~executor~hasMethod('OP00'),0,'promotion has no OP00'
session~beginInstruction
call eq m~tick,'OK','permanent implementation executes'
permPsw=m~cpu~psw~rawHex; permOld=m~storage~fetchHex(x2d('28'),8); permIc=m~cpu~instructionCount
session~commitInstruction
call eq permPsw,livePsw,'candidate/permanent PSW equivalent'
call eq permOld,liveOld,'candidate/permanent old PSW equivalent'
call eq permIc,liveIc,'candidate/permanent IC equivalent'
call eq permOld,'0004000160000002','exact MVT old PSW'
call eq permPsw,'00040000000002CA','exact MVT new PSW'
say 'PASS test_program_operation_interrupt_promotion_equivalence'
exit 0

eq: procedure
  parse arg got,want,label
  if got==want then return
  say 'FAIL' label 'got='got 'want='want
  exit 1
::requires 'IBM4361Journal.cls'
