/* Safety20 whole-trajectory permanent-source MVT replay. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/s370_resume/media/MVTRES.350'
if log='' then log='/mnt/data/s370_resume/mvt_safety20_permanent_frontier.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START PERMANENT OPD1='||m~executor~hasMethod('OPD1')||' OP65='||m~executor~hasMethod('OP65')
if \m~executor~hasMethod('OPD1') | m~executor~hasMethod('OP65') then do; call emit 'FAIL source method audit'; exit 2; end
seenD1=0
stop=''
do n=1 to 900000
  ia=m~cpu~psw~instructionAddress; ic=m~cpu~instructionCount
  if ia=x2d('47C') & ic=531395 then do
    inst=m~storage~fetchHex(ia,6)
    if inst~left(2)<>'D1' then do; call emit 'FAIL expected D1 at recorded frontier'; exit 3; end
    call emit 'D1 PRE IA='||d2x(ia,6)||' IC='||ic||' INST='||inst||' DST='||m~storage~fetchHex(x2d('4E7'),1)||' SRC='||m~storage~fetchHex(x2d('5D1'),1)||' CC='||m~cpu~psw~conditionCode
    seenD1=1
  end
  st=m~tick
  if seenD1=1 & ic=531395 then call emit 'D1 POST ST='||st||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' DST='||m~storage~fetchHex(x2d('4E7'),1)||' SRC='||m~storage~fetchHex(x2d('5D1'),1)||' CC='||m~cpu~psw~conditionCode
  if st<>'OK' then do
    inst=m~storage~fetchHex(ia,6); stop=inst~left(2)
    call emit 'STOP n='||n||' IA='||d2x(ia,6)||' PREIC='||ic||' IC='||m~cpu~instructionCount||' INST='||inst||' OP='||stop||' PSW='||m~cpu~psw~rawHex||' ST='||st
    leave
  end
end
if \seenD1 then do; call emit 'FAIL D1 frontier not observed'; exit 4; end
if stop<>'65' | m~cpu~psw~instructionAddress<>x2d('66') | m~cpu~instructionCount<>532961 then do; call emit 'FAIL unexpected permanent frontier'; exit 5; end
call emit 'END'; call lineout log; say 'PASS probe_mvt_safety20_permanent_frontier log='log; exit 0
emit: use arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
