/* Safety14: fast known lead-in, exact architectural handoff to journal storage,
 * then operation-exception live retry at IA=0.  No OP00 is ever installed. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media14/mvtres.350'
if log='' then log='/mnt/data/mvt_safety14_program_interrupt_journal_handoff.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START FAST'
found=0
/* Safety13 frontier is around 513k guest instructions; accelerators mean fewer ticks. */
do n=1 to 600000
  ia=m~cpu~psw~instructionAddress; ic=m~cpu~instructionCount
  st=m~tick
  if st<>'OK' then do
    inst=m~storage~fetchHex(ia,6)
    call emit 'FAST STOP n='||n||' IA='||d2x(ia,6)||' PREIC='||ic||' IC='||m~cpu~instructionCount||' INST='||inst||' ST='||st||' PSW='||m~cpu~psw~rawHex
    if ia=0 & inst~left(2)='00' & m~cpu~instructionCount=513272 then found=1
    leave
  end
end
if \found then do; call emit 'FAIL expected IA0 frontier not reached'; exit 2; end
call emit 'LOWCORE PGMOLD='||m~storage~fetchHex(x2d('28'),8)||' PGMNEW='||m~storage~fetchHex(x2d('68'),8)||' SVCOLD='||m~storage~fetchHex(x2d('20'),8)||' SVCNEW='||m~storage~fetchHex(x2d('60'),8)
call emit 'CHANNEL active='||m~channels~activeProgramNumbers~items||' pending='||m~channels~pendingInterruptCount||' completed='||m~channels~completedStatusCount

/* Capture explicit architectural component states. */
ms=m~state; cs=m~cpu~state; ks=m~clock~state; ss=m~storage~state; hs=m~channels~state
d350s=m~channels~device(x2d('350'))~state; d1fs=m~channels~device(x2d('001F'))~state
aps=.array~new
do num over m~channels~activeProgramNumbers
  row=.directory~new; row['number']=num; row['state']=m~channels~activeProgram(num)~state; aps~append(row)
end
if hs['pendingInterruptCount']<>0 | hs['completedStatusCount']<>0 then do
  call emit 'FAIL handoff codec refuses pending/completed channel status'; exit 3
end

/* Rehydrate exact state into journal-capable RAM in the same process. */
js=.IBM370JournaledStorage~new(16777216,2048,'MVT-S14-PGM-RAM')
jm=.IBM4361Machine~new(16777216,js)
jd=.IBM3330Device~new(x2d('350'),media); jd~restoreState(d350s)
jc=.IBM3215Device~new(x2d('001F')); jc~restoreState(d1fs)
jm~attachDevice(jd); jm~attachDevice(jc)
jm~restoreMachineState(ms); jm~cpu~restoreState(cs); jm~clock~restoreState(ks); jm~storage~restoreState(ss); jm~channels~restoreState(hs)
do row over aps
  ps=row['state']; p=.IBM370ChannelProgram~new(row['number'],ps['currentCCWAddress'],ps['kind']); p~restoreState(ps); jm~channels~restoreActiveProgram(p)
end
/* Verify exact frontier observables after handoff. */
if jm~cpu~psw~rawHex<>m~cpu~psw~rawHex | jm~cpu~instructionCount<>m~cpu~instructionCount | jm~storage~fetchHex(0,256)<>m~storage~fetchHex(0,256) then do
  call emit 'FAIL handoff mismatch'; exit 4
end
do r=0 to 15
  if jm~cpu~gpr(r)<>m~cpu~gpr(r) then do; call emit 'FAIL handoff GPR'||r; exit 4; end
end
call emit 'HANDOFF OK IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' PGMNEW='||jm~storage~fetchHex(x2d('68'),8)

prePSW=jm~cpu~psw~rawHex; preIC=jm~cpu~instructionCount; preOld=jm~storage~fetchHex(x2d('28'),8)
session=.IBM4361JournalSession~new(jm)
session~beginInstruction
first=jm~tick
call emit 'FIRST ST='||first||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PGMOLD='||jm~storage~fetchHex(x2d('28'),8)
if first<>'UNSUPPORTED' then do; call emit 'FAIL first not unsupported'; exit 5; end

classifier="numeric digits 30; use strict arg raw; return raw~left(2)~translate='00'"
interrupt="expose cpu storage; numeric digits 30; use strict arg inst,ia,len; if cpu~psw~ecMode then raise syntax 40.900 array('BC-mode operation-interruption trial only'); cpu~psw~setInstructionLength(len); cpu~psw~setInstructionAddress((ia+len)//16777216); old=cpu~psw~rawWithInterruptionCode(1); base=cpu~prefix; storage~storeHex((base+x2d('28'))//16777216,old); new=storage~fetchHex((base+x2d('68'))//16777216,8); cpu~psw~loadRawHex(new); return 'OK'"
call emit 'PATCH class='||jm~executor~installLiveMethod('architecturalOperationException',classifier)||' interrupt='||jm~executor~installLiveMethod('programInterruptOperation',interrupt)
jm~cpu~setGpr(5,x2d('DEADBEEF')); jm~storage~storeHex(x2d('1234'),'A55A')
session~abortInstruction
call emit 'REWIND IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' OLD='||jm~storage~fetchHex(x2d('28'),8)||' R5='||d2x(jm~cpu~gpr(5),8)||' M1234='||jm~storage~fetchHex(x2d('1234'),2)||' CLASS='||jm~executor~hasMethod('architecturalOperationException')||' INT='||jm~executor~hasMethod('programInterruptOperation')
if jm~cpu~psw~rawHex<>prePSW | jm~cpu~instructionCount<>preIC | jm~storage~fetchHex(x2d('28'),8)<>preOld then do; call emit 'FAIL rewind mismatch'; exit 6; end

session~beginInstruction
retry=jm~tick
session~commitInstruction
call emit 'RETRY ST='||retry||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' PGMOLD='||jm~storage~fetchHex(x2d('28'),8)||' PGMNEW='||jm~storage~fetchHex(x2d('68'),8)||' OP00='||jm~executor~hasMethod('OP00')
if retry<>'OK' | jm~storage~fetchHex(x2d('28'),8)<>'0004000160000002' | jm~cpu~psw~rawHex<>'00040000000002CA' then do; call emit 'FAIL operation retry'; exit 7; end

pst='OK'
do k=1 to 20000
  pia=jm~cpu~psw~instructionAddress; pic=jm~cpu~instructionCount
  pst=jm~tick
  if pst<>'OK' then do
    pinst=jm~storage~fetchHex(pia,6)
    call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||jm~cpu~instructionCount||' PREIC='||pic||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||jm~cpu~psw~rawHex||' ST='||pst
    leave
  end
end
if pst='OK' then call emit 'NEXT none within 20000 ticks IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
call emit 'END'; call lineout log
say 'PASS probe_mvt_program_interrupt_journal_handoff log='log
exit 0

emit: parse arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
