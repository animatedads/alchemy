/* SAFETY8 ARCHAEOLOGY: exact real-MVT BAL alias rewind/live-retry. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media/mvtres_uncompressed.350'
if log='' then log='/mnt/data/mvt_safety8_bal_journal_retry.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','PROBE-LOGICAL-EQUIVALENT')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
storage=.IBM370JournaledStorage~new(16777216,2048,'MVT-S8-BAL-RAM')
m=.IBM4361Machine~new(16777216,storage)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START'
found=0
do n=1 to 300000
  ia=m~cpu~psw~instructionAddress
  if ia=x2d('018984') & m~cpu~instructionCount=511781 then do; found=1; leave; end
  st=m~tick
  if st<>'OK' then do
    call emit 'EARLY STOP n='||n||' IA='||d2x(ia,6)||' IC='||m~cpu~instructionCount||' ST='||st||' INST='||m~storage~fetchHex(ia,6)
    leave
  end
end
if \found then do; call emit 'FAIL frontier not reached'; call lineout log; exit 2; end
inst=m~storage~fetchHex(ia,6)
prePSW=m~cpu~psw~rawHex; preIC=m~cpu~instructionCount; preR10=m~cpu~gpr(10); preMem=m~storage~fetchHex(x2d('018A60'),48)
call emit 'FRONTIER n='||n||' IA='||d2x(ia,6)||' IC='||preIC||' INST='||inst||' PSW='||prePSW||' R10='||d2x(preR10,8)
call emit 'TARGET_18A60='||preMem

session=.IBM4361JournalSession~new(m)
session~beginInstruction
first=m~tick
call emit 'OLD BAL ST='||first||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' R10='||d2x(m~cpu~gpr(10),8)
if first<>'OK' | m~cpu~psw~instructionAddress<>x2d('018A72') then do; call emit 'FAIL old BAL did not reproduce +8 target'; exit 3; end
session~abortInstruction
call emit 'REWIND1 IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' R10='||d2x(m~cpu~gpr(10),8)
if m~cpu~psw~rawHex<>prePSW | m~cpu~instructionCount<>preIC | m~cpu~gpr(10)<>preR10 then do; call emit 'FAIL rewind1 mismatch'; exit 4; end

/* Form EA from pre-instruction GPRs, then write the link register. */
source="expose cpu; numeric digits 30; use strict arg i,ia,t=0; r=x2d(i~substr(3,1)); x=x2d(i~substr(4,1)); b=x2d(i~substr(5,1)); d=x2d(i~substr(6,3)); target=d; if x<>0 then target=target+cpu~gprFast(x); if b<>0 then target=target+cpu~gprFast(b); target=target//16777216; high=128+cpu~psw~conditionCode*16+cpu~psw~programMask; cpu~setGprFast(r,high*16777216+((ia+4)//16777216)); return target"
session~beginInstruction
installed=m~executor~installLiveMethod('OP45',source)
/* Dirty several journalled architectural participants to prove insertion lives
 * outside the rewind domain while machine state does not. */
m~cpu~setGpr(0,x2d('DEADBEEF'))
m~storage~storeHex(x2d('001000'),'A1B2C3D4')
session~abortInstruction
call emit 'PATCH installed='||installed||' REWIND2 IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' R0='||d2x(m~cpu~gpr(0),8)||' MEM1000='||m~storage~fetchHex(x2d('001000'),4)||' METHOD='||m~executor~hasMethod('OP45')
if m~cpu~psw~rawHex<>prePSW | m~cpu~instructionCount<>preIC | m~cpu~gpr(10)<>preR10 then do; call emit 'FAIL rewind2 mismatch'; exit 5; end

session~beginInstruction
retry=m~tick
session~commitInstruction
call emit 'RETRY ST='||retry||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' R10='||d2x(m~cpu~gpr(10),8)
if retry<>'OK' | m~cpu~psw~instructionAddress<>x2d('018A6A') | m~cpu~gpr(10)<>x2d('B0018988') then do; call emit 'FAIL corrected BAL retry'; exit 6; end

pst='OK'
do k=1 to 10000
  pia=m~cpu~psw~instructionAddress; pinst=m~storage~fetchHex(pia,6)
  pst=m~tick
  if pst<>'OK' then do
    call emit 'NEXT STOP k='||k||' IA='||d2x(pia,6)||' IC='||m~cpu~instructionCount||' INST='||pinst||' OP='||pinst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||pst
    leave
  end
end
if pst='OK' then call emit 'NEXT none within 10000 ticks IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount
call emit '3215='||con~outputRecords~items
call emit 'END'
call lineout log
say 'PASS probe_mvt_bal_journal_retry log='log
exit 0

emit:
  parse arg line
  say line
  call lineout log,line; call lineout log
return

::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
