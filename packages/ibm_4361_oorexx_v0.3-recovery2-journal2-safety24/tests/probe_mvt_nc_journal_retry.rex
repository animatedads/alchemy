/* SAFETY13 ARCHAEOLOGY: exact real-MVT X'D4' NC/And Character rewind/live-retry. */
/* PRE-PROMOTION PROBE: run with the sealed safety12 IBM class path so the
 * first D4 dispatch is genuinely UNSUPPORTED.  Under safety13 OPD4 is native. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt11/mvtres.350'
if log='' then log='/mnt/data/mvt_safety13_nc_journal_retry.log'
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
  if ia=x2d('00660C') & m~cpu~instructionCount=513044 then do; found=1; leave; end
  st=m~tick
  if st<>'OK' then do; call emit 'EARLY STOP n='||n||' IA='||d2x(ia,6)||' IC='||m~cpu~instructionCount||' ST='||st||' INST='||m~storage~fetchHex(ia,6); leave; end
end
if \found then do; call emit 'FAIL frontier not reached'; exit 2; end
inst=m~storage~fetchHex(ia,6)
l=x2d(inst~substr(3,2))+1; b1=x2d(inst~substr(5,1)); d1=x2d(inst~substr(6,3)); b2=x2d(inst~substr(9,1)); d2=x2d(inst~substr(10,3))
a1=d1; if b1<>0 then a1=a1+m~cpu~gpr(b1); a1=a1//16777216
a2=d2; if b2<>0 then a2=a2+m~cpu~gpr(b2); a2=a2//16777216
prePSW=m~cpu~psw~rawHex; preIC=m~cpu~instructionCount; preCC=m~cpu~psw~conditionCode; dst=m~storage~fetchHex(a1,l); src=m~storage~fetchHex(a2,l)
call emit 'FRONTIER n='||n||' IA='||d2x(ia,6)||' IC='||preIC||' INST='||inst||' PSW='||prePSW||' L='||l||' B1='||b1||' A1='||d2x(a1,6)||' DST='||dst||' B2='||b2||' A2='||d2x(a2,6)||' SRC='||src||' CC='||preCC
session=.IBM4361JournalSession~new(m)
session~beginInstruction
first=m~tick
call emit 'FIRST ST='||first||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount
if first<>'UNSUPPORTED' then do; call emit 'FAIL first was not unsupported'; exit 3; end
source="expose cpu storage; numeric digits 30; use strict arg i,ia,t=0; f=self~ssFields(i); a1=self~eaBD(f[2],f[3]); a2=self~eaBD(f[4],f[5]); nz=0; do n=0 to f[1]-1; d=(a1+n)//16777216; s=(a2+n)//16777216; v=c2x(bitand(x2c(storage~fetchHex(d,1)),x2c(storage~fetchHex(s,1)))); storage~storeHex(d,v); if v<>'00' then nz=1; end; cpu~psw~setConditionCode(nz); return ia+6"
installed=m~executor~installLiveMethod('OPD4',source)
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A')
session~abortInstruction
call emit 'PATCH installed='||installed||' REWIND IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' DST='||m~storage~fetchHex(a1,l)||' CC='||m~cpu~psw~conditionCode||' R5='||d2x(m~cpu~gpr(5),8)||' M1234='||m~storage~fetchHex(x2d('1234'),2)
if m~cpu~psw~rawHex<>prePSW | m~cpu~instructionCount<>preIC | m~storage~fetchHex(a1,l)<>dst then do; call emit 'FAIL rewind mismatch'; exit 4; end
session~beginInstruction
retry=m~tick
session~commitInstruction
call emit 'RETRY ST='||retry||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' DST='||m~storage~fetchHex(a1,l)||' CC='||m~cpu~psw~conditionCode||' SRC='||m~storage~fetchHex(a2,l)
if retry<>'OK' then do; call emit 'FAIL retry'; exit 5; end
pst='OK'
do k=1 to 5000
  pia=m~cpu~psw~instructionAddress; pic=m~cpu~instructionCount
  pst=m~tick
  if pst<>'OK' then do; pinst=m~storage~fetchHex(pia,6); call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||m~cpu~instructionCount||' PREIC='||pic||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||pst; leave; end
end
call emit 'END'; call lineout log
say 'PASS probe_mvt_nc_journal_retry log='log
exit 0
emit: parse arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
