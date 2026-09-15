/* Safety22: permanent-source whole-MVT replay through X'02', stop at next boundary. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/s370_media/MVTRES.350'
if log='' then log='evidence/mvt_safety22_02_permanent_frontier.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START PERMANENT OP02='||m~executor~hasMethod('OP02')
if m~executor~hasMethod('OP02') then do; call emit 'FAIL OP02 present'; exit 2; end
seen02=0; st='OK'
do n=1 to 900000
  ia=m~cpu~psw~instructionAddress; ic=m~cpu~instructionCount
  if ia=x2d('6E') & m~storage~fetchHex(ia,1)='02' & ic=534665 then do
    call emit 'BEFORE02 IA='||d2x(ia,6)||' IC='||ic||' PSW='||m~cpu~psw~rawHex||' INST='||m~storage~fetchHex(ia,6)
    seen02=1
  end
  st=m~tick
  if seen02=1 & ic=534665 then call emit 'AFTER02 ST='||st||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' IC='||m~cpu~instructionCount||' PSW='||m~cpu~psw~rawHex||' PGMOLD='||m~storage~fetchHex(x2d('28'),8)||' PGMNEW='||m~storage~fetchHex(x2d('68'),8)
  if st<>'OK' then do
    inst=m~storage~fetchHex(ia,6); call emit 'STOP n='||n||' IA='||d2x(ia,6)||' PREIC='||ic||' IC='||m~cpu~instructionCount||' INST='||inst||' ST='||st||' PSW='||m~cpu~psw~rawHex
    leave
  end
end
if seen02=0 then do; call emit 'FAIL 02 not observed'; exit 3; end
if st='OK' then do; call emit 'FAIL no next boundary'; exit 4; end
if ia<>x2d('82') | m~storage~fetchHex(ia,1)<>'70' | m~cpu~instructionCount<>539172 then do; call emit 'FAIL expected 70 frontier'; exit 5; end
call emit 'END'; call lineout log; say 'PASS probe_mvt_safety22_02_permanent_frontier log='log; exit 0
emit: use arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
