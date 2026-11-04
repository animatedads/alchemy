/* User-space LAPB modulo-8 laboratory layer for ooRexx 5.3.0.
 * Architecture: Tom Dyer. Code: ChatGPT GPT-6, 2026-10-29.
 * No native link, no implicit I/O. Wire input/output are HDLC-de-stuffed
 * address+control+information+FCS octets; raw serial adapters must be separate.
 */
::class X25LapbFrame public
::method init
  expose wire address control kind ns nr pf payload command
  use strict arg wire,address,control,kind,ns,nr,pf,payload,command
::attribute wire get
::attribute address get
::attribute control get
::attribute kind get
::attribute ns get
::attribute nr get
::attribute pf get
::attribute payload get
::attribute command get

::class X25LapbCodec public
::method fcs class
  use strict arg bytes
  crc=65535
  do i=1 to length(bytes)
    low=crc//256
    crc=crc-low+c2d(bitxor(d2c(low),substr(bytes,i,1)))
    do j=1 to 8
      if crc//2=1 then crc=c2d(bitxor(d2c(crc%2,2),'8408'x))
      else crc=crc%2
    end
  end
  crc=c2d(bitxor(d2c(crc,2),'FFFF'x))
  return d2c(crc//256)||d2c(crc%256)

::method emit class
  use strict arg role,kind,ns=0,nr=0,payload='',poll=.false,response=.false
  role=role~string~upper
  if role<>"DTE" & role<>"DCE" then raise syntax 88.900 array('LAPB role must be DTE or DCE')
  if \datatype(ns,'W') | ns<0 | ns>7 | \datatype(nr,'W') | nr<0 | nr>7 then raise syntax 88.900 array('LAPB modulo-8 sequence outside 0..7')
  if poll<>.true & poll<>.false then raise syntax 88.900 array('LAPB poll must be boolean')
  if response<>.true & response<>.false then raise syntax 88.900 array('LAPB response must be boolean')
  if role='DTE' then do
    if response then address=3
    else address=1
  end
  else do
    if response then address=1
    else address=3
  end
  select
    when kind='I' then do
      if response then raise syntax 88.900 array('LAPB I-frame is a command')
      if length(payload)<1 then raise syntax 88.900 array('LAPB I requires payload')
      control=ns*2 + nr*32
    end
    when kind='RR' then control=1+nr*32
    when kind='RNR' then control=5+nr*32
    when kind='REJ' then control=9+nr*32
    when kind='SABM' then control=47
    when kind='UA' then control=99
    when kind='DISC' then control=67
    when kind='DM' then control=15
    otherwise raise syntax 88.900 array('unsupported LAPB control kind')
  end
  if wordpos(kind,'I SABM DISC')>0 & response then raise syntax 88.900 array('LAPB command type sent as response')
  if wordpos(kind,'UA DM')>0 & \response then raise syntax 88.900 array('LAPB response type sent as command')
  if poll then control=control+16
  if kind<>'I' & kind<>'RR' & kind<>'RNR' & kind<>'REJ' & payload<>'' then raise syntax 88.900 array('unexpected LAPB control payload')
  raw=d2c(address)||d2c(control)||payload
  return raw||self~fcs(raw)

::method decode class
  use strict arg wire, receiverRole='DTE', maxInformation=4096
  if \datatype(maxInformation,'W') | maxInformation<1 | maxInformation>65535 then raise syntax 88.900 array('invalid LAPB maximum information length')
  if length(wire)<4 | length(wire)>maxInformation+4 then raise syntax 88.900 array('LAPB wire length invalid')
  raw=left(wire,length(wire)-2)
  if self~fcs(raw)<>right(wire,2) then raise syntax 88.900 array('LAPB FCS mismatch')
  address=c2d(substr(raw,1,1)); control=c2d(substr(raw,2,1))
  if address<>1 & address<>3 then raise syntax 88.900 array('unsupported LAPB single-link address')
  if receiverRole='DTE' then command=(address=3)
  else if receiverRole='DCE' then command=(address=1)
  else raise syntax 88.900 array('invalid LAPB receiver role')
  pf=(control%16)//2
  ns=-1; nr=-1; payload=substr(raw,3)
  select
    when control//2=0 then do
      kind='I'; ns=(control%2)//8; nr=control%32
      if \command then raise syntax 88.900 array('I response address invalid')
      if length(payload)=0 then raise syntax 88.900 array('LAPB I missing information')
    end
    when control//4=1 then do
      nr=control%32
      select
        when (control%4)//4=0 then kind='RR'
        when (control%4)//4=1 then kind='RNR'
        when (control%4)//4=2 then kind='REJ'
        otherwise raise syntax 88.900 array('unsupported LAPB S-frame')
      end
      if payload<>'' then raise syntax 88.900 array('LAPB S-frame with information')
    end
    otherwise do
      base=control-16*pf
      select
        when base=47 then kind='SABM'
        when base=99 then kind='UA'
        when base=67 then kind='DISC'
        when base=15 then kind='DM'
        otherwise raise syntax 88.900 array('unsupported LAPB U-frame')
      end
      if wordpos(kind,'SABM DISC')>0 & \command then raise syntax 88.900 array('LAPB command on response address')
      if wordpos(kind,'UA DM')>0 & command then raise syntax 88.900 array('LAPB response on command address')
      if payload<>'' then raise syntax 88.900 array('unexpected LAPB U-frame information')
    end
  end
  return .X25LapbFrame~new(wire,address,control,kind,ns,nr,pf,payload,command)

::class X25LapbOutstanding public
::method init
  expose sequence payload
  use strict arg sequence,payload
::attribute sequence get
::attribute payload get

::class X25LapbLink public
::method init
  expose role window t1 n2 maxInformation state vs va vr remoteBusy unacked outbound delivered deadline attempts lastTx controlWaiting
  use strict arg role='DTE',window=2,t1=500,n2=3,maxInformation=4096
  if role<>'DTE' & role<>'DCE' then raise syntax 88.900 array('invalid LAPB role')
  if \datatype(window,'W') | window<1 | window>7 then raise syntax 88.900 array('window must be 1..7 for modulo-8')
  if \datatype(t1,'N') | t1<=0 | \datatype(n2,'W') | n2<1 | n2>255 then raise syntax 88.900 array('invalid T1 or N2')
  if \datatype(maxInformation,'W') | maxInformation<3 | maxInformation>65535 then raise syntax 88.900 array('invalid information bound')
  state='DISCONNECTED';vs=0;va=0;vr=0;remoteBusy=.false
  unacked=.array~new;outbound=.array~new;delivered=.array~new
  deadline=-1;attempts=0;lastTx='';controlWaiting=''
::attribute role get
::attribute window get
::attribute state get
::attribute vs get
::attribute va get
::attribute vr get
::attribute remoteBusy get
::attribute deadline get
::attribute attempts get
::method outstanding
  expose unacked
  return unacked~items
::method drainOutgoing
  expose outbound
  result=outbound;outbound=.array~new
  return result
::method drainDelivered
  expose delivered
  result=delivered;delivered=.array~new
  return result
::method start
  expose state outbound deadline attempts t1 controlWaiting role
  use strict arg now
  if state<>'DISCONNECTED' then raise syntax 88.900 array('LAPB start requires disconnected state')
  if \datatype(now,'N') then raise syntax 88.900 array('monotonic tick required')
  state='AWAIT_UA';controlWaiting='SABM';attempts=1;deadline=now+t1
  outbound~append(.X25LapbCodec~emit(role,'SABM',0,0,'',.true))
  return state
::method send
  expose state remoteBusy unacked vs vr role window outbound deadline attempts t1 maxInformation
  use strict arg payload,now
  if \datatype(now,'N') then raise syntax 88.900 array('monotonic tick required')
  if state<>'CONNECTED' then raise syntax 88.900 array('link not connected')
  if remoteBusy then return .false
  if unacked~items>=window then return .false
  if length(payload)<3 | length(payload)>maxInformation then raise syntax 88.900 array('invalid PLP payload size')
  if unacked~items=0 then do
    attempts=1;deadline=now+t1
  end
  unacked~append(.X25LapbOutstanding~new(vs,payload))
  outbound~append(.X25LapbCodec~emit(role,'I',vs,vr,payload))
  vs=(vs+1)//8
  return .true
::method receive
  expose role state vs va vr remoteBusy unacked outbound delivered deadline attempts t1 n2 controlWaiting
  use strict arg wire,now
  if \datatype(now,'N') then raise syntax 88.900 array('monotonic tick required')
  frame=.X25LapbCodec~decode(wire,role)
  k=frame~kind
  if k='SABM' then do
    vs=0;va=0;vr=0;unacked=.array~new;remoteBusy=.false
    state='CONNECTED';controlWaiting='';deadline=-1;attempts=0
    outbound~append(.X25LapbCodec~emit(role,'UA',0,0,'',frame~pf=1,.true))
    return 'LINK_ESTABLISHED_BY_PEER'
  end
  if k='DISC' then do
    outbound~append(.X25LapbCodec~emit(role,'UA',0,0,'',frame~pf=1,.true))
    state='DISCONNECTED';unacked=.array~new;controlWaiting='';deadline=-1;attempts=0
    return 'LINK_DISCONNECTED_BY_PEER'
  end
  if k='UA' then do
    if state='AWAIT_UA' then do
      state='CONNECTED';vs=0;va=0;vr=0;unacked=.array~new
      deadline=-1;attempts=0;controlWaiting='';remoteBusy=.false
      return 'LINK_ESTABLISHED'
    end
    if state='AWAIT_DISC' then do
      state='DISCONNECTED';deadline=-1;attempts=0;controlWaiting=''
      return 'LINK_DISCONNECTED'
    end
    return 'UNSOLICITED_UA'
  end
  if k='DM' then do
    state='DISCONNECTED';deadline=-1;attempts=0;unacked=.array~new
    return 'LINK_DISCONNECTED_BY_PEER'
  end
  if state<>'CONNECTED' then raise syntax 88.900 array('LAPB numbered frame before link establishment')
  /* ACK validity precedes any sequence/state mutation. */
  ackDistance=(frame~nr-va+8)//8
  if ackDistance>unacked~items then raise syntax 88.900 array('LAPB invalid N(R)')
  if ackDistance>0 then do
    keep=.array~new
    do i=ackDistance+1 to unacked~items
      keep~append(unacked[i])
    end
    unacked=keep;va=frame~nr
    if unacked~items=0 then do
      deadline=-1;attempts=0
    end
    else do
      deadline=now+t1;attempts=1
    end
  end
  if k='RR' then do
    remoteBusy=.false
    if frame~pf=1 & frame~command then outbound~append(.X25LapbCodec~emit(role,'RR',0,vr,'',.true,.true))
    return 'ACK_RR'
  end
  if k='RNR' then do
    remoteBusy=.true
    if frame~pf=1 & frame~command then outbound~append(.X25LapbCodec~emit(role,'RR',0,vr,'',.true,.true))
    return 'ACK_RNR'
  end
  if k='REJ' then do
    remoteBusy=.false
    if unacked~items=0 then return 'ACK_REJ_EMPTY'
    /* REJ-triggered replay counts against N2 as much as a T1 timeout;
     * an untrusted peer cannot force unbounded I-frame amplification. */
    if attempts>=n2 then do
      state='FAILED';deadline=-1
      return 'N2_EXHAUSTED'
    end
    attempts=attempts+1;deadline=now+t1
    self~resendOutstanding
    return 'ACK_REJ'
  end
  if k='I' then do
    if frame~ns=vr then do
      delivered~append(frame~payload)
      vr=(vr+1)//8
      outbound~append(.X25LapbCodec~emit(role,'RR',0,vr,'',frame~pf=1,.true))
      return 'DATA_ACCEPTED'
    end
    /* Duplicate previous I is ACKed but never delivered again. */
    if frame~ns=(vr+7)//8 then do
      outbound~append(.X25LapbCodec~emit(role,'RR',0,vr,'',frame~pf=1,.true))
      return 'DATA_DUPLICATE'
    end
    outbound~append(.X25LapbCodec~emit(role,'REJ',0,vr,'',frame~pf=1,.true))
    return 'DATA_OUT_OF_SEQUENCE'
  end
  raise syntax 88.900 array('unexpected LAPB frame')
::method resendOutstanding private
  expose unacked outbound role vr
  do i=1 to unacked~items
    outstanding=unacked[i]
    outbound~append(.X25LapbCodec~emit(role,'I',outstanding~sequence,vr,outstanding~payload))
  end
::method tick
  expose deadline attempts n2 t1 state outbound controlWaiting role unacked
  use strict arg now
  if \datatype(now,'N') then raise syntax 88.900 array('monotonic tick required')
  if deadline<0 | now<deadline then return 'NONE'
  if attempts>=n2 then do
    state='FAILED';deadline=-1;return 'N2_EXHAUSTED'
  end
  attempts=attempts+1;deadline=now+t1
  if state='AWAIT_UA' then outbound~append(.X25LapbCodec~emit(role,'SABM',0,0,'',.true))
  else if state='AWAIT_DISC' then outbound~append(.X25LapbCodec~emit(role,'DISC',0,0,'',.true))
  else if state='CONNECTED' & unacked~items>0 then self~resendOutstanding
  else do
    deadline=-1;return 'NONE'
  end
  return 'RETRANSMITTED'
::method disconnect
  expose role state outbound controlWaiting deadline attempts t1
  use strict arg now
  if state<>'CONNECTED' then raise syntax 88.900 array('disconnect requires connected link')
  if \datatype(now,'N') then raise syntax 88.900 array('monotonic tick required')
  state='AWAIT_DISC';controlWaiting='DISC';attempts=1;deadline=now+t1
  outbound~append(.X25LapbCodec~emit(role,'DISC',0,0,'',.true))
  return state

/* Pure ooRexx HDLC bit-stuffing model. Returned strings contain ASCII bit
 * symbols, NOT electrical serial octets. A sync-device adapter owns clocks,
 * flags, delineation and whether FCS/bit-stuffing is performed in hardware. */
::class X25HdlcBits public
::method encode class
  use strict arg octets
  if length(octets)<4 | length(octets)>65539 then raise syntax 88.900 array('invalid HDLC octet length')
  flag='01111110';body='';ones=0
  do i=1 to length(octets)
    n=c2d(substr(octets,i,1))
    do j=0 to 7
      bit=(n%(2**j))//2
      body=body||bit
      if bit=1 then do
        ones=ones+1
        if ones=5 then do
          body=body||'0';ones=0
        end
      end
      else ones=0
    end
  end
  return flag||body||flag
::method decode class
  use strict arg bitstream,maxOctets=65539
  if \datatype(maxOctets,'W') | maxOctets<4 | maxOctets>65539 then raise syntax 88.900 array('invalid HDLC bound')
  if length(bitstream)<48 | length(bitstream)>maxOctets*10+16 then raise syntax 88.900 array('HDLC bitstream size refused')
  if verify(bitstream,'01')<>0 then raise syntax 88.900 array('HDLC non-bit character')
  if left(bitstream,8)<>'01111110' | right(bitstream,8)<>'01111110' then raise syntax 88.900 array('HDLC flags missing')
  body=substr(bitstream,9,length(bitstream)-16)
  plain='';ones=0;i=1
  do while i<=length(body)
    bit=substr(body,i,1)
    if bit=1 then do
      ones=ones+1
      if ones=5 then do
        i=i+1
        if i>length(body) | substr(body,i,1)<>'0' then raise syntax 88.900 array('HDLC invalid five-ones stuffing')
        ones=0
      end
    end
    else ones=0
    plain=plain||bit
    i=i+1
  end
  if length(plain)//8<>0 then raise syntax 88.900 array('HDLC non-octet-aligned frame')
  if length(plain)%8>maxOctets then raise syntax 88.900 array('HDLC received octets exceed bound')
  result=''
  do i=1 to length(plain) by 8
    n=0
    do j=0 to 7
      n=n+(substr(plain,i+j,1)+0)*(2**j)
    end
    result=result||d2c(n,1)
  end
  return result