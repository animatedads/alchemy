/* safety14: operation exception is a program interruption, never OP00. */
numeric digits 30
storage=.IBM370JournaledStorage~new(1048576,2048,'S14-PGMOP-RAM')
m=.IBM4361Machine~new(1048576,storage)
m~powerOn
/* Recreate the exact BC-mode state observed immediately after BALR R14,R6 -> 0. */
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state
cs['psw']='0004000A60000000'; cs['stopped']=0; cs['instructionCount']=513272
m~cpu~restoreState(cs)
m~storage~storeHex(0,'0000')
m~storage~storeHex(x2d('68'),'00040000000002CA')

prePsw=m~cpu~psw~rawHex; preIc=m~cpu~instructionCount
/* Shadow the promoted classifier with the pre-promotion fail-closed behaviour. */
m~executor~installLiveMethod('architecturalOperationException','use strict arg raw; return .false')
first=m~tick
call eq first,'UNSUPPORTED','first X00 remains archaeology boundary'
call eq m~cpu~psw~rawHex,prePsw,'unsupported atomic PSW'
call eq m~cpu~instructionCount,preIc,'unsupported atomic IC'
call eq m~storage~fetchHex(x2d('28'),8),'0000000000000000','program-old untouched before trial'
call eq m~executor~hasMethod('OP00'),0,'no OP00 method'

session=.IBM4361JournalSession~new(m)
session~beginInstruction
classifier="numeric digits 30; use strict arg raw; return raw~left(2)~translate='00'"
interrupt="expose cpu storage; numeric digits 30; use strict arg inst,ia,len; if cpu~psw~ecMode then raise syntax 40.900 array('BC-mode operation-interruption trial only'); cpu~psw~setInstructionLength(len); cpu~psw~setInstructionAddress((ia+len)//16777216); old=cpu~psw~rawWithInterruptionCode(1); base=cpu~prefix; storage~storeHex((base+x2d('28'))//16777216,old); new=storage~fetchHex((base+x2d('68'))//16777216,8); cpu~psw~loadRawHex(new); return 'OK'"
call eq m~executor~installLiveMethod('architecturalOperationException',classifier),1,'classifier installed'
call eq m~executor~installLiveMethod('programInterruptOperation',interrupt),1,'interrupt installed'
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A')
session~abortInstruction
call eq m~cpu~psw~rawHex,prePsw,'rewind PSW'
call eq m~cpu~instructionCount,preIc,'rewind IC'
call eq m~cpu~gpr(5),0,'rewind GPR dirt'
call eq m~storage~fetchHex(x2d('1234'),2),'0000','rewind RAM dirt'
call eq m~executor~hasMethod('architecturalOperationException'),1,'classifier survives rewind'
call eq m~executor~hasMethod('programInterruptOperation'),1,'interrupt survives rewind'

session~beginInstruction
retry=m~tick
call eq retry,'OK','operation exception delivered'
call eq m~storage~fetchHex(x2d('28'),8),'0004000160000002','exact program-old PSW'
call eq m~cpu~psw~rawHex,'00040000000002CA','full program-new PSW loaded'
call eq m~cpu~instructionCount,preIc+1,'interrupting instruction counted once'
session~commitInstruction
call eq m~executor~hasMethod('OP00'),0,'still no OP00 after delivery'

/* Remove trial classifier and prove an unrelated missing opcode remains atomic. */
m~executor~removeLiveMethod('architecturalOperationException')
m~executor~removeLiveMethod('programInterruptOperation')
m~cpu~psw~loadRawHex('0004000000001000'); m~storage~storeHex(x2d('1000'),'4C00')
ic=m~cpu~instructionCount
st=m~tick
call eq st,'UNSUPPORTED','ordinary missing opcode remains unsupported'
call eq m~cpu~psw~instructionAddress,x2d('1000'),'ordinary unsupported IA atomic'
call eq m~cpu~instructionCount,ic,'ordinary unsupported IC atomic'
say 'PASS test_program_operation_interrupt_live_trial'
exit 0

eq: procedure
  parse arg got,want,label
  if got==want then return
  say 'FAIL' label 'got='got 'want='want
  exit 1

::requires 'IBM4361Journal.cls'
