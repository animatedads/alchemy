/* Safety19: exact X'5D' odd-R1 specification-exception journal trial. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt19/os360mvt/dasd/mvtres.350'
if log='' then log='/mnt/data/mvt_safety19_5d_spec_journal_handoff.log'
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
    if ia=x2d('5E') & inst~left(2)='5D' & m~cpu~instructionCount=531376 then found=1
    leave
  end
end
if \found then do; call emit 'FAIL expected 5D frontier not reached'; exit 2; end
inst=m~storage~fetchHex(x2d('5E'),4); r1=x2d(inst~substr(3,1)); x2=x2d(inst~substr(4,1)); b2=x2d(inst~substr(5,1)); d2=x2d(inst~substr(6,3)); ea=d2; if x2<>0 then ea=ea+m~cpu~gpr(x2); if b2<>0 then ea=ea+m~cpu~gpr(b2); ea=ea//16777216
call emit 'FRONTIER R1='||r1||' X2='||x2||' B2='||b2||' EA='||d2x(ea,6)||' DIVISOR='||m~storage~fetchHex(ea,4)||' R11='||d2x(m~cpu~gpr(11),8)||' R12='||d2x(m~cpu~gpr(12),8)||' CC='||m~cpu~psw~conditionCode
ms=m~state; cs=m~cpu~state; ks=m~clock~state; ss=m~storage~state; hs=m~channels~state; d350s=m~channels~device(x2d('350'))~state; d1fs=m~channels~device(x2d('001F'))~state
aps=.array~new; do num over m~channels~activeProgramNumbers; row=.directory~new; row['number']=num; row['state']=m~channels~activeProgram(num)~state; aps~append(row); end
if hs['pendingInterruptCount']<>0 | hs['completedStatusCount']<>0 then do; call emit 'FAIL channel handoff pending status'; exit 3; end
js=.IBM370JournaledStorage~new(16777216,2048,'MVT-S19-5D-RAM'); jm=.IBM4361Machine~new(16777216,js)
jd=.IBM3330Device~new(x2d('350'),media); jd~restoreState(d350s); jc=.IBM3215Device~new(x2d('001F')); jc~restoreState(d1fs); jm~attachDevice(jd); jm~attachDevice(jc)
jm~restoreMachineState(ms); jm~cpu~restoreState(cs); jm~clock~restoreState(ks); jm~storage~restoreState(ss); jm~channels~restoreState(hs)
do row over aps; ps=row['state']; p=.IBM370ChannelProgram~new(row['number'],ps['currentCCWAddress'],ps['kind']); p~restoreState(ps); jm~channels~restoreActiveProgram(p); end
if jm~cpu~psw~rawHex<>m~cpu~psw~rawHex | jm~cpu~instructionCount<>m~cpu~instructionCount | jm~storage~fetchHex(0,256)<>m~storage~fetchHex(0,256) then do; call emit 'FAIL handoff mismatch'; exit 4; end
do r=0 to 15; if jm~cpu~gpr(r)<>m~cpu~gpr(r) then do; call emit 'FAIL GPR'||r; exit 4; end; end
call emit 'HANDOFF OK IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex
prePSW=jm~cpu~psw~rawHex; preIC=jm~cpu~instructionCount; preOld=jm~storage~fetchHex(x2d('28'),8); preR11=jm~cpu~gpr(11); preDiv=jm~storage~fetchHex(ea,4)
s=.IBM4361JournalSession~new(jm); s~beginInstruction
first=jm~tick; call emit 'FIRST ST='||first||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
if first<>'UNSUPPORTED' then do; call emit 'FAIL first 5D not unsupported'; exit 5; end
classifier="numeric digits 30; use strict arg raw; if raw~length<4 then return .false; return raw~left(2)~translate='5D' & (x2d(raw~substr(3,1))//2=1)"
deliver="expose cpu storage; numeric digits 30; use strict arg inst,ia,len; if cpu~psw~ecMode then return 'UNSUPPORTED'; cpu~psw~setInstructionLength(len); cpu~psw~setInstructionAddress((ia+len)//16777216); old=cpu~psw~rawWithInterruptionCode(6); base=cpu~prefix; storage~storeHex((base+x2d('28'))//16777216,old); new=storage~fetchHex((base+x2d('68'))//16777216,8); cpu~psw~loadRawHex(new); return 'OK'"
call emit 'PATCH classifier='||jm~executor~installLiveMethod('architecturalSpecificationException',classifier)||' delivery='||jm~executor~installLiveMethod('programInterruptSpecification',deliver)||' OP5D='||jm~executor~hasMethod('OP5D')
jm~cpu~setGpr(5,x2d('DEADBEEF')); jm~storage~storeHex(x2d('1234'),'A55A'); s~abortInstruction
call emit 'REWIND IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' OLD='||jm~storage~fetchHex(x2d('28'),8)||' R5='||d2x(jm~cpu~gpr(5),8)||' M1234='||jm~storage~fetchHex(x2d('1234'),2)
if jm~cpu~psw~rawHex<>prePSW | jm~cpu~instructionCount<>preIC | jm~storage~fetchHex(x2d('28'),8)<>preOld | jm~cpu~gpr(11)<>preR11 | jm~storage~fetchHex(ea,4)<>preDiv then do; call emit 'FAIL rewind mismatch'; exit 6; end
s~beginInstruction; retry=jm~tick; s~commitInstruction
old=jm~storage~fetchHex(x2d('28'),8); call emit 'RETRY ST='||retry||' IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount||' PSW='||jm~cpu~psw~rawHex||' PGMOLD='||old||' PGMNEW='||jm~storage~fetchHex(x2d('68'),8)||' R11='||d2x(jm~cpu~gpr(11),8)||' DIVISOR='||jm~storage~fetchHex(ea,4)||' OP5D='||jm~executor~hasMethod('OP5D')
if retry<>'OK' | old<>'00040006A0000062' | jm~cpu~psw~rawHex<>'00040000000002CA' | jm~cpu~gpr(11)<>preR11 | jm~storage~fetchHex(ea,4)<>preDiv then do; call emit 'FAIL 5D specification retry'; exit 7; end
pst='OK'
do k=1 to 100000
  pia=jm~cpu~psw~instructionAddress; pic=jm~cpu~instructionCount; pst=jm~tick
  if pst<>'OK' then do; pinst=jm~storage~fetchHex(pia,6); call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||jm~cpu~instructionCount||' PREIC='||pic||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||jm~cpu~psw~rawHex||' ST='||pst; leave; end
end
if pst='OK' then call emit 'NEXT none within 100000 ticks IA='||d2x(jm~cpu~psw~instructionAddress,6)||' IC='||jm~cpu~instructionCount
call emit 'END'; call lineout log; say 'PASS probe_mvt_safety19_5d_spec_journal_handoff log='log; exit 0
emit: use arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
