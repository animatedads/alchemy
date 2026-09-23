parse arg port bridge caFile
cfg=.ImapSocketTransportConfig~new; cfg~host="localhost"; cfg~port=port+0; cfg~security="IMPLICIT_TLS"; cfg~bridgeDirectory=bridge; cfg~caFile=caFile; cfg~verifyPeer=.true
transport=.ImapSocketTransport~new(cfg); s=.ImapSession~new(transport)
s~acceptGreeting; call assert \s~capabilities~has("MOVE") & s~capabilities~has("UIDPLUS"),"fallback capability shape"
call assert s~login("user","pass")~ok,"login"
call assert s~select("SRC")~ok,"select"
r=.ImapTransferOps~moveSameSession(s,"8","DST",.false,.true,"ORDINARY")
call assert r~ok & r~strategy="UID_COPY_UID_EXPUNGE","fallback transport move"
call assert r~destinationResult~destinationUidFor(8)=80,"fallback transport mapping"
call assert r~sourceRemoval~sourceRemovalComplete,"fallback source removal"
s~logout; transport~close
say "PASS test_move_fallback_transport"
exit 0
assert: procedure
  use strict arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
  return
::requires "ImapApiTlsTransport.cls"
::requires "ImapTransfer.cls"
