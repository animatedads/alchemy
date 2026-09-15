/* Safety24: permanent-source whole-MVT replay through EX-target specification interruption. */
numeric digits 30
parse arg mediaPath log maxAfter
if mediaPath='' then mediaPath='/mnt/data/s370_cont/media/MVTRES.350'
if log='' then log='evidence/mvt_safety24_permanent_frontier.log'
if maxAfter='' then maxAfter=500000
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START PERMANENT OP70='||m~executor~hasMethod('OP70')
if m~executor~hasMethod('OP70') then do; call emit 'FAIL OP70 present'; exit 2; end
seen=0; after=0; st='OK'
do n=1 to 1600000
  ia=m~cpu~psw~instructionAddress; ic=m~cpu~instructionCount
  if ia=x2d('4B6') & ic=539205 & m~storage~fetchHex(ia,4)='440004F4' then do
    call emit 'BEFORE_EX n='||n||' IA='||d2x(ia,6)||' IC='||ic||' PSW='||m~cpu~psw~rawHex||' INST='||m~storage~fetchHex(ia,6)||' TARGET='||m~storage~fetchHex(x2d('4F4'),6)
    seen=1
  end
  st=m~tick
  if seen=1 & ic=539205 then do
    call emit 'AFTER_EX ST='||st||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' PSW='||m~cpu~psw~rawHex||' PGMOLD='||m~storage~fetchHex(x2d('28'),8)||' PGMNEW='||m~storage~fetchHex(x2d('68'),8)||' LAST='||m~executor~lastInstruction
    if st<>'OK' | m~storage~fetchHex(x2d('28'),8)<>'00040006800004BA' | m~cpu~psw~rawHex<>'00040000000002CA' then do; call emit 'FAIL permanent EX target transition'; exit 3; end
  end
  if seen=1 then after=after+1
  if st<>'OK' then do
    call emit 'STOP n='||n||' after='||after||' IA='||d2x(ia,6)||' PREIC='||ic||' IC='||m~cpu~instructionCount||' INST='||m~storage~fetchHex(ia,6)||' ST='||st||' PSW='||m~cpu~psw~rawHex||' LAST='||m~executor~lastInstruction
    leave
  end
  if seen=1 & after>=maxAfter then do
    call emit 'NO STOP after='||after||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' PSW='||m~cpu~psw~rawHex
    leave
  end
end
if seen=0 then do; call emit 'FAIL EX frontier not observed'; exit 4; end
call emit 'END'; call lineout log; say 'PASS probe_mvt_safety24_permanent_frontier log='log; exit 0
emit: use arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
