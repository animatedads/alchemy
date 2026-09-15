/* Safety24: exact EX @ 0004B6 target invalid-R1 STE specification propagation. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/s370_cont/media/MVTRES.350'
if log='' then log='evidence/mvt_safety24_ex_target_specification_journal_handoff.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
oldStep=readText('evidence/safety24_step_pre_promotion.rexsrc')
call truth m~executor~installLiveMethod('step',oldStep),'install pre-Safety24 step on lead-in machine'
call emit 'START FAST OP70='||m~executor~hasMethod('OP70')
found=0
do n=1 to 900000
  ia=m~cpu~psw~instructionAddress; ic=m~cpu~instructionCount; st=m~tick
  if st<>'OK' then do
    inst=m~storage~fetchHex(ia,6); call emit 'FAST STOP n='||n||' IA='||d2x(ia,6)||' PREIC='||ic||' IC='||m~cpu~instructionCount||' INST='||inst||' ST='||st||' PSW='||m~cpu~psw~rawHex||' LAST='||m~executor~lastInstruction
    if ia=x2d('4B6') & inst~left(8)='440004F4' & m~cpu~instructionCount=539205 then found=1
    leave
  end
end
if \found then do; call emit 'FAIL expected EX target frontier not reached'; exit 2; end
call emit 'LOWCORE PGMOLD='||m~storage~fetchHex(x2d('28'),8)||' PGMNEW='||m~storage~fetchHex(x2d('68'),8)||' SVCOLD='||m~storage~fetchHex(x2d('20'),8)||' SVCNEW='||m~storage~fetchHex(x2d('60'),8)
ms=m~state; cs=m~cpu~state; ks=m~clock~state; ss=m~storage~state; hs=m~channels~state; d350s=m~channels~device(x2d('350'))~state; d1fs=m~channels~device(x2d('001F'))~state
aps=.array~new; do num over m~channels~activeProgramNumbers; row=.directory~new; row['number']=num; row['state']=m~channels~activeProgram(num)~state; aps~append(row); end
if hs['pendingInterruptCount']<>0 | hs['completedStatusCount']<>0 then do; call emit 'FAIL channel handoff pending status'; exit 3; end
js=.IBM370JournaledStorage~new(16777216,2048,'MVT-S24-EX-RAM'); jm=.IBM4361Machine~new(16777216,js)
jd=.IBM3330Device~new(x2d('350'),media); jd~restoreState(d350s); jc=.IBM3215Device~new(x2d('001F')); jc~restoreState(d1fs); jm~attachDevice(jd); jm~attachDevice(jc)
jm~restoreMachineState(ms); jm~cpu~restoreState(cs); jm~clock~restoreState(ks); jm~storage~restoreState(ss); jm~channels~restoreState(hs)
do row over aps; ps=row['state']; p=.IBM370ChannelProgram~new(row['number'],ps['currentCCWAddress'],ps['kind']); p~restoreState(ps); jm~channels~restoreActiveProgram(p); end
call truth jm~executor~installLiveMethod('step',oldStep),'install pre-Safety24 step on journal machine'
if jm~cpu~psw~rawHex<>m~cpu~psw~rawHex | jm~cpu~instructionCount<>m~cpu~instructionCount | jm~storage~fetchHex(0,256)<>m~storage~fetchHex(0,256) then do; call emit 'FAIL handoff mismatch'; exit 4; end
do r=0 to 15; if jm~cpu~gpr(r)<>m~cpu~gpr(r) then do; call emit 'FAIL GPR'||r; exit 4; end; end
call emit 'HANDOFF OK IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' TARGET='||jm~storage~fetchHex(x2d('4F4'),6)
prePSW=jm~cpu~psw~rawHex; preIC=jm~cpu~instructionCount; preOld=jm~storage~fetchHex(x2d('28'),8); preR5=jm~cpu~gpr(5); preDirty=jm~storage~fetchHex(x2d('1234'),2)
s=.IBM4361JournalSession~new(jm); s~beginInstruction
first=jm~tick; call emit 'FIRST ST='||first||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' STATUS='||jm~executor~lastStatus||' LAST='||jm~executor~lastInstruction
if first<>'UNSUPPORTED' | jm~executor~lastStatus<>'UNSUPPORTED_EX_TARGET' then do; call emit 'FAIL first EX not unsupported target'; exit 5; end
source=readText('evidence/safety24_step_candidate.rexsrc')
call emit 'PATCH step='||jm~executor~installLiveMethod('step',source)||' OP70='||jm~executor~hasMethod('OP70')
jm~cpu~setGpr(5,x2d('DEADBEEF')); jm~storage~storeHex(x2d('1234'),'A55A'); s~abortInstruction
call emit 'REWIND IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' OLD='||jm~storage~fetchHex(x2d('28'),8)||' R5='||d2x(jm~cpu~gpr(5),8)||' M1234='||jm~storage~fetchHex(x2d('1234'),2)
if jm~cpu~psw~rawHex<>prePSW | jm~cpu~instructionCount<>preIC | jm~storage~fetchHex(x2d('28'),8)<>preOld | jm~cpu~gpr(5)<>preR5 | jm~storage~fetchHex(x2d('1234'),2)<>preDirty then do; call emit 'FAIL rewind mismatch'; exit 6; end
s~beginInstruction; retry=jm~tick; s~commitInstruction
old=jm~storage~fetchHex(x2d('28'),8); call emit 'RETRY ST='||retry||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' PGMOLD='||old||' PGMNEW='||jm~storage~fetchHex(x2d('68'),8)||' LAST='||jm~executor~lastInstruction||' OP70='||jm~executor~hasMethod('OP70')
if retry<>'OK' | old<>'00040006800004BA' | jm~cpu~psw~rawHex<>'00040000000002CA' | jm~cpu~instructionCount<>539206 then do; call emit 'FAIL EX target specification retry'; exit 7; end
call truth jm~executor~removeLiveMethod('step'),'remove live step after proof'
pst='OK'
do k=1 to 100000
  pia=jm~cpu~psw~instructionAddress; pic=jm~cpu~instructionCount; pst=jm~tick
  if pst<>'OK' then do
    pinst=jm~storage~fetchHex(pia,6); call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||jm~cpu~instructionCount||' PREIC='||pic||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||jm~cpu~psw~rawHex||' ST='||pst||' LAST='||jm~executor~lastInstruction; leave
  end
end
if pst='OK' then call emit 'NEXT none within 100000 ticks IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
call emit 'END'; call lineout log; say 'PASS probe_mvt_safety24_ex_target_specification_journal_handoff log='log; exit 0
readText: procedure
  use arg path
  text=''
  do while lines(path)>0; text=text||linein(path)||';'; end
  call lineout path
  return text
emit: use arg line; say line; call lineout log,line; call lineout log; return
truth: use arg x,label; if \x then do; say 'FAIL' label; exit 1; end; return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
