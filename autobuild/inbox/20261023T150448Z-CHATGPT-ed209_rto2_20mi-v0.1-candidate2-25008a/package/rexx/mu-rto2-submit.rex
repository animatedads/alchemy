/* MU-side authenticated native XTP request to commissioned MI. This is NOT SSH dispatch.
 * Invocation is via the owning MU's operator CLI, not through a remote MI shell.
 */
parse arg runId nodeId muId count epoch mac routeId routeFile helper keyHex
if runId="" | nodeId="" | muId="" | count="" | epoch="" | mac="" | routeId="" | routeFile="" | helper="" | keyHex="" then do
  say "usage: mu-rto2-submit.rex RUN MI MU N EPOCH MI_MAC ROUTE_ID ROUTES XTP_HELPER KEY_HEX"; exit 64
end
if keyHex="@env" then keyHex=value("GRID_RTO2_KEY_HEX",,"ENVIRONMENT")
if \datatype(count,"W") | count<1 | count>1000 | \datatype(epoch,"W") | epoch<1 then exit 65
if \datatype(routeId,"W") | routeId<1 | routeId>4095 then exit 65
if verify(keyHex~lower,"0123456789abcdef")<>0 | keyHex~length<>64 then exit 65
if runId~length>80 | verify(runId,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")<>0 then exit 65
if nodeId~length>48 | verify(nodeId,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-")<>0 then exit 65
nonce=.QueueXTPNonceSource~new~nextNonceHex
correlation="RTO2-"||nonce~left(24)
sourceManager="GRID.MU."||muId~upper
destinationManager="GRID.MN."||nodeId~upper
ch="RTO2."||nodeId~upper
command=.QueueRecordCodec~encode("RTO2_WORK",.array~of(.QueueXTPTransportBuild~PROTOCOL,runId,nodeId,count,epoch))
frame=.QueueXTPWire~request(keyHex,correlation,sourceManager,destinationManager,ch,"grid-controller","k1",nonce,command)
/* XTP route table keys are symbolic identities (GRID.MN.*), never MACs.
 * libxtp selects the commissioned MAC and egress device from that route.
 */
e=.QueueXTPEndpoint~new(destinationManager,destinationManager,routeFile,"grid-controller","k1",keyHex,6000,5,0,routeId,"none")
rpc=.QueueXTPNativeRpc~new(helper)
txn=x2d(nonce~left(7)) // 2147483648
if txn=0 then txn=1
rr=rpc~transact(e,frame,txn)
if \rr~ok then do; say "XTP_REQUEST_FAILED" rr~code rr~detail; exit 70; end
/* A native XTP ACK only establishes packet delivery. A guest without the
 * RTO2 controller grant returns a plaintext UNAUTHENTICATED response, which
 * must never be mistaken for an authenticated job receipt. Classify without
 * printing arbitrary untrusted response data or credential material.
 */
responseBytes=rr~value
if .QueueXTPWire~parse(responseBytes)==.nil then do
  if responseBytes~left(16)="UNAUTHENTICATED:" then do
    if responseBytes="UNAUTHENTICATED:PEER_NOT_TRUSTED" then do
      say "RTO2_MI_CONTROLLER_GRANT_ABSENT_OR_STALE"; exit 71
    end
    say "RTO2_MI_UNAUTHENTICATED_REJECTION"; exit 71
  end
  say "RTO2_MI_RESPONSE_NOT_QFXTP bytes="||responseBytes~length; exit 71
end
opened=.QueueXTPWire~open(keyHex,responseBytes,"RESP")
if \opened~ok then do; say "XTP_RESPONSE_AUTH_FAILED" opened~code; exit 71; end
head=opened~value["header"]
if head["correlation"]<>correlation | head["source_manager"]<>destinationManager | head["destination_manager"]<>sourceManager | head["receiver_channel"]<>ch | head["principal"]<>"grid-controller" then do
  say "XTP_RESPONSE_BINDING_FAILED"; exit 72
end
row=.QueueRecordCodec~decode(opened~value["plaintext"])
if row==.nil then do; say "XTP_RESPONSE_INVALID"; exit 73; end
if row[1]="RESULT" then do; say "RTO2_REMOTE_REJECT" row[4] row[5]; exit 74; end
if row~items<>3 | row[1]<>"RTO2_WORK_RESULT" | row[2]<>.QueueXTPTransportBuild~PROTOCOL then do; say "RTO2_WRONG_RESPONSE"; exit 75; end
result=.json~fromJson(row[3])
if result["schema"]<>"rexxos.rto2.smoke.result/1" | result["node_id"]<>nodeId | result["run_id"]<>runId | result["n"]<>count | result["epoch"]<>epoch then do; say "RTO2_RESULT_IDENTITY_MISMATCH"; exit 76; end
if result["committed_sequence"]<>1 | result["committed_value"]<>count*(count+1)/2 | result["role"]<>"ACTIVE" then do; say "RTO2_RESULT_NOT_COMMITTED"; exit 77; end
receipt=.Directory~new
receipt["schema"]="ed209.rto2.controller-receipt/1"
receipt["run_id"]=runId;receipt["mi_id"]=nodeId;receipt["mu_id"]=muId
receipt["controller_id"]=sourceManager; receipt["delivery"]="authenticated-xtp-qf-wire-response"
receipt["response_correlation"]=correlation
receipt["rto2"]=result
say .json~toJson(receipt)
exit 0
::requires "ObjectQueueXTPTransport.cls"
::requires "json.cls"
