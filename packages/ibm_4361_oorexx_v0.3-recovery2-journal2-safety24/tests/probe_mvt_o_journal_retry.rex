/* SAFETY12 ARCHAEOLOGY: exact real-MVT X'56' O/Or rewind/live-retry. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt11/mvtres.350'
if log='' then log='/mnt/data/mvt_safety12_o_journal_retry.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
storage=.IBM370JournaledStorage~new(16777216,2048,'MVT-S12-O-RAM')
m=.IBM4361Machine~new(16777216,storage)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START'
found=0
do n=1 to 300000
  ia=m~cpu~psw~instructionAddress
  if ia=x2d('0146FC') & m~cpu~instructionCount=512240 then do; found=1; leave; end
  st=m~tick
  if st<>'OK' then do; call emit 'EARLY STOP n='||n||' IA='||d2x(ia,6)||' IC='||m~cpu~instructionCount||' ST='||st||' INST='||m~storage~fetchHex(ia,6); leave; end
end
if \found then do; call emit 'FAIL frontier not reached'; exit 2; end
inst=m~storage~fetchHex(ia,6)
r=x2d(inst~substr(3,1)); x=x2d(inst~substr(4,1)); b=x2d(inst~substr(5,1)); d=x2d(inst~substr(6,3))
ea=d; if x<>0 then ea=ea+m~cpu~gpr(x); if b<>0 then ea=ea+m~cpu~gpr(b); ea=ea//16777216
prePSW=m~cpu~psw~rawHex; preIC=m~cpu~instructionCount; preR=m~cpu~gpr(r); preCC=m~cpu~psw~conditionCode; operand=m~storage~fetchHex(ea,4)
call emit 'FRONTIER n='||n||' IA='||d2x(ia,6)||' IC='||preIC||' INST='||inst||' PSW='||prePSW||' R='||r||' RV='||d2x(preR,8)||' X='||x||' XV='||d2x(m~cpu~gpr(x),8)||' B='||b||' CC='||preCC||' EA='||d2x(ea,6)||' MEM='||operand
session=.IBM4361JournalSession~new(m)
session~beginInstruction
first=m~tick
call emit 'FIRST ST='||first||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount
if first<>'UNSUPPORTED' then do; call emit 'FAIL first was not unsupported'; exit 3; end
source="expose cpu storage; numeric digits 30; use strict arg i,ia,t=0; f=self~rxFields(i); ea=self~eaRX(f[2],f[3],f[4]); v=c2d(bitor(d2c(cpu~gprFast(f[1]),4),x2c(storage~fetchHex(ea,4)))); cpu~setGprFast(f[1],v); self~ccLogical(v); return ia+4"
installed=m~executor~installLiveMethod('OP56',source)
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A')
session~abortInstruction
call emit 'PATCH installed='||installed||' REWIND IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' RV='||d2x(m~cpu~gpr(r),8)||' CC='||m~cpu~psw~conditionCode||' R5='||d2x(m~cpu~gpr(5),8)||' M1234='||m~storage~fetchHex(x2d('1234'),2)
if m~cpu~psw~rawHex<>prePSW | m~cpu~instructionCount<>preIC | m~cpu~gpr(r)<>preR then do; call emit 'FAIL rewind mismatch'; exit 4; end
session~beginInstruction
retry=m~tick
session~commitInstruction
call emit 'RETRY ST='||retry||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' RV='||d2x(m~cpu~gpr(r),8)||' CC='||m~cpu~psw~conditionCode||' MEM='||m~storage~fetchHex(ea,4)
if retry<>'OK' then do; call emit 'FAIL retry'; exit 5; end
pst='OK'
do k=1 to 5000
  pia=m~cpu~psw~instructionAddress; pic=m~cpu~instructionCount
  pst=m~tick
  if pst<>'OK' then do; pinst=m~storage~fetchHex(pia,6); call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||m~cpu~instructionCount||' PREIC='||pic||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||pst; leave; end
end
call emit 'END'; call lineout log
say 'PASS probe_mvt_o_journal_retry log='log
exit 0
emit: parse arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
