/* Safety17: exact C4 @ X'42' operation-exception trial; no OPC4. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media16/mvtres.350'
if log='' then log='/mnt/data/mvt_safety17_c4_program_interrupt_journal_handoff.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START FAST'
found=0
do n=1 to 750000
  ia=m~cpu~psw~instructionAddress; ic=m~cpu~instructionCount; st=m~tick
  if st<>'OK' then do
    inst=m~storage~fetchHex(ia,6); call emit 'FAST STOP n='||n||' IA='||d2x(ia,6)||' PREIC='||ic||' IC='||m~cpu~instructionCount||' INST='||inst||' ST='||st||' PSW='||m~cpu~psw~rawHex
    if ia=x2d('42') & inst~left(2)='C4' & m~cpu~instructionCount=527364 then found=1
    leave
  end
end
if \found then do; call emit 'FAIL expected C4 frontier not reached'; exit 2; end
call emit 'LOWCORE PGMOLD='||m~storage~fetchHex(x2d('28'),8)||' PGMNEW='||m~storage~fetchHex(x2d('68'),8)||' SVCOLD='||m~storage~fetchHex(x2d('20'),8)||' SVCNEW='||m~storage~fetchHex(x2d('60'),8)
ms=m~state; cs=m~cpu~state; ks=m~clock~state; ss=m~storage~state; hs=m~channels~state; d350s=m~channels~device(x2d('350'))~state; d1fs=m~channels~device(x2d('001F'))~state
aps=.array~new; do num over m~channels~activeProgramNumbers; row=.directory~new; row['number']=num; row['state']=m~channels~activeProgram(num)~state; aps~append(row); end
if hs['pendingInterruptCount']<>0 | hs['completedStatusCount']<>0 then do; call emit 'FAIL channel handoff pending status'; exit 3; end
js=.IBM370JournaledStorage~new(16777216,2048,'MVT-S17-C4-RAM'); jm=.IBM4361Machine~new(16777216,js)
jd=.IBM3330Device~new(x2d('350'),media); jd~restoreState(d350s); jc=.IBM3215Device~new(x2d('001F')); jc~restoreState(d1fs); jm~attachDevice(jd); jm~attachDevice(jc)
jm~restoreMachineState(ms); jm~cpu~restoreState(cs); jm~clock~restoreState(ks); jm~storage~restoreState(ss); jm~channels~restoreState(hs)
do row over aps; ps=row['state']; p=.IBM370ChannelProgram~new(row['number'],ps['currentCCWAddress'],ps['kind']); p~restoreState(ps); jm~channels~restoreActiveProgram(p); end
if jm~cpu~psw~rawHex<>m~cpu~psw~rawHex | jm~cpu~instructionCount<>m~cpu~instructionCount | jm~storage~fetchHex(0,256)<>m~storage~fetchHex(0,256) then do; call emit 'FAIL handoff mismatch'; exit 4; end
do r=0 to 15; if jm~cpu~gpr(r)<>m~cpu~gpr(r) then do; call emit 'FAIL GPR'||r; exit 4; end; end
call emit 'HANDOFF OK IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex
prePSW=jm~cpu~psw~rawHex; preIC=jm~cpu~instructionCount; preOld=jm~storage~fetchHex(x2d('28'),8)
s=.IBM4361JournalSession~new(jm); s~beginInstruction
first=jm~tick; call emit 'FIRST ST='||first||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
if first<>'UNSUPPORTED' then do; call emit 'FAIL first C4 not unsupported'; exit 5; end
classifier="numeric digits 30; use strict arg raw; op=raw~left(2)~translate; return op='00' | op='FF' | op='C4'"
call emit 'PATCH classifier='||jm~executor~installLiveMethod('architecturalOperationException',classifier)||' OPC4='||jm~executor~hasMethod('OPC4')
jm~cpu~setGpr(5,x2d('DEADBEEF')); jm~storage~storeHex(x2d('1234'),'A55A'); s~abortInstruction
call emit 'REWIND IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' OLD='||jm~storage~fetchHex(x2d('28'),8)||' R5='||d2x(jm~cpu~gpr(5),8)||' M1234='||jm~storage~fetchHex(x2d('1234'),2)
if jm~cpu~psw~rawHex<>prePSW | jm~cpu~instructionCount<>preIC | jm~storage~fetchHex(x2d('28'),8)<>preOld then do; call emit 'FAIL rewind mismatch'; exit 6; end
s~beginInstruction; retry=jm~tick; s~commitInstruction
old=jm~storage~fetchHex(x2d('28'),8); call emit 'RETRY ST='||retry||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' PGMOLD='||old||' PGMNEW='||jm~storage~fetchHex(x2d('68'),8)||' OPC4='||jm~executor~hasMethod('OPC4')
if retry<>'OK' | old<>'00040001E0000048' | jm~cpu~psw~rawHex<>'00040000000002CA' then do; call emit 'FAIL C4 operation retry'; exit 7; end
pst='OK'
do k=1 to 50000
  pia=jm~cpu~psw~instructionAddress; pic=jm~cpu~instructionCount; pst=jm~tick
  if pst<>'OK' then do; pinst=jm~storage~fetchHex(pia,6); call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||jm~cpu~instructionCount||' PREIC='||pic||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||jm~cpu~psw~rawHex||' ST='||pst; leave; end
end
if pst='OK' then call emit 'NEXT none within 50000 ticks IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
call emit 'END'; call lineout log; say 'PASS probe_mvt_c4_program_interrupt_journal_handoff log='log; exit 0
emit: parse arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
