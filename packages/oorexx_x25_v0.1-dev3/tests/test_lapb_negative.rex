/* Adversarial LAPB lab checks, ooRexx r13196. */
signal on syntax name failure
say 'RUN LAPB negative encoding and stuffing'
t=.LapbReject~new
f=.X25LapbCodec~emit('DTE','SABM',0,0,'',.true)
call check t~reject('bad-fcs',left(f,4)||'00'x),'corrupt FCS'
call check t~reject('no-flag',left(.X25HdlcBits~encode(f),10)),'missing closing flag'
call check t~reject('invalid-stuff','01111110'||'11111111'||'01111110'),'missing stuffed zero'
call check t~reject('invalid-role',f),'incorrect command response role'
call check t~reject('bad-kind',''),'unknown frame kind'
call check t~reject('short-I',''),'missing I payload'
call check t~reject('unsupported-S',''),'unsupported selective supervisory code'
call check t~reject('bad-address',''),'out-of-scope multi-link address'

say 'RUN LAPB ACK and FCS corruption cannot mutate state'
a=.X25LapbLink~new('DTE',2,20,2)
b=.X25LapbLink~new('DCE',2,20,2)
ignore=a~start(0)
out=a~drainOutgoing
ignore=b~receive(out[1],1)
out=b~drainOutgoing
ignore=a~receive(out[1],2)
call check a~send('10010B11'x,3),'valid send accepted'
ignore=a~drainOutgoing
nr7=.X25LapbCodec~emit('DCE','RR',0,7)
call check t~reject('invalid-ack',nr7,a),'N(R) beyond issued window rejected'
call check a~outstanding=1 & a~va=0 & a~vs=1,'bad ACK did not mutate counters'
rr=.X25LapbCodec~emit('DCE','RR',0,1)
call check t~reject('bad-receive',left(rr,3)||'0000'x,a),'FCS mismatch cannot acknowledge'
call check a~outstanding=1 & a~va=0,'bad FCS left outstanding untouched'
call check a~receive(rr,4)='ACK_RR' & a~outstanding=0,'valid ACK subsequently accepted'

say 'RUN LAPB modulo-8 wrap and bounded window'
a=.X25LapbLink~new('DTE',2,20,3)
b=.X25LapbLink~new('DCE',2,20,3)
ignore=a~start(0);out=a~drainOutgoing;ignore=b~receive(out[1],1);out=b~drainOutgoing;ignore=a~receive(out[1],2)
do j=0 to 9
  call check a~send('10010B11'x,10+j*2),'send modulo8 iteration'||j
  out=a~drainOutgoing
  call check b~receive(out[1],11+j*2)='DATA_ACCEPTED','remote accepts modulo8 iteration'||j
  ack=b~drainOutgoing
  call check a~receive(ack[1],12+j*2)='ACK_RR','ack modulo8 iteration'||j
end
call check a~vs=2 & a~va=2 & b~vr=2,'modulo-8 counters wrap'
p=b~drainDelivered
call check p~items=10,'ten delivered messages without duplicate'

say 'RUN LAPB repeated REJ consumes bounded N2 budget'
a=.X25LapbLink~new('DTE',2,20,2)
b=.X25LapbLink~new('DCE',2,20,2)
ignore=a~start(0);out=a~drainOutgoing;ignore=b~receive(out[1],1);out=b~drainOutgoing;ignore=a~receive(out[1],2)
call check a~send('10010B11'x,3),'prepare one pending I'
ignore=a~drainOutgoing
rej=.X25LapbCodec~emit('DCE','REJ',0,0)
call check a~receive(rej,4)='ACK_REJ','first REJ consumes permitted retry'
call check a~drainOutgoing~items=1,'one bounded REJ replay'
call check a~receive(rej,5)='N2_EXHAUSTED','second REJ fails closed on N2'
call check a~state='FAILED' & a~drainOutgoing~items=0,'no unbounded REJ retransmission'

say 'PASS LAPB negative FCS, flags, unsupported types, ACK, wrap, no-mutation'
exit 0
check:
  use strict arg predicate,description
  if \predicate then do; say 'FAIL:' description; exit 1; end
  return
failure:
  say 'FAIL unexpected syntax:' condition('D')
  exit 1

::class LapbReject public
::method reject
  use strict arg scenario,frame,link=.nil
  signal on syntax name caught
  select
    when scenario='bad-fcs' then ignore=.X25LapbCodec~decode(frame,'DCE')
    when scenario='no-flag' then ignore=.X25HdlcBits~decode(frame)
    when scenario='invalid-stuff' then ignore=.X25HdlcBits~decode(frame)
    when scenario='invalid-role' then ignore=.X25LapbCodec~decode(frame,'DTE')
    when scenario='bad-kind' then ignore=.X25LapbCodec~emit('DTE','UNKNOWN')
    when scenario='short-I' then ignore=.X25LapbCodec~emit('DTE','I')
    when scenario='unsupported-S' then do
      raw='01CD'x
      ignore=.X25LapbCodec~decode(raw||.X25LapbCodec~fcs(raw),'DCE')
    end
    when scenario='bad-address' then do
      raw='0501'x
      ignore=.X25LapbCodec~decode(raw||.X25LapbCodec~fcs(raw),'DCE')
    end
    when scenario='invalid-ack' then ignore=link~receive(frame,4)
    when scenario='bad-receive' then ignore=link~receive(frame,4)
  end
  signal off syntax
  return .false
caught:
  signal off syntax
  return .true
::requires 'X25Lapb.cls'