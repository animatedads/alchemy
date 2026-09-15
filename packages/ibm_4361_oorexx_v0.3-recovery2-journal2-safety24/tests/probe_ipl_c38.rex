numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
low=x2d('C38'); high=x2d('FFE608'); lo=m~storage~fetchHex(low,4); hi=m~storage~fetchHex(high,4)
say 'START C38='lo 'HIGH='hi
seen=.false
do n=1 to 20000
 ia=m~cpu~psw~instructionAddress
 if ia>=x2d('320') & ia<=x2d('340') then say 'PRE n='n 'IC='m~cpu~instructionCount 'IA='d2x(ia,6) 'INST='m~storage~fetchHex(ia,6) 'R12='d2x(m~cpu~gpr(12),8) 'C38='m~storage~fetchHex(low,4)
 st=m~tick
 nlo=m~storage~fetchHex(low,4); nhi=m~storage~fetchHex(high,4)
 if nlo<>lo then do; say 'LOW CHANGE after IA='d2x(ia,6) 'IC='m~cpu~instructionCount lo'->'nlo 'R12='d2x(m~cpu~gpr(12),8); lo=nlo; end
 if nhi<>hi then do; say 'HIGH CHANGE after IA='d2x(ia,6) 'IC='m~cpu~instructionCount hi'->'nhi; hi=nhi; end
 if ia=x2d('332') then seen=.true
 if st<>"OK" then do; say 'STOP' st; exit 2; end
 if m~cpu~psw~instructionAddress>=x2d('FF0000') then do; say 'ENTER HIGH IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'LOW='lo 'HIGH='hi 'seen332='seen; exit 0; end
end
say 'NOTFOUND'
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
