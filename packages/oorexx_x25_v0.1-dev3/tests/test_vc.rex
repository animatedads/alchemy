/* Deterministic VC transition qualification, no real X.25 peer. */
call main
say 'PASS ooRexx X25VirtualCircuit v0.1-dev2 (dev1 regression)'
exit 0
main:
  vc=.X25VirtualCircuit~new('if0',1,'incarnation-7')
  call check vc~identity='if0:1:incarnation-7','typed interface/LCN/incarnation'
  call check vc~state='IDLE','initial state'
  callPkt=.X25Packet~new('10010B0000'x)
  call check vc~beginCall(callPkt,100,50)='CALL_SENT','outbound call'
  call check vc~deadline=150 & vc~timerName='T21','explicit T21 profile timer'
  call check \vc~tick(149),'call not yet timed out'
  ca=.X25Packet~new('10010F'x)
  call check vc~receive(ca,'incarnation-7')='ACTIVE','CALL ACCEPTED'
  call check \vc~tick(300),'T21 cancelled on accepted call'
  d0=.X25Packet~new('1001004849'x)
  call check vc~receive(d0,'incarnation-7')='ACTIVE','receive valid DATA'
  call check vc~receiveNext=1,'data receive sequence advanced'
  call check vc~receive(.X25Packet~new('100105'x),'incarnation-7')='ACTIVE','RNR'
  call check \vc~remoteReady,'RNR flow control flag'
  call check vc~receive(.X25Packet~new('100101'x),'incarnation-7')='ACTIVE','RR'
  call check vc~remoteReady,'RR flow control flag'
  call check vc~receive(.X25Packet~control(1,'RESET',4,5),'incarnation-7')='RESET_RECEIVED','reset reception'
  call check vc~lastCause=4 & vc~lastDiagnostic=5,'retain raw reason'
  call check vc~confirmIncomingReset='ACTIVE','reset confirmation local step'
  call check vc~receiveNext=0,'reset receive sequence reinitialised'
  call check vc~beginClear(9,7)='CLEAR_SENT','clear outbound'
  call check vc~receive(.X25Packet~control(1,'CLEAR_CONFIRM'),'incarnation-7')='CLEARED','clear confirmed'
  call check vc~state='CLEARED','terminal circuit state'
  vc2=.X25VirtualCircuit~new('if0',2,'incarnation-8')
  call check vc2~beginCall(.X25Packet~new('10020B0000'x),100,25)='CALL_SENT','second call'
  call check vc2~tick(125),'T21 expires at deadline'
  call check vc2~state='TIMED_OUT' & \vc2~tick(200),'one expiry only'
  vc3=.X25VirtualCircuit~new('if1',3,'incarnation-9')
  call check vc3~receive(.X25Packet~new('10030B0000'x),'incarnation-9')='CALL_INCOMING','incoming call pending'
  call check vc3~acceptIncoming(.true)='ACTIVE','authorised inbound CALL'
  call check vc3~receive(.X25Packet~control(3,'CLEAR',9,6),'incarnation-9')='CLEAR_RECEIVED','incoming CLEAR pending response'
  call check vc3~confirmIncomingClear='CLEARED','local clear confirmation'
  return
check:
  use strict arg ok,label
  if \ok then do; say 'FAIL:' label; exit 1; end
  return
::requires 'X25Packet.cls'
::requires 'X25VirtualCircuit.cls'