/* X25Packet.cls — ooRexx X.25 PLP octet codec, v0.1-dev1.
 * Architecture: Tom Dyer; coding: ChatGPT (GPT-6).
 * Strict modulo-8 laboratory subset. No driver, clock or live PLP claim.
 * The wire packet is retained, never flattened into a generic stream.
 */
::class X25Packet public
::method init
  expose raw maxData kind lcn modulo qualifier delivery typeByte sendSequence receiveSequence more cause diagnostic payload
  use strict arg raw, maxData=128
  if \datatype(maxData, "W") | maxData<1 | maxData>4096 then raise syntax 88.900 array("X25Packet: maxData must be integer 1..4096")
  if length(raw)<3 then raise syntax 88.900 array("X25Packet: short X.25 packet")
  b0=c2d(substr(raw,1,1)); b1=c2d(substr(raw,2,1)); typeByte=c2d(substr(raw,3,1))
  modulo=(b0 % 16) // 4
  if modulo<>1 then raise syntax 88.900 array("X25Packet: only modulo-8 GFI supported in dev1")
  qualifier=b0 % 128
  delivery=(b0 % 64) // 2
  lcn=(b0 // 16)*256+b1
  sendSequence=-1; receiveSequence=-1; more=0; cause=-1; diagnostic=-1
  payload=""; kind="UNKNOWN"
  select
    when typeByte//2=0 then do
      kind="DATA"
      sendSequence=(typeByte % 2) // 8
      more=(typeByte % 16) // 2
      receiveSequence=typeByte % 32
      payload=substr(raw,4)
      if length(payload)>maxData then raise syntax 88.900 array("X25Packet: DATA exceeds negotiated packet size")
    end
    when typeByte//32=1 | typeByte//32=5 | typeByte//32=9 then do
      receiveSequence=typeByte % 32
      select
        when typeByte//32=1 then kind="RR"
        when typeByte//32=5 then kind="RNR"
        when typeByte//32=9 then kind="REJ"
      end
      if length(raw)<>3 then raise syntax 88.900 array("X25Packet: flow-control packet has extra octets")
    end
    otherwise do
      select
        when typeByte=11 then kind="CALL"
        when typeByte=15 then kind="CALL_ACCEPTED"
        when typeByte=19 then kind="CLEAR"
        when typeByte=23 then kind="CLEAR_CONFIRM"
        when typeByte=27 then kind="RESET"
        when typeByte=31 then kind="RESET_CONFIRM"
        when typeByte=35 then kind="INTERRUPT"
        when typeByte=39 then kind="INTERRUPT_CONFIRM"
        when typeByte=241 then kind="DIAGNOSTIC"
        when typeByte=243 then kind="REGISTRATION"
        when typeByte=245 then kind="PVC_SETUP"
        when typeByte=247 then kind="REGISTRATION_CONFIRM"
        when typeByte=251 then kind="RESTART"
        when typeByte=255 then kind="RESTART_CONFIRM"
        otherwise raise syntax 88.900 array("X25Packet: unrecognised X.25 packet type")
      end
      select
        when kind="CALL" then do
          if length(raw)<5 then raise syntax 88.900 array("X25Packet: CALL lacks address-length and facility-length fields")
          addressLen=c2d(substr(raw,4,1))
          addressBytes=(addressLen//16 + addressLen%16 + 1)%2
          facilityOffset=5+addressBytes
          if length(raw)<facilityOffset then raise syntax 88.900 array("X25Packet: CALL truncated address block")
          facilityBytes=c2d(substr(raw,facilityOffset,1))
          if length(raw)<facilityOffset+facilityBytes then raise syntax 88.900 array("X25Packet: CALL truncated facilities")
          payload=substr(raw,facilityOffset+facilityBytes+1)
        end
        when kind="CLEAR" | kind="RESET" | kind="RESTART" then do
          if length(raw)<4 then raise syntax 88.900 array("X25Packet: cause octet missing")
          cause=c2d(substr(raw,4,1))
          if length(raw)>=5 then diagnostic=c2d(substr(raw,5,1))
        end
        when kind="INTERRUPT" then do
          payload=substr(raw,4)
          if length(payload)>32 then raise syntax 88.900 array("X25Packet: interrupt exceeds 32 octets")
        end
        when kind="CALL_ACCEPTED" then nop
        when kind="CLEAR_CONFIRM" | kind="RESET_CONFIRM" | kind="INTERRUPT_CONFIRM" | kind="RESTART_CONFIRM" then do
          if length(raw)<>3 then raise syntax 88.900 array("X25Packet: confirmation has extra octets in basic profile")
        end
        otherwise nop
      end
    end
  end
::attribute raw get
::attribute maxData get
::attribute kind get
::attribute lcn get
::attribute modulo get
::attribute qualifier get
::attribute delivery get
::attribute typeByte get
::attribute sendSequence get
::attribute receiveSequence get
::attribute more get
::attribute cause get
::attribute diagnostic get
::attribute payload get

/* Rewrite only the 12-bit interface-local LCN. No other packet bytes change. */
::method withLCN
  expose raw maxData
  use strict arg newLCN
  if \datatype(newLCN,"W") | newLCN<0 | newLCN>4095 then raise syntax 88.900 array("X25Packet: LCN outside 0..4095")
  b0=c2d(substr(raw,1,1))
  newFirst=(b0 % 16)*16 + newLCN % 256
  newRaw=d2c(newFirst)||d2c(newLCN//256)||substr(raw,3)
  return .X25Packet~new(newRaw,maxData)

/* SVC control construction is deliberately limited to unambiguous basic
 * CLEAR/RESET and confirmations. CALL facility encoding is not fabricated. */
::method control class
  use strict arg lcn, kind, cause=0, diagnostic=0
  if \datatype(lcn,"W") | lcn<0 | lcn>4095 then raise syntax 88.900 array("invalid LCN")
  if \datatype(cause,"W") | cause<0 | cause>255 then raise syntax 88.900 array("invalid cause")
  if \datatype(diagnostic,"W") | diagnostic<0 | diagnostic>255 then raise syntax 88.900 array("invalid diagnostic")
  select
    when kind="CLEAR" then n=19
    when kind="RESET" then n=27
    when kind="CLEAR_CONFIRM" then n=23
    when kind="RESET_CONFIRM" then n=31
    otherwise raise syntax 88.900 array("unsupported control constructor")
  end
  wire=d2c(16+lcn%256)||d2c(lcn//256)||d2c(n)
  if kind="CLEAR" | kind="RESET" then wire=wire||d2c(cause)||d2c(diagnostic)
  return .X25Packet~new(wire)

::method invalid private
  use strict arg why
  raise syntax 88.900 array("X25Packet: "||why)

/* Framing only. The caller owns TCP connections and must close on FAILED.
 * One TCP connection is required per VC under RFC 1613. */
::class XotFramer public
::method init
  expose pending failed maxPacket
  use strict arg maxPacket=4096
  if \datatype(maxPacket,"W") | maxPacket<3 | maxPacket>65535 then raise syntax 88.900 array("invalid maxPacket")
  pending=""; failed=.false
::attribute failed get
::method pendingLength
  expose pending
  return length(pending)

/* Emit RFC1613 version=0 (big endian) + 16-bit packet length. Reject the
 * XOT-forbidden link-local packet types. No network I/O is performed. */
::method frame
  expose failed maxPacket
  use strict arg packet
  if failed then raise syntax 88.900 array("XOT framer already failed")
  if packet~class<>.X25Packet then raise syntax 88.900 array("XOT requires X25Packet object")
  if length(packet~raw)>maxPacket then raise syntax 88.900 array("oversize XOT packet")
  if wordpos(packet~kind,"RESTART RESTART_CONFIRM REJ DIAGNOSTIC REGISTRATION REGISTRATION_CONFIRM")>0 then raise syntax 88.900 array("RFC1613 local-only packet cannot traverse XOT")
  n=length(packet~raw)
  return "0000"x||d2c(n%256)||d2c(n//256)||packet~raw

/* The returned array consists of complete raw X.25 packets. Incomplete
 * TCP reads are buffered under a strict negotiated bound, not discarded. */
::method push
  expose pending failed maxPacket
  use strict arg chunk
  if failed then raise syntax 88.900 array("XOT framer already failed")
  if length(chunk)>maxPacket+4-length(pending) then do
    /* Avoid unbounded buffering even when caller supplies a huge chunk. */
    /* Full multi-frame chunks use consume below in a streaming loop. */
    if length(chunk)>65536 then ignore=self~fail("TCP chunk exceeds 65536 octets")
  end
  pending=pending||chunk
  frames=.array~new
  do while length(pending)>=4
    if substr(pending,1,2)<>"0000"x then ignore=self~fail("nonzero XOT version")
    n=c2d(substr(pending,3,1))*256+c2d(substr(pending,4,1))
    if n<3 | n>maxPacket then ignore=self~fail("illegal XOT packet length")
    if length(pending)<n+4 then leave
    frames~append(substr(pending,5,n))
    pending=substr(pending,n+5)
  end
  if length(pending)>maxPacket+4 then ignore=self~fail("XOT buffer overrun")
  return frames

::method finish
  expose pending failed
  if failed then return .false
  if length(pending)<>0 then do
    failed=.true
    return .false
  end
  return .true

::method fail private
  expose failed pending
  use strict arg why
  failed=.true; pending=""
  raise syntax 88.900 array("XOT: "||why)