/* SAFETY9 ARCHAEOLOGY: exact real-MVT LCR rewind/live-retry. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media/mvtres_uncompressed.350'
if log='' then log='/mnt/data/mvt_safety9_lcr_journal_retry.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','PROBE-LOGICAL-EQUIVALENT')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
storage=.IBM370JournaledStorage~new(16777216,2048,'MVT-S9-LCR-RAM')
m=.IBM4361Machine~new(16777216,storage)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START'
found=0
do n=1 to 300000
  ia=m~cpu~psw~instructionAddress
  if ia=x2d('014FCA') & m~cpu~instructionCount=511869 then do; found=1; leave; end
  st=m~tick
  if st<>'OK' then do; call emit 'EARLY STOP n='||n||' IA='||d2x(ia,6)||' IC='||m~cpu~instructionCount||' ST='||st||' INST='||m~storage~fetchHex(ia,6); leave; end
end
if \found then do; call emit 'FAIL frontier not reached'; exit 2; end
inst=m~storage~fetchHex(ia,6); prePSW=m~cpu~psw~rawHex; preIC=m~cpu~instructionCount; preR7=m~cpu~gpr(7); preCC=m~cpu~psw~conditionCode; prePM=m~cpu~psw~programMask
call emit 'FRONTIER n='||n||' IA='||d2x(ia,6)||' IC='||preIC||' INST='||inst||' PSW='||prePSW||' R7='||d2x(preR7,8)||' CC='||preCC||' PM='||prePM
session=.IBM4361JournalSession~new(m)
session~beginInstruction
first=m~tick
call emit 'FIRST ST='||first||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount
if first<>'UNSUPPORTED' then do; call emit 'FAIL first was not unsupported'; exit 3; end
source="expose cpu; numeric digits 30; use strict arg i,ia,t=0; f=self~rr(i); v=self~s32(cpu~gprFast(f[2])); if v=-2147483648 then do; if cpu~psw~programMask>=8 then raise syntax 40.900 array('LCR fixed-point-overflow interruption path not yet implemented'); cpu~setGprFast(f[1],2147483648); cpu~psw~setConditionCode(3); end; else do; r=-v; cpu~setGprFast(f[1],self~u32(r)); self~ccSigned(r); end; return ia+2"
installed=m~executor~installLiveMethod('OP13',source)
session~abortInstruction
call emit 'PATCH installed='||installed||' REWIND IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' R7='||d2x(m~cpu~gpr(7),8)||' CC='||m~cpu~psw~conditionCode||' METHOD='||m~executor~hasMethod('OP13')
if m~cpu~psw~rawHex<>prePSW | m~cpu~instructionCount<>preIC | m~cpu~gpr(7)<>preR7 then do; call emit 'FAIL rewind mismatch'; exit 4; end
session~beginInstruction
retry=m~tick
session~commitInstruction
call emit 'RETRY ST='||retry||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' R7='||d2x(m~cpu~gpr(7),8)||' CC='||m~cpu~psw~conditionCode
if retry<>'OK' | m~cpu~gpr(7)<>12 | m~cpu~psw~conditionCode<>2 then do; call emit 'FAIL retry'; exit 5; end
pst='OK'
do k=1 to 5000
  pia=m~cpu~psw~instructionAddress; pinst=m~storage~fetchHex(pia,6)
  pst=m~tick
  if pst<>'OK' then do; call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||m~cpu~instructionCount||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||pst; leave; end
end
if pst='OK' then call emit 'NEXT none within 5000 ticks IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount
call emit 'END'; call lineout log
say 'PASS probe_mvt_lcr_journal_retry log='log
exit 0
emit:
  parse arg line
  say line; call lineout log,line; call lineout log
return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
