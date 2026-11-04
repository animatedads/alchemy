/* Real ooRexx deterministic packet and XOT tests. */
call main
say 'PASS ooRexx X25Packet/XOT codec v0.1-dev2 (dev1 regression)'
exit 0

main:
  p=.X25Packet~new('10010B0000'x)
  call check p~kind='CALL', 'CALL recognized'
  call check p~lcn=1,'LCN decoded'
  call check p~modulo=1,'mod8 flag'
  call check p~raw='10010B0000'x, 'wire preserved'
  c=.X25Packet~control(513,'CLEAR',9,4)
  call check c~raw='1201130904'x,'basic clear octets'
  call check c~cause=9 & c~diagnostic=4,'cause/diagnostic'
  call check c~withLCN(15)~raw='100F130904'x,'LCN rewrite only'
  call check .X25Packet~control(3,'RESET_CONFIRM')~raw='10031F'x,'reset confirm'
  data=.X25Packet~new('9001204849'x)
  call check data~kind='DATA', 'data kind'
  call check data~qualifier=1, 'Q bit preserved'
  call check data~delivery=0, 'D bit preserved'
  call check data~sendSequence=0 & data~receiveSequence=1, 'modulo8 counters'
  call check data~payload='HI','payload binary preserved'
  r=.X25Packet~new('100141'x)
  call check r~kind='RR' & r~receiveSequence=2,'RR sequence'
  interrupt=.X25Packet~new('100123DEADBEEF'x)
  call check interrupt~kind='INTERRUPT' & length(interrupt~payload)=4, 'interrupt body'
  fr=.XotFramer~new
  a=fr~frame(c)
  call check c2x(a)='000000051201130904','XOT framing is version zero + len'
  call check fr~push(substr(a,1,2))~items=0,'split header wait'
  call check fr~push(substr(a,3,1))~items=0,'split length wait'
  call check fr~push(substr(a,4,3))~items=0,'split data wait'
  got=fr~push(substr(a,7))
  call check got~items=1,'completed frame'
  call check got[1]=c~raw,'complete frame exact'
  both=fr~push(a||a)
  call check both~items=2 & both[1]=c~raw & both[2]=c~raw,'coalesced frames'
  call check fr~finish,'clean EOF'
  bad=.XotFramer~new
  signal on syntax name expectedSyntax
  ignore=bad~push('00010003'x||'100117'x)
  raise syntax 88.900 array('expected bad version exception')
expectedSyntax:
  signal off syntax
  call check bad~failed,'bad version permanently poisons framer'
  call check \(.XotFramer~new~finish=.false), 'empty stream cleanly ends'
  return
check:
  use strict arg ok,label
  if \ok then do
    say 'FAIL' label
    exit 1
  end
  return
::requires 'X25Packet.cls'