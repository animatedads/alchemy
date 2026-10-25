/* X25VirtualCircuit.cls — deterministic user-space X.25 SVC transition core.
 * Architecture Tom Dyer; coding ChatGPT (GPT-6).
 * No network I/O. No invented responses or implicit retransmissions.
 * Timers use caller-supplied monotonic ticks, never wall-clock comparisons.
 */
::class X25VirtualCircuit public
::method init
  expose interfaceId lcn incarnation state receiveNext remoteReady lastCause lastDiagnostic timerName deadline maxData
  use strict arg interfaceId, lcn, incarnation, maxData=128
  if interfaceId~string~strip="" then raise syntax 88.900 array("interface identifier required")
  if \datatype(lcn,"W") | lcn<1 | lcn>4095 then raise syntax 88.900 array("SVC requires LCN 1..4095")
  if incarnation~string~strip="" then raise syntax 88.900 array("incarnation required")
  if \datatype(maxData,"W") | maxData<1 | maxData>4096 then raise syntax 88.900 array("invalid maxData")
  state="IDLE"; receiveNext=0; remoteReady=.true
  lastCause=-1; lastDiagnostic=-1; timerName=""; deadline=-1
::attribute interfaceId get
::attribute lcn get
::attribute incarnation get
::attribute state get
::attribute receiveNext get
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
  expose state receiveNext remoteReady lastCause lastDiagnostic deadline timerName maxData lcn incarnation
  use strict arg packet, suppliedIncarnation
  if suppliedIncarnation<>incarnation then raise syntax 88.900 array("stale VC incarnation")
  if packet~lcn<>lcn | packet~maxData<>maxData then raise syntax 88.900 array("wrong LCN or profile")
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
      state="CLEAR_RECEIVED"; timerName=""; deadline=-1
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
      state="ACTIVE"
    end
    otherwise raise syntax 88.900 array("unimplemented packet transition: "||k)
  end
  return state

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
  expose state receiveNext remoteReady
  if state<>"RESET_RECEIVED" then raise syntax 88.900 array("no incoming RESET")
  state="ACTIVE"; receiveNext=0; remoteReady=.true
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