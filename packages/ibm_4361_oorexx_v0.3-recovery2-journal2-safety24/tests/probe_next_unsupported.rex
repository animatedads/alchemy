numeric digits 30
log='/mnt/data/mvt_next_unsupported.log'
call lineout log; call sysfiledelete log
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
con=.IBM3215Device~new(x2d('001F'))
m=.IBM4361Machine~new(16777216)
m~powerOn; m~attachDevice(dev); m~attachDevice(con); m~initialProgramLoad(x2d('350'))
ring=.array~new(64); rp=0
call emit 'START'
do n=1 to 245000
  ia=m~cpu~psw~instructionAddress; inst=m~storage~fetchHex(ia,6)
  rp=rp+1; if rp>64 then rp=1
  ring[rp]=right(n,7)||' IC='||m~cpu~instructionCount||' IA='||d2x(ia,6)||' INST='||inst||' CC='||m~cpu~psw~conditionCode
  st=m~tick
  if n//50000=0 then call emit 'PROGRESS n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' OUT='||con~outputRecordCount
  if st<>'OK' then do
    call emit 'STOP n='||n||' IC='||m~cpu~instructionCount||' IA='||d2x(m~cpu~psw~instructionAddress,6)||' INST='||m~storage~fetchHex(m~cpu~psw~instructionAddress,6)||' PSW='||m~cpu~psw~rawHex||' ST='||st
    call emit 'REGS '||m~cpu~registersHex
    call emit 'RING_BEGIN'
    start=rp+1; if start>64 then start=1
    do j=0 to 63
      k=start+j; if k>64 then k=k-64
      if ring[k]<>.nil then call emit ring[k]
    end
    call emit 'RING_END'
    leave
  end
end
call emit 'END n='||n||' IC='||m~cpu~instructionCount||' OUT='||con~outputRecordCount
call lineout log
exit 0
emit:
 parse arg line
 call lineout log,line; call lineout log
return
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
