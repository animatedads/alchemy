/* X.25 dev2 corrective regression, ooRexx 5.3.0 r13196. No network. */
call main
say 'PASS test_dev2 F1 F2 F3 F4 F5 F6 and typed diagnostic/roundtrip'
exit 0

main:
  /* F1: CALL A=1 signals unsupported TOA/NPI, not Q+BCD. */
  call check rejected("ignore=.X25Packet~new('90010B0000'x)"),'F1 A-bit CALL refused'
  call check .X25Packet~new('10010B0000'x)~qualifier=0,'F1 basic CALL not Q flagged'

  /* F2: Interface-global packets can only occur on LCN 0. */
  call check .X25Packet~new('1000FB00'x)~lcn=0,'F2 RESTART on global LCN'
  call check .X25Packet~new('1000FF'x)~kind='RESTART_CONFIRM','F2 global restart confirm'
  call check .X25Packet~new('1000F1'x)~kind='DIAGNOSTIC','F2 global diagnostic'
  call check .X25Packet~new('1000F3'x)~kind='REGISTRATION','F2 global registration'
  call check .X25Packet~new('1000F7'x)~kind='REGISTRATION_CONFIRM','F2 global registration confirm'
  call check rejected("ignore=.X25Packet~new('1001FB00'x)"),'F2 reject local channel restart'
  call check rejected("ignore=.X25Packet~new('1001FF'x)"),'F2 reject local channel restart confirm'
  call check rejected("ignore=.X25Packet~new('1001F1'x)"),'F2 reject local channel diagnostic'
  call check rejected("ignore=.X25Packet~new('1001F3'x)"),'F2 reject local channel registration'
  call check rejected("ignore=.X25Packet~new('1001F7'x)"),'F2 reject local channel registration confirm'

  /* F3: No per-circuit packet or control construction on global channel. */
  call check rejected("ignore=.X25Packet~new('10000041'x)"),'F3 DATA global LCN'
  call check rejected("ignore=.X25Packet~new('10000B0000'x)"),'F3 CALL global LCN'
  call check rejected("ignore=.X25Packet~new('1000130000'x)"),'F3 CLEAR global LCN'
  call check rejected("ignore=.X25Packet~new('10001B0000'x)"),'F3 RESET global LCN'
  call check rejected("ignore=.X25Packet~control(0,'CLEAR')"),'F3 construct control global LCN'
  call check rejected("ignore=.X25Packet~new('100100'x)~withLCN(0)"),'F3 rewrite circuit to global forbidden'

  /* F4: Interrupt length is 1..32 binary octets. */
  call check rejected("ignore=.X25Packet~new('100123'x)"),'F4 reject empty interrupt'
  call check length(.X25Packet~new('100123'x||copies('AA'x,32))~payload)=32,'F4 accept 32-byte interrupt'
  call check rejected("ignore=.X25Packet~new('100123'x||copies('AA'x,33))"),'F4 reject 33-byte interrupt'

  /* Q/D/M, high and low LCN octets, opaque binary: encode->decode. */
  p=.X25Packet~data(513,'00FF10'x,7,6,1,1,1)
  call check p~lcn=513 & p~sendSequence=7 & p~receiveSequence=6,'DATA encode sequence and LCN'
  call check p~qualifier=1 & p~delivery=1 & p~more=1,'DATA preserve Q/D/M'
  call check p~payload='00FF10'x,'DATA binary payload roundtrip'
  call check .X25Packet~new(p~raw)~raw=p~raw,'DATA byte-exact decode roundtrip'
  call check rejected("ignore=.X25Packet~data(1,'AA'x,8)"),'DATA rejects unrepresentable modulo8 PS'
  call check rejected("ignore=.X25Packet~data(1,copies('AA'x,129))"),'DATA rejects oversized body'

  /* F5: local RESET_CONFIRM must reinit both directions. */
  vc=.X25VirtualCircuit~new('if0',1,'epoch-1')
  call check vc~beginCall(.X25Packet~new('10010B0000'x),100,20)='CALL_SENT','vc setup'
  call check vc~receive(.X25Packet~new('10010F'x),'epoch-1')='ACTIVE','vc active'
  call check vc~noteDataSent(.X25Packet~data(1,'A',0))=1,'prepare outgoing P(S) 0'
  call check vc~noteDataSent(.X25Packet~data(1,'B',1))=2,'prepare outgoing P(S) 1'
  call check vc~receive(.X25Packet~data(1,'C',0),'epoch-1')='ACTIVE','consume incoming P(S) 0'
  call check vc~receive(.X25Packet~data(1,'D',1),'epoch-1')='ACTIVE','consume incoming P(S) 1'
  call check vc~receiveNext=2 & vc~sendNext=2,'pre-reset both counters 2'
  call check vc~beginReset='RESET_SENT','own reset began'
  call check vc~receive(.X25Packet~control(1,'RESET_CONFIRM'),'epoch-1')='ACTIVE','own reset confirmed'
  call check vc~receiveNext=0 & vc~sendNext=0,'F5 both counters reset'
  call check vc~receive(.X25Packet~data(1,'E',0),'epoch-1')='ACTIVE','F5 new peer P(S)=0 accepted'
  call check vc~noteDataSent(.X25Packet~data(1,'F',0))=1,'F5 new local P(S)=0 accepted'

  /* Correct, separately typed wire RESET proposal for invalid P(S). */
  r=vc~inspectIncoming(.X25Packet~data(1,'bad',5),'epoch-1')
  call check r<>.nil & r~reason='INVALID_PS','invalid P(S) classified'
  call check r~hasWireResponse & r~action='RESET','invalid P(S) requests reset'
  call check r~cause=0 & r~diagnostic=1,'DTE reset cause zero, diag 1'
  call check r~responsePacket~raw='10011B0001'x,'DTE diagnostic wire packet exact'
  call check rejected("ignore=vc~receive(.X25Packet~data(1,'bad',5),'epoch-1')"),'invalid P(S) still raises safely'
  call check vc~state='ACTIVE' & vc~receiveNext=1,'invalid P(S) leaves state and counter'
  vcDce=.X25VirtualCircuit~new('if1',1,'dce',128,'DCE')
  call check vcDce~receive(.X25Packet~new('10010B0000'x),'dce')='CALL_INCOMING','DCE incoming CALL'
  call check vcDce~acceptIncoming(.true)='ACTIVE','DCE accepted'
  r=vcDce~inspectIncoming(.X25Packet~data(1,'bad',5),'dce')
  call check r~cause=5 & r~diagnostic=1,'DCE cause 5 diagnostic 1'
  call check r~responsePacket~raw='10011B0501'x,'DCE error wire packet'
  call check rejected("ignore=.X25VirtualCircuit~new('if1',1,'bad',128,'UNKNOWN')"),'invalid role blocked'
  local=vc~inspectIncoming(.X25Packet~data(1,'bad',0),'old-incarnation')
  call check local~action='LOCAL_ONLY' & \local~hasWireResponse,'stale epoch has no fabricated on-wire response'
  call check rejected("ignore=local~responsePacket"),'local rejection cannot emit RESET'

  /* Parse-time failures have a safe typed response only when validly
   * mapped to the ACTIVE VC and its DTE/DCE role. */
  malformed=vc~inspectRaw('100100'x||copies('AA'x,129),'epoch-1')
  call check malformed~hasWireResponse & malformed~diagnostic=39, 'DATA oversize maps RESET diag39'
  call check malformed~responsePacket~raw='10011B0027'x, 'oversize DTE exact RESET bytes'
  malformed=vcDce~inspectRaw('100123'x,'dce')
  call check malformed~diagnostic=38 & malformed~cause=5, 'short interrupt DCE maps RESET diag38'
  call check malformed~responsePacket~raw='10011B0526'x, 'short interrupt DCE exact bytes'
  malformed=vc~inspectRaw('90010B0000'x,'epoch-1')
  call check malformed~action='LOCAL_ONLY' & \malformed~hasWireResponse, 'A-bit CALL has no fabricated reset mapping'
  malformed=vc~inspectRaw('100100'x,'expired-incarnation')
  call check malformed~action='LOCAL_ONLY', 'stale bytes refused without response'

  /* F6: simultaneous CLEAR completes, and no confirmation is pending. */
  call check vc~beginClear='CLEAR_SENT','begin local clear'
  call check vc~receive(.X25Packet~control(1,'CLEAR',0,0),'epoch-1')='CLEARED','F6 clear collision completes immediately'
  call check rejected("ignore=vc~confirmIncomingClear"),'F6 no spurious clear confirm'
  return

rejected:
  use strict arg source
  signal on syntax name caught
  interpret source
  signal off syntax
  return .false
caught:
  signal off syntax
  return .true
check:
  use strict arg good,label
  if \good then do
    say 'FAIL:' label
    exit 1
  end
  return
::requires 'X25Packet.cls'
::requires 'X25VirtualCircuit.cls'