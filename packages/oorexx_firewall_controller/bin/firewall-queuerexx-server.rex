/* Gateway-side QueueRexx qualification server for firewall.control/0.1.
 * Production should bind FirewallQueueRexxBinding to the resident peer mesh.
 */
parse arg root localNode localManager bindHost localPort peerNode peerManager peerHost peerPort principal keyId keyHex allowedPeerIp clientId helperPath protectedCsv ledgerPath receiptPath maxRequests
if root="" | localNode="" | localManager="" | bindHost="" | localPort="" | peerNode="" | peerManager="" | peerHost="" | peerPort="" | principal="" | keyId="" | keyHex="" | allowedPeerIp="" | clientId="" | helperPath="" | protectedCsv="" then do
  say "usage: server ROOT LOCAL_NODE LOCAL_MANAGER BIND_HOST LOCAL_PORT PEER_NODE PEER_MANAGER PEER_HOST PEER_PORT PRINCIPAL KEY_ID KEY_HEX ALLOWED_PEER_IP CLIENT_ID HELPER PROTECTED_CSV [LEDGER] [RECEIPTS] [MAX_REQUESTS]"
  exit 2
end
if maxRequests="" then maxRequests=0
if \datatype(localPort,"W") then exit 3
if \datatype(peerPort,"W") then exit 3
if \datatype(maxRequests,"W") then exit 3

codec=.QueueGraphPayloadCodec~new
manager=.ObjectQueueManager~new(root||"/fabric",codec,"queue-admin")
transport=.QueueSocketClientTransport~new("queue-admin",codec)
channels=.QueueChannelFabric~new(localManager,manager,transport,"queue-admin")
listener=.QueueSocketListener~new(localManager,bindHost,localPort,channels,codec)
mesh=.QueueRexxPeerMeshRuntime~new(localNode,root,localManager,manager,channels,transport,listener,"queue-admin",.nil)
b=mesh~bindSocketPeer(peerNode,peerManager,peerHost,peerPort,principal,keyId,keyHex,.array~of(allowedPeerIp),.array~new,10000)
if \b~ok then do
  say "PEER_BIND_FAIL" b~code b~detail
  exit 6
end

protected=.FirewallProtectedSources~new
protectWords=translate(protectedCsv," ",",")
do i=1 to words(protectWords)
  protected~protect(word(protectWords,i))
end
access=.FirewallPeerAccessPolicy~new
access~allow(peerNode)
provider=.FirewallNftablesProvider~new(helperPath)
ledger=.FirewallReplayLedger~new(ledgerPath)
receipts=.FirewallReceiptStore~new(receiptPath)
service=.FirewallControlService~new(localNode,provider,protected,access,ledger,receipts)
ready=service~start
if \ready~ok then do
  say "FIREWALL_PROVIDER_FAIL" ready~code ready~detail
  exit 7
end
sb=.FirewallQueueRexxBinding~bindServer(mesh,peerNode,clientId,service)
if sb==.nil then exit 8
if \sb~ok then do
  say "SERVICE_BIND_FAIL" sb~code sb~detail
  exit 8
end
if \mesh~startListener then do
  say "LISTENER_FAIL" listener~lastError
  exit 9
end
say "READY firewall.control/0.1 node="localNode "port="listener~port "peer="peerNode
count=0
signal on halt name stopping
do forever
  tr=mesh~serveTransportOne
  if tr==.nil then iterate
  if \tr~ok then do
    say "TRANSPORT_FAIL" tr~code tr~detail
    iterate
  end
  rr=sb~value~processOne
  if rr==.nil then iterate
  if \rr~ok then do
    say "SERVICE_FAIL" rr~code rr~detail
    iterate
  end
  count+=1
  say "SERVED" count .FirewallControlCodec~value(rr~value,"operation","") .FirewallControlCodec~value(rr~value,"code","")
  if maxRequests>0 then do
    if count>=maxRequests then leave
  end
end
stopping:
say "HALT rc="rc "sigl="sigl "condition="condition("C") "description="condition("D")
signal off halt
ignore=listener~stop
say "STOPPED requests="count
exit 0

::requires "FirewallControl.cls"
::requires "QueueRexxPeerMesh.cls"
