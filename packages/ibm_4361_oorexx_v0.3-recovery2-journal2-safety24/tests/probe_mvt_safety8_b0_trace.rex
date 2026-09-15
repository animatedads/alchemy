numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt_media/mvtres_uncompressed.350'
if log='' then log='/mnt/data/mvt_safety8_b0_trace.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','PROBE-LOGICAL-EQUIVALENT')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START'
do n=1 to 300000
  ia=m~cpu~psw~instructionAddress
  inst=m~storage~fetchHex(ia,6)
  ic=m~cpu~instructionCount
  if ic>=511768 then call traceState 'PRE',m,ia,inst,log
  st=m~tick
  if ic>=511768 then do
    call emit 'POST ST='||st||' IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' PSW='||m~cpu~psw~rawHex
  end
  if st<>'OK' then do
    call emit 'STOP n='||n||' IC='||m~cpu~instructionCount||' PREIA='||d2x(ia,6)||' INST='||inst||' OP='||inst~left(2)||' PSW='||m~cpu~psw~rawHex||' ST='||st
    call emit 'LOWCORE_20_6F='||m~storage~fetchHex(x2d('20'),80)
    call emit 'PROGRAM_OLD_28='||m~storage~fetchHex(x2d('28'),8)
    call emit 'PROGRAM_NEW_68='||m~storage~fetchHex(x2d('68'),8)
    leave
  end
end
call lineout log
exit 0

traceState:
  use arg tag,mm,a,ins,l
  s=tag||' IC='||mm~cpu~instructionCount||' IA='||d2x(a,6)||' INST='||ins||' PSW='||mm~cpu~psw~rawHex
  do r=0 to 15
    s=s||' R'||r||'='||d2x(mm~cpu~gpr(r),8)
  end
  call emit s
return

emit:
  parse arg line
  say line
  call lineout log,line; call lineout log
return

::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
