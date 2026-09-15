/* Safety22 exact X'02' microstate: live candidate -> rewind -> remove -> permanent. */
numeric digits 30
storage=.IBM370JournaledStorage~new(1048576,2048,'S22-02-PROMO-RAM'); m=.IBM4361Machine~new(1048576,storage); m~powerOn
md=.directory~new; md['model']='IBM 4361'; md['machinePhase']='GUEST_STARTED'; md['eventSequence']=1; md['lastIPLDevice']=x2d('350'); m~restoreMachineState(md)
cs=m~cpu~state; cs['psw']='000400016000006E'; cs['stopped']=0; cs['instructionCount']=534665; m~cpu~restoreState(cs)
m~storage~storeHex(x2d('6E'),'02CA00020000'); m~storage~storeHex(x2d('28'),'000400016000006E'); m~storage~storeHex(x2d('68'),'00040000000002CA')
prePsw=m~cpu~psw~rawHex; preIc=m~cpu~instructionCount; preOld=m~storage~fetchHex(x2d('28'),8)
classifier="numeric digits 30; use strict arg raw; op=raw~left(2)~translate; return op='00' | op='FF' | op='C4' | op='62' | op='65' | op='02'"
interrupt="expose cpu storage; numeric digits 30; use strict arg inst,ia,len; if cpu~psw~ecMode then raise syntax 40.900 array('BC-mode operation-interruption trial only'); cpu~psw~setInstructionLength(len); cpu~psw~setInstructionAddress((ia+len)//16777216); old=cpu~psw~rawWithInterruptionCode(1); base=cpu~prefix; storage~storeHex((base+x2d('28'))//16777216,old); new=storage~fetchHex((base+x2d('68'))//16777216,8); cpu~psw~loadRawHex(new); return 'OK'"
s=.IBM4361JournalSession~new(m); s~beginInstruction; m~executor~installLiveMethod('architecturalOperationException',classifier); m~executor~installLiveMethod('programInterruptOperation',interrupt); call eq m~tick,'OK','live 02 executes'; livePsw=m~cpu~psw~rawHex; liveOld=m~storage~fetchHex(x2d('28'),8); liveIc=m~cpu~instructionCount; s~abortInstruction
call eq m~cpu~psw~rawHex,prePsw,'rewind PSW'; call eq m~cpu~instructionCount,preIc,'rewind IC'; call eq m~storage~fetchHex(x2d('28'),8),preOld,'rewind old'
m~executor~removeLiveMethod('architecturalOperationException'); m~executor~removeLiveMethod('programInterruptOperation'); call eq m~executor~hasMethod('OP02'),0,'no OP02'
s~beginInstruction; call eq m~tick,'OK','permanent 02 executes'; permPsw=m~cpu~psw~rawHex; permOld=m~storage~fetchHex(x2d('28'),8); permIc=m~cpu~instructionCount; s~commitInstruction
call eq permPsw,livePsw,'live/permanent PSW'; call eq permOld,liveOld,'live/permanent old'; call eq permIc,liveIc,'live/permanent IC'; call eq permOld,'0004000160000070','exact old'; call eq permPsw,'00040000000002CA','exact new'
say 'PASS test_program_operation_interrupt_02_promotion_equivalence'; exit 0
eq: procedure; parse arg got,want,label; if got==want then return; say 'FAIL' label 'got='got 'want='want; exit 1
::requires 'IBM4361Journal.cls'
