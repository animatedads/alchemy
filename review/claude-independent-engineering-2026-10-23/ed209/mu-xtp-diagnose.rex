/* mu-xtp-diagnose.rex -- Increment B pre-step diagnostic for ED209 F/H.
 * Author: Claude (Opus 5.5), 2026-10-23. Architecture: Tom Dyer.
 * Status: NOT TESTED -- the Grid classes it requires (ObjectQueueXTPTransport.cls)
 * were not available to the author. It uses only calls already used by
 * ed209_rto2_20mi_candidate1/rexx/mu-rto2-submit.rex.
 *
 * Runs ON the owning MU. Sends exactly ONE authenticated PROBE through the
 * existing qf-xtp-rpc helper and classifies the reply so that one failure
 * cause is isolated per run. PROBE is an existing handler path that writes
 * nothing in the guest. This script writes nothing anywhere and never prints
 * key material. The key is read from the environment only.
 *
 * Usage (key in GRID_DIAG_KEY_HEX, never on the command line):
 *   rexx mu-xtp-diagnose.rex MI_ID MU_ID MI_MAC ROUTE_ID ROUTE_FILE HELPER PRINCIPAL KEY_ID CHANNEL
 *
 * Exit codes / classification:
 *   0  PROBE_OK                  authenticated HEALTH returned
 *   70 TRANSPORT_FAIL            helper reported failure (timeout, route, carrier)
 *   71 GUEST_PLAINTEXT_REJECT    guest replied "UNAUTHENTICATED:<reason>" (no peer row,
 *                                or the guest could not parse our frame)
 *   72 RESPONSE_UNPARSEABLE      reply is neither plaintext reject nor a parseable frame
 *                                (stdout contamination, truncation, segmentation)
 *   73 RESPONSE_AUTH_FAIL        frame parsed but did not authenticate under our key
 *   74 AUTHENTICATED_REJECT      guest authenticated us and refused (code reported)
 *   75 RESPONSE_BINDING_FAIL     authenticated but bound to the wrong correlation/peer/channel
 *   64/65 usage / invalid input
 */
parse arg nodeId muId mac routeId routeFile helper principal keyId channel
if nodeId="" | muId="" | mac="" | routeId="" | routeFile="" | helper="" | principal="" | keyId="" | channel="" then do
  say "usage: mu-xtp-diagnose.rex MI MU MI_MAC ROUTE_ID ROUTES XTP_HELPER PRINCIPAL KEY_ID CHANNEL (key in GRID_DIAG_KEY_HEX)"
  exit 64
end
keyHex=value("GRID_DIAG_KEY_HEX",,"ENVIRONMENT")
if keyHex~length<>64 then exit 65
if verify(keyHex~lower,"0123456789abcdef")<>0 then exit 65
if \datatype(routeId,"W") then exit 65
if routeId<1 | routeId>4095 then exit 65
if nodeId~length>48 | verify(nodeId,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-")<>0 then exit 65

nonce=.QueueXTPNonceSource~new~nextNonceHex
correlation="DIAG-"||nonce~left(24)
sourceManager="GRID.MU."||muId~upper
destinationManager="GRID.MN."||nodeId~upper
command=.QueueRecordCodec~encode("PROBE",.array~of(.QueueXTPTransportBuild~PROTOCOL))
frame=.QueueXTPWire~request(keyHex,correlation,sourceManager,destinationManager,channel,principal,keyId,nonce,command)
say "DIAG REQUEST mi="nodeId "mu="muId "principal="principal "key_id="keyId "channel="channel "route_id="routeId "frame_bytes="frame~length

endpoint=.QueueXTPEndpoint~new(destinationManager,mac,routeFile,principal,keyId,keyHex,6000,5,0,routeId,"none")
rpc=.QueueXTPNativeRpc~new(helper)
txn=x2d(nonce~left(7)) // 2147483648
if txn=0 then txn=1
call time "R"
rr=rpc~transact(endpoint,frame,txn)
elapsed=format(time("E"),,3)
if \rr~ok then do
  say "DIAG TRANSPORT_FAIL code="rr~code "detail="rr~detail "elapsed_s="elapsed
  exit 70
end
raw=rr~value
say "DIAG RESPONSE bytes="raw~length "elapsed_s="elapsed "head_hex="raw~left(16)~c2x

if raw~left(16)="UNAUTHENTICATED:" then do
  reason=raw~substr(17)~left(64)
  if verify(reason,"ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789")<>0 then reason="(non-token text, length "raw~length")"
  say "DIAG GUEST_PLAINTEXT_REJECT reason="reason
  exit 71
end

peekReply=.QueueXTPWire~parse(raw)
if peekReply==.nil then do
  embedded=raw~pos("UNAUTHENTICATED:")
  say "DIAG RESPONSE_UNPARSEABLE embedded_plaintext_reject_at="embedded "tail_hex="raw~right(16)~c2x
  exit 72
end

opened=.QueueXTPWire~open(keyHex,raw,"RESP")
if \opened~ok then do
  say "DIAG RESPONSE_AUTH_FAIL code="opened~code
  exit 73
end
head=opened~value["header"]
if head["correlation"]<>correlation then do
  say "DIAG RESPONSE_BINDING_FAIL field=correlation"
  exit 75
end
if head["source_manager"]<>destinationManager | head["destination_manager"]<>sourceManager then do
  say "DIAG RESPONSE_BINDING_FAIL field=manager source="head["source_manager"] "destination="head["destination_manager"]
  exit 75
end
if head["receiver_channel"]<>channel | head["principal"]<>principal then do
  say "DIAG RESPONSE_BINDING_FAIL field=channel_or_principal"
  exit 75
end
row=.QueueRecordCodec~decode(opened~value["plaintext"])
if row==.nil then do
  say "DIAG RESPONSE_UNPARSEABLE field=plaintext_record"
  exit 72
end
if row[1]="HEALTH" then do
  say "DIAG PROBE_OK health="row[3] "guest_time="row[4] "elapsed_s="elapsed
  exit 0
end
if row[1]="RESULT" then do
  say "DIAG AUTHENTICATED_REJECT code="row[4] "detail="row[5]
  exit 74
end
say "DIAG RESPONSE_UNEXPECTED type="row[1]
exit 72

::requires "ObjectQueueXTPTransport.cls"
