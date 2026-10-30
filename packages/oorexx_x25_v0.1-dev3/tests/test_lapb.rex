/* Deterministic user-space LAPB modulo-8 tests; no network, no root. */
signal on syntax name fail
run:
  say 'RUN LAPB codec/fcs/role'
  call verify length(.X25LapbCodec~fcs('123456789'))=2,'FCS is two octets'
  call verify c2x(.X25LapbCodec~fcs('123456789'))='6E90','HDLC FCS standard 123456789 vector'
  f=.X25LapbCodec~emit('DTE','SABM',0,0,'',.true)
  x=.X25LapbCodec~decode(f,'DCE')
  call verify x~kind='SABM' & x~command & x~pf=1,'SABM role/bit decode'
  call verify c2x(left(f,2))='013F','DTE command and SABM poll wire'
  ua=.X25LapbCodec~emit('DCE','UA',0,0,'',.true,.true)
  call verify .X25LapbCodec~decode(ua,'DTE')~kind='UA','DCE UA response'
  call verify .X25LapbCodec~decode(.X25LapbCodec~emit('DTE','RR',0,7), 'DCE')~nr=7,'RR N(R) modulo8'

  say 'RUN LAPB handshake and I-frames'
  a=.X25LapbLink~new('DTE',2,100,3)
  b=.X25LapbLink~new('DCE',2,100,3)
  call verify a~start(0)='AWAIT_UA','outbound start'
  tx=a~drainOutgoing
  call verify tx~items=1,'SABM generated'
  call verify b~receive(tx[1],1)='LINK_ESTABLISHED_BY_PEER','peer accepts SABM'
  rx=b~drainOutgoing
  call verify a~receive(rx[1],2)='LINK_ESTABLISHED','UA completes handshake'
  call verify a~state='CONNECTED' & b~state='CONNECTED','both connected'
  payload1='10010B11'x;payload2='10010B22'x;payload3='10010B33'x
  call verify a~send(payload1,3),'I #1 sent'
  call verify a~send(payload2,4),'I #2 sent'
  call verify \a~send(payload3,5),'window=2 stops third I'
  tx=a~drainOutgoing
  call verify tx~items=2,'two frames'
  call verify b~receive(tx[1],10)='DATA_ACCEPTED','peer accepts first frame'
  call verify b~receive(tx[1],11)='DATA_DUPLICATE','duplicate suppressed'
  delivered=b~drainDelivered
  call verify delivered~items=1 & delivered[1]=payload1,'one delivery only'
  rxs=b~drainOutgoing
  call verify a~receive(rxs[1],12)='ACK_RR','ack clears one window slot'
  call verify a~outstanding=1 & a~va=1,'V(A) advanced'
  call verify a~send(payload3,13),'window reopens'
  tx=a~drainOutgoing
  call verify tx~items=1,'one new I frame'
  call verify b~receive(tx[1],14)='DATA_OUT_OF_SEQUENCE','out-of-order REJ'
  rr=b~drainOutgoing
  n=rr~items
  call verify .X25LapbCodec~decode(rr[n],'DTE')~kind='REJ','REJ issued'
  call verify a~receive(rr[n],15)='ACK_REJ','REJ processes ACK and causes replay'
  again=a~drainOutgoing
  call verify again~items=2,'retransmits only outstanding I frames'
  call verify b~receive(again[1],20)='DATA_ACCEPTED','replayed second frame accepted'
  call verify b~receive(again[2],21)='DATA_ACCEPTED','replayed third frame accepted'
  delivered=b~drainDelivered
  call verify delivered~items=2 & delivered[1]=payload2 & delivered[2]=payload3,'ordered delivery'
  rr=b~drainOutgoing
  call verify a~receive(rr[rr~items],22)='ACK_RR','last ACK'
  call verify a~outstanding=0 & a~va=3 & a~vs=3,'window drained and sequence aligned'

  say 'RUN PLP DATA over LAPB octet-to-bit-to-frame round trip'
  plp=.X25Packet~data(17,'00FF2A'x,0,0,1,0,1)
  framed=.X25LapbCodec~emit('DTE','I',0,0,plp~raw)
  bits=.X25HdlcBits~encode(framed)
  recovered=.X25LapbCodec~decode(.X25HdlcBits~decode(bits),'DCE')
  packet=.X25Packet~new(recovered~payload)
  call verify packet~kind='DATA' & packet~lcn=17 & packet~payload='00FF2A'x,'PLP DATA preserved through LAPB and HDLC'
  call verify packet~qualifier=1 & packet~more=1,'PLP Q and M bits preserved'
  say 'RUN LAPB backpressure and timers'
  rnr=.X25LapbCodec~emit('DCE','RNR',0,3,'',.false,.false)
  call verify a~receive(rnr,24)='ACK_RNR' & a~remoteBusy,'peer busy asserted'
  call verify \a~send(payload1,25),'RNR denies new I'
  rr=.X25LapbCodec~emit('DCE','RR',0,3)
  call verify a~receive(rr,26)='ACK_RR' & \a~remoteBusy,'RR clears busy'
  call verify a~send(payload1,27),'resumed sending'
  ignore=a~drainOutgoing
  call verify a~tick(126)='NONE','no early T1'
  call verify a~tick(127)='RETRANSMITTED','T1 retransmits outstanding'
  call verify a~drainOutgoing~items=1,'one I replay'
  call verify a~tick(227)='RETRANSMITTED','second T1 retransmits'
  ignore=a~drainOutgoing
  call verify a~tick(327)='N2_EXHAUSTED','bounded retransmit attempts'
  call verify a~state='FAILED' & a~drainOutgoing~items=0,'failed link stops output'

  say 'RUN LAPB handshake expiry and disconnect'
  c=.X25LapbLink~new('DTE',2,20,2)
  call verify c~start(1)='AWAIT_UA','SABM setup'
  ignore=c~drainOutgoing
  call verify c~tick(21)='RETRANSMITTED','SABM T1 retry'
  call verify c~drainOutgoing~items=1,'SABM repeated'
  call verify c~tick(41)='N2_EXHAUSTED' & c~state='FAILED','handshake failure bounded'
  c=.X25LapbLink~new('DTE',2,20,2)
  d=.X25LapbLink~new('DCE',2,20,2)
  ignore=c~start(0);tx=c~drainOutgoing;ignore=d~receive(tx[1],1);tx=d~drainOutgoing;ignore=c~receive(tx[1],2)
  call verify c~disconnect(3)='AWAIT_DISC','DISC sent'
  tx=c~drainOutgoing;call verify d~receive(tx[1],4)='LINK_DISCONNECTED_BY_PEER','DISC received'
  tx=d~drainOutgoing;call verify c~receive(tx[1],5)='LINK_DISCONNECTED','UA closes link'
  say 'RUN HDLC bitstuff/unstuff with bounded flags'
  testwire=.X25LapbCodec~emit('DTE','I',7,2,'7EFFFE7E00' x)
  bits=.X25HdlcBits~encode(testwire)
  call verify left(bits,8)='01111110' & right(bits,8)='01111110','HDLC flags'
  call verify .X25HdlcBits~decode(bits)=testwire,'HDLC stuffed 7E/FF octets round-trip'
  call verify .X25LapbCodec~decode(.X25HdlcBits~decode(bits),'DCE')~payload='7EFFFE7E00' x,'bitstream reconstructs I payload'
  say 'RUN LAPB bad-FCS rejection' 
  signal on syntax name caughtBad
  ignore=.X25LapbCodec~decode(left(f,4)||'00'x,'DCE')
  signal off syntax
  say 'FAIL damaged FCS accepted'
  exit 1
verify:
  use strict arg ok,msg
  if \ok then do
    say 'FAIL:' msg
    exit 1
  end
  return
caughtBad:
  say 'PASS X25Lapb codec, FCS, roles, window, REJ, RNR, T1, N2 and disconnect'
  exit 0
fail:
  say 'FAIL unexpected ooRexx syntax' condition('D')
  exit 1
::requires 'X25Lapb.cls'
::requires 'X25Packet.cls'