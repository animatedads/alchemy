numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
do n=1 to 50000
  if m~cpu~psw~instructionAddress=x2d('FFE04C') then do
    say 'FOUND n='n 'IC='m~cpu~instructionCount 'CC='m~cpu~psw~conditionCode
    do r=0 to 15; say 'R'r'='d2x(m~cpu~gpr(r),8) '('m~cpu~gpr(r)')'; end
    say 'CODEPRE='m~storage~fetchHex(x2d('FFDFC0'),160)
    exit 0
  end
  st=m~tick
  if st<>"OK" then do; say 'STOP' st n 'IA='d2x(m~cpu~psw~instructionAddress,6); exit 2; end
end
say 'NOTFOUND IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6)
exit 1
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
