/* RexxOS/HTTPS-side QueueRexx qualification client.
 * Reports exactly one hostile IPv4 source.  It has no firewall authority.
 */
parse arg root localNode localManager bindHost localPort peerNode peerManager peerHost peerPort principal keyId keyHex allowedPeerIp clientId sourceIp reason evidenceId
if root="" | localNode="" | localManager="" | bindHost="" | localPort="" | peerNode="" | peerManager="" | peerHost="" | peerPort="" | principal="" | keyId="" | keyHex="" | allowedPeerIp="" | clientId="" | sourceIp="" then do
  say "usage: client ROOT LOCAL_NODE LOCAL_MANAGER BIND_HOST LOCAL_PORT PEER_NODE PEER_MANAGER PEER_HOST PEER_PORT PRINCIPAL KEY_ID KEY_HEX ALLOWED_PEER_IP CLIENT_ID SOURCE_IP [REASON] [EVIDENCE_ID]"
  exit 2
end
if reason="" then reason="HOSTILE_HTTPS_SCAN"
if \datatype(localPort,"W") then exit 3
if \datatype(peerPort,"W") then exit 3
if .FirewallControlCodec~normaliseIpv4(sourceIp)="" then do
  say "SOURCE_IP_INVALID" sourceIp
  exit 4
end

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
cb=.FirewallQueueRexxBinding~bindClient(mesh,peerNode,clientId,"firewall-client",.FirewallControlContract~REQUEST_QUEUE,10000)
if cb==.nil then exit 7
if \cb~ok then do
  say "SERVICE_BIND_FAIL" cb~code cb~detail
  exit 7
end
client=.FirewallQueueRexxClient~new(localNode,cb~value)
res=client~blockHostileSource(peerNode,sourceIp,reason,evidenceId)
if res==.nil then do
  say "NO_RESPONSE"
  exit 8
end
say "RESULT status="res["status"] "code="res["code"] "detail="res["detail"]
if res["payload"]<>.nil then do
  p=res["payload"]
  if p["source_ip"]<>.nil then say "BLOCK exact="p["source_ip"] "minutes="p["exact_block_minutes"]
  if p["network24"]<>.nil then say "BLOCK network="p["network24"] "minutes="p["net24_block_minutes"]
end
ignore=listener~stop
if res["status"]="OK" then exit 0
exit 9

::requires "FirewallControl.cls"
::requires "QueueRexxPeerMesh.cls"
