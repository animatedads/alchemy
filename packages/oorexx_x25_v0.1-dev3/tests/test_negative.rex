/* Negative tests: strictly fail-closed, with state unchanged on refusal. */
call main
say 'PASS ooRexx X.25 negative boundary cases'
exit 0
main:
  call check rejected("ignore=.X25Packet~new('')"), 'empty packet rejected'
  call check rejected("ignore=.X25Packet~new('200100'x)"), 'modulo128 profile unavailable'
  call check rejected("ignore=.X25Packet~new('10010B'x)"), 'truncated call'
  call check rejected("ignore=.X25Packet~new('10010B001100'x)"), 'truncated call facilities'
  call check rejected("ignore=.X25Packet~new('100100'x,1)" )=.false, 'empty DATA allowed with packet size 1'
  call check rejected("ignore=.X25Packet~new('1001004142'x,1)"), 'oversize data rejected'
  call check rejected("ignore=.X25Packet~new('100123'x||copies('41'x,33))"), 'oversize interrupt rejected'
  call check rejected("ignore=.X25Packet~control(4096,'CLEAR')"), 'LCN upper bound'
  call check rejected("ignore=.X25Packet~new('100117FF'x)"), 'control octet length bound'
  f=.XotFramer~new
  call check rejected("ignore=f~push('00010003'x||'100117'x)"), 'bad version poison'
  call check f~failed,'bad version permanent FAILED'
  call check rejected("ignore=f~push('00000003'x||'100117'x)"), 'failed framer cannot recover without new socket'
  f2=.XotFramer~new(100)
  call check rejected("ignore=f2~push('00000065'x)"), 'oversize announced length refused before body'
  f3=.XotFramer~new
  call check f3~push('00000005'x||'1201'x)~items=0,'partial body held'
  call check \f3~finish & f3~failed,'truncated EOF reported'
  p=.X25Packet~new('1001004142'x)
  f4=.XotFramer~new
  call check rejected("ignore=f4~frame(.X25Packet~new('1000FB0000'x))"),'RESTART not sent over XOT'
  vc=.X25VirtualCircuit~new('if0',1,'new')
  start=.X25Packet~new('10010B0000'x)
  call check rejected("ignore=vc~receive(start,'old')"), 'stale incarnation refused'
  call check vc~state='IDLE','stale refusal leaves VC state intact'
  call check vc~receive(start,'new')='CALL_INCOMING','real incarnation admitted as pending'
  call check rejected("ignore=vc~acceptIncoming(.false)"), 'not-authorised incoming CALL refused'
  call check vc~state='CALL_INCOMING','unauthorised transition did not mutate VC'
  call check vc~acceptIncoming(.true)='ACTIVE','explicit authorisation'
  call check rejected("ignore=vc~receive(.X25Packet~new('10010241'x),'new')"), 'out-of-sequence DATA rejected'
  call check vc~receiveNext=0,'bad DATA has not advanced sequence'
  call check rejected("ignore=vc~receive(.X25Packet~control(2,'CLEAR'),'new')"), 'wrong LCN rejected'
  call check vc~state='ACTIVE','wrong LCN preserves ACTIVE'
  return
rejected:
  use strict arg source
  signal on syntax name syntacticFailure
  interpret source
  signal off syntax
  return .false
syntacticFailure:
  signal off syntax
  return .true
check:
  use strict arg ok,label
  if \ok then do; say 'FAIL:' label; exit 1; end
  return
::requires 'X25Packet.cls'
::requires 'X25VirtualCircuit.cls'