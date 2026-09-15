numeric digits 30
media=.IBM370CCKDMedia~new('/mnt/data/mvt_media/mvtres.350','MVTRES','DEV')
dev=.IBM3330Device~new(x2d('350'),media)
m=.IBM4361Machine~new(16777216); m~powerOn; m~attachDevice(dev); m~initialProgramLoad(x2d('350'))
prev=m~storage~fetchHex(x2d('FFE608'),4)
say 'START VAL='prev 'IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6)
do n=1 to 40000
  ia=m~cpu~psw~instructionAddress
  .environment['IBM_WATCH_IA']=d2x(ia,6)
  .environment['IBM_WATCH_IC']=m~cpu~instructionCount
  if ia>=0 & ia<m~storage~sizeBytes then do
    op=m~storage~fetchHex(ia,1)
    il=2; v=x2d(op); if v>=64 then il=4; if v>=192 then il=6
    .environment['IBM_WATCH_INST']=m~storage~fetchHex(ia,il)
  end
  st=m~tick
  cur=m~storage~fetchHex(x2d('FFE608'),4)
  if cur<>prev then do
    say 'WATCH VALUE CHANGE n='n 'from='prev 'to='cur 'postIA='d2x(m~cpu~psw~instructionAddress,6) 'IC='m~cpu~instructionCount
    prev=cur
  end
  if st<>"OK" then do; say 'STOP' st n 'IA='d2x(m~cpu~psw~instructionAddress,6) 'IC='m~cpu~instructionCount; leave; end
  if m~cpu~psw~instructionAddress=x2d('FFE04C') then do
    say 'FOUND BEFORE DR n='n 'IC='m~cpu~instructionCount 'VAL='cur
    leave
  end
end
say 'END IC='m~cpu~instructionCount 'IA='d2x(m~cpu~psw~instructionAddress,6) 'VAL='m~storage~fetchHex(x2d('FFE608'),4) 'CCHHR='dev~cylinder'/'dev~head'/'dev~record
exit 0
::requires 'IBM4361.cls'
::requires 'IBM370DASD.cls'
