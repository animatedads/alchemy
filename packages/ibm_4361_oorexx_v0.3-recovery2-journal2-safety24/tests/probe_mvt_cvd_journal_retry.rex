/* PRE-PROMOTION ARCHAEOLOGY PROBE: run against the safety4 executor before permanent OP4E promotion.
 * Safety5 retains this source only to preserve the exact journal experiment; evidence is in evidence/mvt_cvd_journal_retry.log. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media_s5/mvtres_uncompressed.350'
if log='' then log='/mnt/data/mvt_cvd_journal_retry.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','PROBE-LOGICAL-EQUIVALENT')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
storage=.IBM370JournaledStorage~new(16777216,2048,'MVT-S5-RAM')
m=.IBM4361Machine~new(16777216,storage)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START'

do n=1 to 285000
  ia=m~cpu~psw~instructionAddress
  inst=m~storage~fetchHex(ia,6)
  st=m~tick
  if n//50000=0 then call emit 'PROGRESS n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)
  if st<>'OK' then leave
end
call emit 'BOUNDARY n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(ia,6)||' INST='||inst||' OP='||inst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||st
if d2x(ia,6)<>'FF71B0' | m~cpu~instructionCount<>511763 | inst~left(2)<>'4E' then do
  call emit 'FAIL unexpected frontier'; call lineout log; exit 2
end
r1=x2d(inst~substr(3,1)); x2=x2d(inst~substr(4,1)); b2=x2d(inst~substr(5,1)); d2=x2d(inst~substr(6,3))
ea=d2; if x2<>0 then ea=ea+m~cpu~gpr(x2); if b2<>0 then ea=ea+m~cpu~gpr(b2); ea=ea//16777216
preR=m~cpu~gpr(r1); preCC=m~cpu~psw~conditionCode; preMem=m~storage~fetchHex(ea,8); prePSW=m~cpu~psw~rawHex; preIC=m~cpu~instructionCount
call emit 'PRE R='||r1||' RV='||d2x(preR,8)||' X='||x2||' B='||b2||' EA='||d2x(ea,6)||' MEM='||preMem||' CC='||preCC

session=.IBM4361JournalSession~new(m)
cp=session~beginInstruction
first=m~tick
call emit 'FIRST ST='||first||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' RV='||d2x(m~cpu~gpr(r1),8)||' MEM='||m~storage~fetchHex(ea,8)||' CC='||m~cpu~psw~conditionCode
if first<>'UNSUPPORTED' then do; call emit 'FAIL first trial was not unsupported'; exit 3; end

source="expose cpu storage; numeric digits 30; use strict arg i,ia,t=0; f=self~rxFields(i); ea=self~eaRX(f[2],f[3],f[4]); v=self~s32(cpu~gprFast(f[1])); sign='C'; if v<0 then do; sign='D'; v=-v; end; packed=v~string~right(15,'0')||sign; storage~storeHex(ea,packed); return ia+4"
installed=m~executor~installLiveMethod('OP4E',source)
call emit 'PATCH installed='||installed
session~abortInstruction
call emit 'REWIND IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' RV='||d2x(m~cpu~gpr(r1),8)||' MEM='||m~storage~fetchHex(ea,8)||' CC='||m~cpu~psw~conditionCode||' METHOD='||m~executor~hasMethod('OP4E')
if m~cpu~psw~rawHex<>prePSW | m~cpu~instructionCount<>preIC | m~cpu~gpr(r1)<>preR | m~storage~fetchHex(ea,8)<>preMem | m~cpu~psw~conditionCode<>preCC then do
  call emit 'FAIL rewind mismatch'; exit 4
end

session~beginInstruction
retry=m~tick
session~commitInstruction
call emit 'RETRY ST='||retry||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' RV='||d2x(m~cpu~gpr(r1),8)||' MEM='||m~storage~fetchHex(ea,8)||' CC='||m~cpu~psw~conditionCode
if retry<>'OK' then do; call emit 'FAIL retry'; exit 5; end

pst='OK'; postTicks=0
do k=1 to 2000
  pia=m~cpu~psw~instructionAddress; pinst=m~storage~fetchHex(pia,6)
  pst=m~tick
  if pst<>'OK' then do
    postTicks=k-1
    call emit 'NEXT STOP IA='||d2x(pia,6)||' IC='||m~cpu~instructionCount||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||pst||' POSTTICKS='||postTicks
    leave
  end
end
if pst='OK' then call emit 'NEXT none within 2000 ticks IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount
call emit 'END'
call lineout log
say 'PASS probe_mvt_cvd_journal_retry log='log
exit 0

emit:
  parse arg line
  say line
  call lineout log,line; call lineout log
return

::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
