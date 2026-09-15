/* Safety16 observation-only trace: explain why safety15 reaches FF @ X'20'. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media16/mvtres.350'
if log='' then log='/mnt/data/mvt_safety16_ff_trace.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
ring=.array~new(128); rp=0; seen=0
call emit 'START'
do n=1 to 700000
  ia=m~cpu~psw~instructionAddress; ic=m~cpu~instructionCount; psw=m~cpu~psw~rawHex
  inst=m~storage~fetchHex(ia,6)
  r6=m~cpu~gpr(6); r14=m~cpu~gpr(14); r15=m~cpu~gpr(15)
  rp=rp//128+1; seen=seen+1
  ring[rp]='PRE IC='||ic||' IA='||d2x(ia,6)||' INST='||inst||' PSW='||psw||' R6='||d2x(r6,8)||' R14='||d2x(r14,8)||' R15='||d2x(r15,8)
  st=m~tick
  if st<>'OK' then do
    call emit 'STOP n='||n||' PREIC='||ic||' IC='||m~cpu~instructionCount||' IA='||d2x(ia,6)||' INST='||inst||' ST='||st||' POSTPSW='||m~cpu~psw~rawHex
    leave
  end
end
count=seen; if count>128 then count=128
start=rp-count+1; if start<=0 then start=start+128
do j=0 to count-1
  ix=(start+j-1)//128+1
  call emit ring[ix]
end
call emit 'LOWCORE SVCOLD20='||m~storage~fetchHex(x2d('20'),8)||' PGMOLD28='||m~storage~fetchHex(x2d('28'),8)||' SVCNEW60='||m~storage~fetchHex(x2d('60'),8)||' PGMNEW68='||m~storage~fetchHex(x2d('68'),8)
call emit 'END'; call lineout log
say 'PASS probe_mvt_safety16_ff_trace log='log
exit 0
emit: parse arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
