/* X25VirtualCircuit.cls — deterministic user-space X.25 SVC transition core.
 * Architecture Tom Dyer; coding ChatGPT (GPT-6).
 * No network I/O. No invented responses or implicit retransmissions.
 * Timers use caller-supplied monotonic ticks, never wall-clock comparisons.
 */
::class X25VirtualCircuit public
::method init
  expose interfaceId lcn incarnation state receiveNext sendNext remoteReady lastCause lastDiagnostic timerName deadline maxData role
  use strict arg interfaceId, lcn, incarnation, maxData=128, role="DTE"
  if interfaceId~string~strip="" then raise syntax 88.900 array("interface identifier required")
  if \datatype(lcn,"W") | lcn<1 | lcn>4095 then raise syntax 88.900 array("SVC requires LCN 1..4095")
  if incarnation~string~strip="" then raise syntax 88.900 array("incarnation required")
  if \datatype(maxData,"W") | maxData<1 | maxData>4096 then raise syntax 88.900 array("invalid maxData")
  if role<>"DTE" & role<>"DCE" then raise syntax 88.900 array("explicit DTE or DCE role required")
  state="IDLE"; receiveNext=0; sendNext=0; remoteReady=.true
  lastCause=-1; lastDiagnostic=-1; timerName=""; deadline=-1
::attribute interfaceId get
::attribute lcn get
::attribute incarnation get
::attribute state get
::attribute receiveNext get
::attribute sendNext get
::attribute role get
::attribute remoteReady get
::attribute lastCause get
::attribute lastDiagnostic get
::attribute timerName get
::attribute deadline get
::attribute maxData get
::method identity
  expose interfaceId lcn incarnation
  return interfaceId||":"||lcn||":"||incarnation

/* Caller has already obtained permission for outbound CALL; no CALL wire
 * encoding is attempted here. t21 is an explicit per-profile timeout. */
::method beginCall
  expose state timerName deadline lcn maxData
  use strict arg packet, now, t21
  if state<>"IDLE" then raise syntax 88.900 array("SVC is already in use")
  if packet~kind<>"CALL" | packet~lcn<>lcn then raise syntax 88.900 array("outgoing CALL required on same LCN")
  if \datatype(now,"N") | \datatype(t21,"N") | t21<=0 then raise syntax 88.900 array("T21 duration and monotonic tick required")
  if packet~maxData<>maxData then raise syntax 88.900 array("packet profile mismatch")
  state="CALL_SENT"; timerName="T21"; deadline=now+t21
  return state

/* Inbound event: require exact incarnation to fence late old-circuit data.
 * Does not inject packets, ack the remote, or imply application acceptance. */
::method receive
  expose state receiveNext sendNext remoteReady lastCause lastDiagnostic deadline timerName maxData lcn incarnation
  use strict arg packet, suppliedIncarnation
  if suppliedIncarnation<>incarnation then raise syntax 88.900 array("stale VC incarnation")
  if packet~lcn<>lcn | packet~maxData<>maxData then raise syntax 88.900 array("wrong LCN or profile")
  rejection=self~inspectIncoming(packet, suppliedIncarnation)
  if rejection<>.nil then raise syntax 88.900 array("X25VirtualCircuit: "||rejection~reason)
  k=packet~kind
  select
    when k="CALL" then do
      if state<>"IDLE" then raise syntax 88.900 array("unexpected incoming CALL")
      state="CALL_INCOMING"
    end
    when k="CALL_ACCEPTED" then do
      if state<>"CALL_SENT" then raise syntax 88.900 array("unexpected CALL ACCEPTED")
      state="ACTIVE"; timerName=""; deadline=-1
    end
    when k="DATA" then do
      if state<>"ACTIVE" then raise syntax 88.900 array("DATA outside active VC")
      if packet~sendSequence<>receiveNext then raise syntax 88.900 array("unexpected X.25 DATA sequence")
      receiveNext=(receiveNext+1)//8
    end
    when k="RR" | k="RNR" then do
      if state<>"ACTIVE" then raise syntax 88.900 array("RR/RNR outside active VC")
      remoteReady=(k="RR")
    end
    when k="CLEAR" then do
      if state="IDLE" | state="CLEARED" | state="TIMED_OUT" then raise syntax 88.900 array("CLEAR outside circuit")
      lastCause=packet~cause; lastDiagnostic=packet~diagnostic
      /* Simultaneous clear is already complete; do not send a second
       * CLEAR CONFIRM as if it were a newly received clear. */
      if state="CLEAR_SENT" then state="CLEARED"
      else state="CLEAR_RECEIVED"
      timerName=""; deadline=-1
    end
    when k="CLEAR_CONFIRM" then do
      if state<>"CLEAR_SENT" then raise syntax 88.900 array("unexpected CLEAR confirmation")
      state="CLEARED"; timerName=""; deadline=-1
    end
    when k="RESET" then do
      if state<>"ACTIVE" then raise syntax 88.900 array("RESET outside active circuit")
      lastCause=packet~cause; lastDiagnostic=packet~diagnostic
      state="RESET_RECEIVED"
    end
    when k="RESET_CONFIRM" then do
      if state<>"RESET_SENT" then raise syntax 88.900 array("unexpected RESET confirmation")
      state="ACTIVE"; receiveNext=0; sendNext=0; remoteReady=.true
    end
    otherwise raise syntax 88.900 array("unimplemented packet transition: "||k)
  end
  return state

/* Deterministic diagnostic proposal. It neither modifies the VC nor
 * transmits a packet. The caller decides whether to emit the RESET.
 * Only invalid P(S) has an evidenced protocol mapping in this dev slice.
 * Other rejections are local-only until their edition/profile is qualified. */
::method inspectIncoming
  expose state receiveNext lcn incarnation maxData role
  use strict arg packet, suppliedIncarnation
  if suppliedIncarnation<>incarnation then return .X25CircuitRejection~new("STALE_INCAR", "LOCAL_ONLY", -1,-1,lcn)
  if packet~lcn<>lcn | packet~maxData<>maxData then return .X25CircuitRejection~new("LCN_OR_PROFILE_MISMATCH", "LOCAL_ONLY", -1,-1,lcn)
  if packet~kind="DATA" & state="ACTIVE" then do
    if packet~sendSequence<>receiveNext then do
      /* ITU-T X.25 diagnostic 1 is invalid P(S); the local DTE uses
       * cause 0, whereas a DCE uses cause 5 (local procedure error). */
      if role="DTE" then cause=0
      else cause=5
      return .X25CircuitRejection~new("INVALID_PS", "RESET",cause,1,lcn)
    end
  end
  return .nil

/* Decode hostile octets without permitting the decoder's SYNTAX failure
 * to bypass the circuit-level policy. This intentionally maps only error
 * cases with an unambiguous X.25 diagnostic for an already ACTIVE VC.
 * ITU-T X.25 Annex E: 38 packet too short; 39 packet too long.
 * Missing channel identity, unsupported GFI and unknown packet types
 * remain LOCAL_ONLY rather than guessing a network response. */
::method inspectRaw
  expose state lcn incarnation maxData role
  use strict arg raw, suppliedIncarnation
  if suppliedIncarnation<>incarnation then return .X25CircuitRejection~new("STALE_INCAR", "LOCAL_ONLY",-1,-1,lcn)
  signal on syntax name malformed
  decoded=.X25Packet~new(raw,maxData)
  signal off syntax
  return self~inspectIncoming(decoded,suppliedIncarnation)
malformed:
  signal off syntax
  if length(raw)<3 then return .X25CircuitRejection~new("TRUNCATED_OR_UNKNOWN_HEADER", "LOCAL_ONLY",-1,-1,lcn)
  b0=c2d(substr(raw,1,1))
  channel=(b0//16)*256+c2d(substr(raw,2,1))
  if channel<>lcn | (b0%16)//4<>1 then return .X25CircuitRejection~new("BAD_LCN_OR_GFI", "LOCAL_ONLY",-1,-1,lcn)
  if state<>"ACTIVE" then return .X25CircuitRejection~new("MALFORMED_NOT_ACTIVE", "LOCAL_ONLY",-1,-1,lcn)
  kindByte=c2d(substr(raw,3,1))
  if kindByte//2=0 then do
    if length(raw)>maxData+3 then diagnostic=39
    else return .X25CircuitRejection~new("MALFORMED_DATA_UNMAPPED", "LOCAL_ONLY",-1,-1,lcn)
  end
  else if kindByte=35 & length(raw)=3 then diagnostic=38
  else return .X25CircuitRejection~new("MALFORMED_CONTROL_UNMAPPED", "LOCAL_ONLY",-1,-1,lcn)
  if role="DTE" then cause=0
  else cause=5
  return .X25CircuitRejection~new("MALFORMED_WIRE", "RESET",cause,diagnostic,lcn)

/* Record local DATA packet sequence preparation only; transport send,
 * acknowledgements and credit/window management are not implemented. */
::method noteDataSent
  expose state lcn maxData sendNext
  use strict arg packet
  if state<>"ACTIVE" | packet~kind<>"DATA" | packet~lcn<>lcn | packet~maxData<>maxData then raise syntax 88.900 array("outgoing DATA requires active matching VC")
  if packet~sendSequence<>sendNext then raise syntax 88.900 array("outgoing P(S) mismatch")
  sendNext=(sendNext+1)//8
  return sendNext

/* External caller must enforce policy/facilities before admitting a CALL. */
::method acceptIncoming
  expose state
  use strict arg authorised
  if state<>"CALL_INCOMING" | authorised<>.true then raise syntax 88.900 array("incoming CALL not authorised or not pending")
  state="ACTIVE"
  return state

::method beginClear
  expose state lastCause lastDiagnostic deadline timerName
  use strict arg cause=0, diagnostic=0
  if state<>"ACTIVE" & state<>"CALL_SENT" & state<>"CALL_INCOMING" & state<>"RESET_SENT" then raise syntax 88.900 array("cannot clear in current state")
  if \datatype(cause,"W") | cause<0 | cause>255 | \datatype(diagnostic,"W") | diagnostic<0 | diagnostic>255 then raise syntax 88.900 array("invalid clear diagnosis")
  lastCause=cause; lastDiagnostic=diagnostic
  state="CLEAR_SENT"; timerName=""; deadline=-1
  return state

::method confirmIncomingClear
  expose state
  if state<>"CLEAR_RECEIVED" then raise syntax 88.900 array("no incoming CLEAR")
  state="CLEARED"
  return state

::method beginReset
  expose state
  if state<>"ACTIVE" then raise syntax 88.900 array("reset requires active VC")
  state="RESET_SENT"
  return state

::method confirmIncomingReset
  expose state receiveNext sendNext remoteReady
  if state<>"RESET_RECEIVED" then raise syntax 88.900 array("no incoming RESET")
  state="ACTIVE"; receiveNext=0; sendNext=0; remoteReady=.true
  return state

/* Only the configured CALL timer exists in this dev1 slice. Return true
 * exactly when the expiry transitions; duplicate ticks cannot replay it. */
::method tick
  expose state timerName deadline
  use strict arg now
  if \datatype(now,"N") then raise syntax 88.900 array("monotonic tick required")
  if timerName="" then return .false
  if now<deadline then return .false
  state="TIMED_OUT"; timerName=""; deadline=-1
  return .true

/* A typed, non-transmitting error mapping. A negative cause/diagnostic
 * means no qualified wire response is available for this reason. */
::class X25CircuitRejection public
::method init
  expose reason action cause diagnostic lcn
  use strict arg reason, action, cause, diagnostic, lcn
::attribute reason get
::attribute action get
::attribute cause get
::attribute diagnostic get
::attribute lcn get
::method hasWireResponse
  expose action cause diagnostic
  return action="RESET" & cause>=0 & diagnostic>=0
::method responsePacket
  expose action cause diagnostic lcn
  if \self~hasWireResponse then raise syntax 88.900 array("no qualified X.25 wire response")
  return .X25Packet~control(lcn, action, cause, diagnostic)

::requires 'X25Packet.cls'