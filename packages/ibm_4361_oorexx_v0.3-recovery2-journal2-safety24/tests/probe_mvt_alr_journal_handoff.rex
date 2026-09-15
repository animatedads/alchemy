/* Safety15: fast known lead-in through permanent safety14 program interrupt,
 * then exact state handoff to journal RAM for ALR live retry. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media14/mvtres.350'
if log='' then log='/mnt/data/mvt_safety15_alr_journal_handoff.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START FAST'
found=0
do n=1 to 650000
  ia=m~cpu~psw~instructionAddress; ic=m~cpu~instructionCount; st=m~tick
  if st<>'OK' then do
    inst=m~storage~fetchHex(ia,6); call emit 'FAST STOP n='||n||' IA='||d2x(ia,6)||' PREIC='||ic||' IC='||m~cpu~instructionCount||' INST='||inst||' ST='||st||' PSW='||m~cpu~psw~rawHex
    if ia=x2d('01A482') & inst~left(2)='1E' & m~cpu~instructionCount=513307 then found=1
    leave
  end
end
if \found then do; call emit 'FAIL expected ALR frontier not reached'; exit 2; end
inst=m~storage~fetchHex(x2d('01A482'),2); r1=x2d(inst~substr(3,1)); r2=x2d(inst~substr(4,1))
call emit 'FRONTIER INST='||inst||' R1='||r1||' V1='||d2x(m~cpu~gpr(r1),8)||' R2='||r2||' V2='||d2x(m~cpu~gpr(r2),8)||' CC='||m~cpu~psw~conditionCode
ms=m~state; cs=m~cpu~state; ks=m~clock~state; ss=m~storage~state; hs=m~channels~state; d350s=m~channels~device(x2d('350'))~state; d1fs=m~channels~device(x2d('001F'))~state
aps=.array~new; do num over m~channels~activeProgramNumbers; row=.directory~new; row['number']=num; row['state']=m~channels~activeProgram(num)~state; aps~append(row); end
if hs['pendingInterruptCount']<>0 | hs['completedStatusCount']<>0 then do; call emit 'FAIL channel handoff pending status'; exit 3; end
js=.IBM370JournaledStorage~new(16777216,2048,'MVT-S15-ALR-RAM'); jm=.IBM4361Machine~new(16777216,js)
jd=.IBM3330Device~new(x2d('350'),media); jd~restoreState(d350s); jc=.IBM3215Device~new(x2d('001F')); jc~restoreState(d1fs); jm~attachDevice(jd); jm~attachDevice(jc)
jm~restoreMachineState(ms); jm~cpu~restoreState(cs); jm~clock~restoreState(ks); jm~storage~restoreState(ss); jm~channels~restoreState(hs)
do row over aps; ps=row['state']; p=.IBM370ChannelProgram~new(row['number'],ps['currentCCWAddress'],ps['kind']); p~restoreState(ps); jm~channels~restoreActiveProgram(p); end
if jm~cpu~psw~rawHex<>m~cpu~psw~rawHex | jm~storage~fetchHex(0,256)<>m~storage~fetchHex(0,256) then do; call emit 'FAIL handoff mismatch'; exit 4; end
call emit 'HANDOFF OK IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
prePsw=jm~cpu~psw~rawHex; preIc=jm~cpu~instructionCount; preR=jm~cpu~gpr(r1); preCC=jm~cpu~psw~conditionCode
session=.IBM4361JournalSession~new(jm); session~beginInstruction
first=jm~tick; call emit 'FIRST ST='||first||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
if first<>'UNSUPPORTED' then do; call emit 'FAIL first ALR not unsupported'; exit 5; end
source="expose cpu; numeric digits 30; use strict arg i,ia,t=0; f=self~rr(i); a=cpu~gprFast(f[1]); b=cpu~gprFast(f[2]); exact=a+b; carry=(exact>=4294967296); v=exact//4294967296; cpu~setGprFast(f[1],v); if carry then do; if v=0 then cc=2; else cc=3; end; else do; if v=0 then cc=0; else cc=1; end; cpu~psw~setConditionCode(cc); return ia+2"
call emit 'PATCH installed='||jm~executor~installLiveMethod('OP1E',source)
jm~cpu~setGpr(5,x2d('DEADBEEF')); jm~storage~storeHex(x2d('1234'),'A55A'); session~abortInstruction
call emit 'REWIND IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' V1='||d2x(jm~cpu~gpr(r1),8)||' CC='||jm~cpu~psw~conditionCode||' R5='||d2x(jm~cpu~gpr(5),8)||' M1234='||jm~storage~fetchHex(x2d('1234'),2)||' METHOD='||jm~executor~hasMethod('OP1E')
if jm~cpu~psw~rawHex<>prePsw | jm~cpu~instructionCount<>preIc | jm~cpu~gpr(r1)<>preR | jm~cpu~psw~conditionCode<>preCC then do; call emit 'FAIL rewind mismatch'; exit 6; end
session~beginInstruction; retry=jm~tick; session~commitInstruction
call emit 'RETRY ST='||retry||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' V1='||d2x(jm~cpu~gpr(r1),8)||' CC='||jm~cpu~psw~conditionCode
if retry<>'OK' then do; call emit 'FAIL retry'; exit 7; end
pst='OK'
do k=1 to 30000
  pia=jm~cpu~psw~instructionAddress; pic=jm~cpu~instructionCount; pst=jm~tick
  if pst<>'OK' then do; pinst=jm~storage~fetchHex(pia,6); call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||jm~cpu~instructionCount||' PREIC='||pic||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||jm~cpu~psw~rawHex||' ST='||pst; leave; end
end
if pst='OK' then call emit 'NEXT none within 30000 ticks IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
call emit 'END'; call lineout log; say 'PASS probe_mvt_alr_journal_handoff log='log; exit 0
emit: parse arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
