/* Safety20: exact X'D1' MVN journal trial from sealed Safety19. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/s370_resume/media/MVTRES.350'
if log='' then log='/mnt/data/s370_resume/mvt_safety20_d1_mvn_journal_handoff.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START FAST'
found=0
do n=1 to 900000
  ia=m~cpu~psw~instructionAddress; ic=m~cpu~instructionCount; st=m~tick
  if st<>'OK' then do
    inst=m~storage~fetchHex(ia,6); call emit 'FAST STOP n='||n||' IA='||d2x(ia,6)||' PREIC='||ic||' IC='||m~cpu~instructionCount||' INST='||inst||' ST='||st||' PSW='||m~cpu~psw~rawHex
    if ia=x2d('47C') & inst~left(2)='D1' & m~cpu~instructionCount=531395 then found=1
    leave
  end
end
if \found then do; call emit 'FAIL expected D1 frontier not reached'; exit 2; end
inst=m~storage~fetchHex(x2d('47C'),6)
l=x2d(inst~substr(3,2))+1; b1=x2d(inst~substr(5,1)); d1=x2d(inst~substr(6,3)); b2=x2d(inst~substr(9,1)); d2=x2d(inst~substr(10,3))
a1=d1; if b1<>0 then a1=(a1+m~cpu~gpr(b1))//16777216
a2=d2; if b2<>0 then a2=(a2+m~cpu~gpr(b2))//16777216
preDst=m~storage~fetchHex(a1,l); preSrc=m~storage~fetchHex(a2,l); preCC=m~cpu~psw~conditionCode
call emit 'FRONTIER LEN='||l||' B1='||b1||' D1='||d2x(d1,3)||' A1='||d2x(a1,6)||' DST='||preDst||' B2='||b2||' D2='||d2x(d2,3)||' A2='||d2x(a2,6)||' SRC='||preSrc||' CC='||preCC
ms=m~state; cs=m~cpu~state; ks=m~clock~state; ss=m~storage~state; hs=m~channels~state; d350s=m~channels~device(x2d('350'))~state; d1fs=m~channels~device(x2d('001F'))~state
aps=.array~new; do num over m~channels~activeProgramNumbers; row=.directory~new; row['number']=num; row['state']=m~channels~activeProgram(num)~state; aps~append(row); end
if hs['pendingInterruptCount']<>0 | hs['completedStatusCount']<>0 then do; call emit 'FAIL channel handoff pending status'; exit 3; end
js=.IBM370JournaledStorage~new(16777216,2048,'MVT-S20-D1-RAM'); jm=.IBM4361Machine~new(16777216,js)
jd=.IBM3330Device~new(x2d('350'),media); jd~restoreState(d350s); jc=.IBM3215Device~new(x2d('001F')); jc~restoreState(d1fs); jm~attachDevice(jd); jm~attachDevice(jc)
jm~restoreMachineState(ms); jm~cpu~restoreState(cs); jm~clock~restoreState(ks); jm~storage~restoreState(ss); jm~channels~restoreState(hs)
do row over aps; ps=row['state']; p=.IBM370ChannelProgram~new(row['number'],ps['currentCCWAddress'],ps['kind']); p~restoreState(ps); jm~channels~restoreActiveProgram(p); end
if jm~cpu~psw~rawHex<>m~cpu~psw~rawHex | jm~cpu~instructionCount<>m~cpu~instructionCount | jm~storage~fetchHex(0,256)<>m~storage~fetchHex(0,256) then do; call emit 'FAIL handoff mismatch'; exit 4; end
do r=0 to 15; if jm~cpu~gpr(r)<>m~cpu~gpr(r) then do; call emit 'FAIL GPR'||r; exit 4; end; end
call emit 'HANDOFF OK IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex
prePSW=jm~cpu~psw~rawHex; preIC=jm~cpu~instructionCount; preDst=jm~storage~fetchHex(a1,l); preSrc=jm~storage~fetchHex(a2,l); preCC=jm~cpu~psw~conditionCode; preR5=jm~cpu~gpr(5); preDirty=jm~storage~fetchHex(x2d('1234'),2)
s=.IBM4361JournalSession~new(jm); s~beginInstruction
first=jm~tick; call emit 'FIRST ST='||first||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
if first<>'UNSUPPORTED' then do; call emit 'FAIL first D1 not unsupported'; exit 5; end
source="expose storage; numeric digits 30; use strict arg i,ia,t=0; f=self~ssFields(i); a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5]); do n=0 to f[1]-1; d=(a1+n)//16777216; s=(a2+n)//16777216; db=storage~fetchHex(d,1); sb=storage~fetchHex(s,1); storage~storeHex(d,db~left(1)||sb~right(1)); end; return ia+6"
call emit 'PATCH OPD1='||jm~executor~installLiveMethod('OPD1',source)||' HAS='||jm~executor~hasMethod('OPD1')
jm~cpu~setGpr(5,x2d('DEADBEEF')); jm~storage~storeHex(x2d('1234'),'A55A'); s~abortInstruction
call emit 'REWIND IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' R5='||d2x(jm~cpu~gpr(5),8)||' M1234='||jm~storage~fetchHex(x2d('1234'),2)||' HAS='||jm~executor~hasMethod('OPD1')
if jm~cpu~psw~rawHex<>prePSW | jm~cpu~instructionCount<>preIC | jm~storage~fetchHex(a1,l)<>preDst | jm~storage~fetchHex(a2,l)<>preSrc | jm~cpu~psw~conditionCode<>preCC | jm~cpu~gpr(5)<>preR5 | jm~storage~fetchHex(x2d('1234'),2)<>preDirty then do; call emit 'FAIL rewind mismatch'; exit 6; end
expected=''; do n=0 to l-1; expected=expected||preDst~substr(n*2+1,1)||preSrc~substr(n*2+2,1); end
s~beginInstruction; retry=jm~tick; s~commitInstruction
postDst=jm~storage~fetchHex(a1,l); postSrc=jm~storage~fetchHex(a2,l)
call emit 'RETRY ST='||retry||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' DST='||postDst||' SRC='||postSrc||' EXPECT='||expected||' CC='||jm~cpu~psw~conditionCode
if retry<>'OK' | postDst<>expected | jm~cpu~psw~conditionCode<>preCC | jm~cpu~instructionCount<>preIC+1 then do; call emit 'FAIL D1 retry'; exit 7; end
pst='OK'
do k=1 to 200000
  pia=jm~cpu~psw~instructionAddress; pic=jm~cpu~instructionCount; pst=jm~tick
  if pst<>'OK' then do; pinst=jm~storage~fetchHex(pia,6); call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||jm~cpu~instructionCount||' PREIC='||pic||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||jm~cpu~psw~rawHex||' ST='||pst; leave; end
end
if pst='OK' then call emit 'NEXT none within 200000 ticks IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
call emit 'END'; call lineout log; say 'PASS probe_mvt_safety20_d1_mvn_journal_handoff log='log; exit 0
emit: use arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
