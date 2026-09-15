/* Safety19: capture exact X'5D' D / Divide frontier from sealed safety18. */
numeric digits 30
parse arg mediaPath log
if mediaPath='' then mediaPath='/mnt/data/mvt19/os360mvt/dasd/mvtres.350'
if log='' then log='/mnt/data/mvt_safety19_divide_frontier.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new(mediaPath,'MVTRES','SUPPLIED')
dev=.IBM3330Device~new(x2d('350'),media); con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
call emit 'START FAST'
found=0
do n=1 to 900000
  ia=m~cpu~psw~instructionAddress; ic=m~cpu~instructionCount; st=m~tick
  if st<>'OK' then do
    inst=m~storage~fetchHex(ia,6)
    call emit 'STOP n='||n||' IA='||d2x(ia,6)||' PREIC='||ic||' IC='||m~cpu~instructionCount||' INST='||inst||' ST='||st||' PSW='||m~cpu~psw~rawHex
    if ia=x2d('5E') & inst~left(2)='5D' & m~cpu~instructionCount=531376 then found=1
    leave
  end
end
if \found then do; call emit 'FAIL expected 5D frontier not reached'; exit 2; end
inst=m~storage~fetchHex(x2d('5E'),4)
r1=x2d(inst~substr(3,1)); x2=x2d(inst~substr(4,1)); b2=x2d(inst~substr(5,1)); d2=x2d(inst~substr(6,3))
ea=d2; if x2<>0 then ea=ea+m~cpu~gpr(x2); if b2<>0 then ea=ea+m~cpu~gpr(b2); ea=ea//16777216
call emit 'FIELDS R1='||r1||' X2='||x2||' B2='||b2||' D2='||d2x(d2,3)||' EA='||d2x(ea,6)||' MEM='||m~storage~fetchHex(ea,4)
do r=0 to 15
  call emit 'R'||r||'='||d2x(m~cpu~gpr(r),8)
end
call emit 'CC='||m~cpu~psw~conditionCode||' PM='||m~cpu~psw~programMask
call emit 'END'; call lineout log; say 'PASS probe_mvt_divide_frontier log='log; exit 0
emit: use arg line; say line; call lineout log,line; call lineout log; return
::requires 'IBM4361Journal.cls'
::requires 'IBM370DASD.cls'
