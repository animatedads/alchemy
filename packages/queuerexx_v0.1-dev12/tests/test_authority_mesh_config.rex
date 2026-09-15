root="/mnt/data/queuerexx-dev12-authority-mesh-config"
address system "rm -rf "||root
call SysMkDir root

registry=.NodeCapabilityRegistry~new
if \registry~advertiseCapability(.NodeCapabilityStatement~new("NODE-CONFIG",1)) then call fail "capability"
if \registry~observeCapacity(.NodeCapacityObservation~new("NODE-CONFIG",1,1,1000,5000,4096,4096,4,1000000,0,0)) then call fail "capacity"

/* General QueueRexx mesh configuration owns endpoint, key, principal and
 * control-plane permissions.  Nothing in the JNA service config repeats it. */
meshDoc=.directory~new; meshDoc["schema"]=.QueueRexxPeerMeshConfig~SCHEMA
peers=.array~new; peer=.directory~new
peer["node_id"]="FD-A"; peer["manager"]="FD-MANAGER"
peer["host"]="127.0.0.1"; peer["port"]=9
peer["transport_principal"]="wire-fd"; peer["key_id"]="k-fd"; peer["key_hex"]=copies("66",64)
peer["allowed_source_ips"]=.array~of("127.0.0.1")
peer["operations"]=.array~of(.QueueRexxPeerOperation~HEALTH,.QueueRexxPeerOperation~JOB_CHECK)
peer["timeout_ms"]=2500; peers~append(peer); meshDoc["peers"]=peers
meshPath=root||"/peer-mesh.json"; .QueueSerialization~toJsonFile(meshDoc,meshPath)

svcDoc=.directory~new; svcDoc["schema"]=.QueueRexxAuthorityPeerClientConfig~SCHEMA
clients=.array~new; c=.directory~new
c["client_id"]="FD-CLIENT"; c["peer_node_id"]="FD-A"; c["client_reply_queue"]="FD.JNA.REPLY"
c["operations"]=.array~of("PLAN","ALLOCATE","CHECK","RENEW","RELEASE"); c["owner_node_id"]="FD-OWNER"
clients~append(c); svcDoc["clients"]=clients
svcPath=root||"/authority-services.json"; .QueueSerialization~toJsonFile(svcDoc,svcPath)

stack=.QueueRexxAuthorityStack~new(root||"/authority",registry,.nil,.nil,"QUEUEREXX","queue","QRX-CONFIG","AUTH-CONFIG","127.0.0.1",0,"auth-admin",1000,.TestDigest~new)
server=.QueueRexxAuthorityServer~new(stack,.QueueRexxAuthorityPeerClientConfig~new(svcPath),.QueueRexxPeerMeshConfig~new(meshPath),"AUTH-NODE")
started=server~start
if \started~ok then call fail "server start "||started~code||" "||started~detail

mesh=stack~peerMesh
if mesh==.nil then call fail "mesh absent"
pb=mesh~trustPolicy~binding("FD-A")
if pb==.nil then call fail "peer binding absent"
if pb~peerManager<>"FD-MANAGER" | pb~transportPrincipal<>"wire-fd" then call fail "peer connectivity binding"
if \pb~allows(.QueueRexxPeerOperation~HEALTH) | pb~allows(.QueueRexxPeerOperation~AUTHORIZE) then call fail "peer control operations"

binding=stack~clientBindings["FD-CLIENT"]
if binding==.nil then call fail "JNA service binding absent"
if binding~peerNodeId<>"FD-A" | binding~ownerNodeId<>"FD-OWNER" | binding~replyAlias="" then call fail "JNA semantic binding"
if stack~channels~remoteQueue(binding~replyAlias)==.nil then call fail "JNA remote reply alias absent"
if stack~queueManager~queue(stack~requestQueue)~securityDomain<>"JNA" then call fail "JNA request domain"

placement=.JobPlacementRequest~new("CFG-JOB",.JobNodeRequirement~new,"FD-OWNER",0,0)
other=.JobPlacementRequest~new("CFG-JOB-OTHER",.JobNodeRequirement~new,"OTHER-OWNER",0,0)
if \stack~accessPolicy~authorised("FD-CLIENT","ALLOCATE",placement) then call fail "network1 ACL did not permit bound owner"
if stack~accessPolicy~authorised("FD-CLIENT","ALLOCATE",other) then call fail "network1 ACL accepted wrong owner"
if stack~accessPolicy~authorised("FD-CLIENT","BOGUS",placement) then call fail "network1 ACL accepted ungranted operation"
ignore=server~stop

/* Missing local node identity fails before peer configuration/listen. */
stackMissing=.QueueRexxAuthorityStack~new(root||"/missing-node",registry,.nil,.nil,"QUEUEREXX","queue","QRX-CONFIG","AUTH-MISSING","127.0.0.1",0,"auth-admin",1000,.TestDigest~new)
missing=.QueueRexxAuthorityServer~new(stackMissing,.QueueRexxAuthorityPeerClientConfig~new(svcPath),.QueueRexxPeerMeshConfig~new(meshPath),"")~start
if missing~ok | missing~code<>"PEER_MESH_LOCAL_NODE_REQUIRED" then call fail "missing local node did not fail closed"

/* Malformed peer configuration fails before semantic service bindings. */
badPeer=.directory~new; badPeer["schema"]=.QueueRexxPeerMeshConfig~SCHEMA; badRows=.array~new
badRow=.directory~new; badRow["node_id"]="FD-A"; badRows~append(badRow); badPeer["peers"]=badRows
badPeerPath=root||"/bad-peer.json"; .QueueSerialization~toJsonFile(badPeer,badPeerPath)
stackBadPeer=.QueueRexxAuthorityStack~new(root||"/bad-peer-root",registry,.nil,.nil,"QUEUEREXX","queue","QRX-CONFIG","AUTH-BAD-PEER","127.0.0.1",0,"auth-admin",1000,.TestDigest~new)
badPeerServer=.QueueRexxAuthorityServer~new(stackBadPeer,.QueueRexxAuthorityPeerClientConfig~new(svcPath),.QueueRexxPeerMeshConfig~new(badPeerPath),"AUTH-NODE")
r=badPeerServer~start
if r~ok | r~code<>"PEER_MESH_CONFIG_INVALID" then call fail "bad peer config not rejected"
if badPeerServer~running then call fail "bad peer config started listener"
if stackBadPeer~clientBindings~items<>0 then call fail "service ACL applied before bad peer config rejected"

/* Malformed semantic binding is rejected after mesh construction but still
 * before listener startup. */
badSvc=.directory~new; badSvc["schema"]=.QueueRexxAuthorityPeerClientConfig~SCHEMA; badClients=.array~new
badClient=.directory~new; badClient["client_id"]="FD-BROKEN"; badClient["peer_node_id"]="FD-A"; badClients~append(badClient); badSvc["clients"]=badClients
badSvcPath=root||"/bad-service.json"; .QueueSerialization~toJsonFile(badSvc,badSvcPath)
stackBadSvc=.QueueRexxAuthorityStack~new(root||"/bad-service-root",registry,.nil,.nil,"QUEUEREXX","queue","QRX-CONFIG","AUTH-BAD-SVC","127.0.0.1",0,"auth-admin",1000,.TestDigest~new)
badSvcServer=.QueueRexxAuthorityServer~new(stackBadSvc,.QueueRexxAuthorityPeerClientConfig~new(badSvcPath),.QueueRexxPeerMeshConfig~new(meshPath),"AUTH-NODE")
r=badSvcServer~start
if r~ok | r~code<>"AUTHORITY_PEER_CLIENT_CONFIG_INVALID" then call fail "bad service config not rejected"
if badSvcServer~running then call fail "bad service config started listener"
if stackBadSvc~peerMesh==.nil | stackBadSvc~peerMesh~trustPolicy~binding("FD-A")==.nil then call fail "peer config was not applied first"

say "PASS QueueRexx dev12 configuration split: peer mesh owns node endpoint/trust/key config, exact network1 service config owns only client->peer operation/owner/reply bindings, and both fail closed before listen"
exit 0

fail: procedure
  parse arg message
  say "FAIL" message
  exit 1

::class TestDigest public
::method digest
  use strict arg text
  return "D:"||c2x(text~string)

::requires "QueueRexxAuthority.cls"
