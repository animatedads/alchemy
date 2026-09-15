/* SAFETY10 ARCHAEOLOGY: exact real-MVT NR rewind/live-retry. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media/mvtres_uncompressed.350'
if log='' then log='/mnt/data/mvt_safety10_nr_journal_retry.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','PROBE-LOGICAL-EQUIVALENT')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
storage=.IBM370JournaledStorage~new(16777216,2048,'MVT-S10-NR-RAM')
m=.IBM4361Machine~new(16777216,storage)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START'
found=0
do n=1 to 300000
  ia=m~cpu~psw~instructionAddress
  if ia=x2d('01464C') & m~cpu~instructionCount=511897 then do; found=1; leave; end
  st=m~tick
  if st<>'OK' then do; call emit 'EARLY STOP n='||n||' IA='||d2x(ia,6)||' IC='||m~cpu~instructionCount||' ST='||st||' INST='||m~storage~fetchHex(ia,6); leave; end
end
if \found then do; call emit 'FAIL frontier not reached'; exit 2; end
inst=m~storage~fetchHex(ia,6); prePSW=m~cpu~psw~rawHex; preIC=m~cpu~instructionCount; preR2=m~cpu~gpr(2); preR0=m~cpu~gpr(0); preCC=m~cpu~psw~conditionCode
call emit 'FRONTIER n='||n||' IA='||d2x(ia,6)||' IC='||preIC||' INST='||inst||' PSW='||prePSW||' R2='||d2x(preR2,8)||' R0='||d2x(preR0,8)||' CC='||preCC
session=.IBM4361JournalSession~new(m)
session~beginInstruction
first=m~tick
call emit 'FIRST ST='||first||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount
if first<>'UNSUPPORTED' then do; call emit 'FAIL first was not unsupported'; exit 3; end
source="expose cpu; numeric digits 30; use strict arg i,ia,t=0; f=self~rr(i); v=c2d(bitand(d2c(self~s32(cpu~gprFast(f[1])),4),d2c(self~s32(cpu~gprFast(f[2])),4))); cpu~setGprFast(f[1],v); self~ccLogical(v); return ia+2"
installed=m~executor~installLiveMethod('OP14',source)
/* prove architectural dirt rewinds while the executable hypothesis survives */
m~cpu~setGpr(5,x2d('DEADBEEF')); m~storage~storeHex(x2d('1234'),'A55A')
session~abortInstruction
call emit 'PATCH installed='||installed||' REWIND IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' R2='||d2x(m~cpu~gpr(2),8)||' R0='||d2x(m~cpu~gpr(0),8)||' CC='||m~cpu~psw~conditionCode||' METHOD='||m~executor~hasMethod('OP14')||' R5='||d2x(m~cpu~gpr(5),8)||' M1234='||m~storage~fetchHex(x2d('1234'),2)
if m~cpu~psw~rawHex<>prePSW | m~cpu~instructionCount<>preIC | m~cpu~gpr(2)<>preR2 | m~cpu~gpr(0)<>preR0 then do; call emit 'FAIL rewind mismatch'; exit 4; end
session~beginInstruction
retry=m~tick
session~commitInstruction
call emit 'RETRY ST='||retry||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' R2='||d2x(m~cpu~gpr(2),8)||' R0='||d2x(m~cpu~gpr(0),8)||' CC='||m~cpu~psw~conditionCode
if retry<>'OK' then do; call emit 'FAIL retry'; exit 5; end
pst='OK'
do k=1 to 5000
  pia=m~cpu~psw~instructionAddress; pinst=m~storage~fetchHex(pia,6)
  pst=m~tick
  if pst<>'OK' then do; call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||m~cpu~instructionCount||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||pst; leave; end
end
if pst='OK' then call emit 'NEXT none within 5000 ticks IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount
call emit 'END'; call lineout log
say 'PASS probe_mvt_nr_journal_retry log='log
exit 0
emit:
  parse arg line
  say line; call lineout log,line; call lineout log
return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
