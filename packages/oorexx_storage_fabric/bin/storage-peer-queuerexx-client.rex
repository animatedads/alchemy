/* Materialise an exact StorageRef from a QueueRexx peer and independently
 * verify SHA-256 before reporting success. */
parse arg root localNode localManager bindHost localPort peerNode peerManager peerHost peerPort principal keyId keyHex allowedPeerIp clientId objectId digest targetPath chunkBytes
if root="" | localNode="" | localManager="" | bindHost="" | localPort="" | peerNode="" | peerManager="" | peerHost="" | peerPort="" | principal="" | keyId="" | keyHex="" | allowedPeerIp="" | clientId="" | objectId="" | digest="" | targetPath="" then do
  say "usage: client ROOT LOCAL_NODE LOCAL_MANAGER BIND_HOST LOCAL_PORT PEER_NODE PEER_MANAGER PEER_HOST PEER_PORT PRINCIPAL KEY_ID KEY_HEX ALLOWED_PEER_IP CLIENT_ID OBJECT_ID DIGEST TARGET_PATH [CHUNK_BYTES]"
  exit 2
end
if chunkBytes="" then chunkBytes=65536
codec=.QueueGraphPayloadCodec~new
manager=.ObjectQueueManager~new(root||"/fabric",codec,"queue-admin")
transport=.QueueSocketClientTransport~new("queue-admin",codec)
channels=.QueueChannelFabric~new(localManager,manager,transport,"queue-admin")
listener=.QueueSocketListener~new(localManager,bindHost,localPort,channels,codec)
mesh=.QueueRexxPeerMeshRuntime~new(localNode,root,localManager,manager,channels,transport,listener,"queue-admin",.nil)
b=mesh~bindSocketPeer(peerNode,peerManager,peerHost,peerPort,principal,keyId,keyHex,.array~of(allowedPeerIp),.array~new,10000)
if \b~ok then do; say "PEER_BIND_FAIL" b~code b~detail; exit 6; end
cb=.StoragePeerQueueRexxBinding~bindClient(mesh,peerNode,clientId,"storage-client","STORAGE.PEER.REQUEST",10000)
if cb==.nil | \cb~ok then do; if cb<>.nil then say "SERVICE_BIND_FAIL" cb~code cb~detail; exit 7; end
client=.StoragePeerClient~new(localNode,cb~value)
ref=.StorageRef~new(objectId,digest)
h=client~hello(peerNode)
if h==.nil | .StoragePeerCodec~value(h,"status","")<>"OK" then do; say "HELLO_FAIL"; exit 8; end
have=client~have(peerNode,ref)
if have==.nil | .StoragePeerCodec~value(have,"status","")<>"OK" then do; say "HAVE_FAIL"; exit 9; end
say "HAVE" have["payload"]["disposition"]
if have["payload"]["disposition"]<>.StoragePeerDisposition~AVAILABLE then exit 10
call SysFileDelete targetPath
mr=.StoragePeerMaterialiser~new(chunkBytes)~materialise(client,peerNode,ref,targetPath)
if \mr~ok then do; say "MATERIALISE_FAIL" mr~code mr~digest mr~bytes; exit 11; end
say "PASS storage peer materialise node="peerNode "object="objectId "digest="mr~digest "bytes="mr~bytes "path="targetPath
ignore=listener~stop
exit 0


::requires "StoragePeer.cls"
::requires "QueueRexxPeerMesh.cls"
