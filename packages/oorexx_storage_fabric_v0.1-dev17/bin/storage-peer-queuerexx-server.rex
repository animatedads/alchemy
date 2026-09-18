/* Serve one immutable Storage object over an already authenticated QueueRexx
 * queue.transport/2 relationship constructed here from explicit endpoint
 * parameters.  Intended for two-node qualification, not topology authority. */
parse arg root localNode localManager bindHost localPort peerNode peerManager peerHost peerPort principal keyId keyHex allowedPeerIp clientId sourcePath objectId digest maxRequests
if root="" | localNode="" | localManager="" | bindHost="" | localPort="" | peerNode="" | peerManager="" | peerHost="" | peerPort="" | principal="" | keyId="" | keyHex="" | allowedPeerIp="" | clientId="" | sourcePath="" | objectId="" then do
  say "usage: server ROOT LOCAL_NODE LOCAL_MANAGER BIND_HOST LOCAL_PORT PEER_NODE PEER_MANAGER PEER_HOST PEER_PORT PRINCIPAL KEY_ID KEY_HEX ALLOWED_PEER_IP CLIENT_ID SOURCE_PATH OBJECT_ID [DIGEST] [MAX_REQUESTS]"
  exit 2
end
if maxRequests="" then maxRequests=0
if \datatype(localPort,"W") | \datatype(peerPort,"W") | \datatype(maxRequests,"W") then exit 3
if digest="" then do
  raw=.StoragePosixSha256Verifier~new~digestFile(sourcePath)
  if raw="" then do; say "cannot SHA-256 source"; exit 4; end
  digest="sha256:"||raw
end
size=stream(sourcePath,"c","query size")
if \datatype(size,"N") then do; say "cannot stat source"; exit 5; end
codec=.QueueGraphPayloadCodec~new
manager=.ObjectQueueManager~new(root||"/fabric",codec,"queue-admin")
transport=.QueueSocketClientTransport~new("queue-admin",codec)
channels=.QueueChannelFabric~new(localManager,manager,transport,"queue-admin")
listener=.QueueSocketListener~new(localManager,bindHost,localPort,channels,codec)
mesh=.QueueRexxPeerMeshRuntime~new(localNode,root,localManager,manager,channels,transport,listener,"queue-admin",.nil)
b=mesh~bindSocketPeer(peerNode,peerManager,peerHost,peerPort,principal,keyId,keyHex,.array~of(allowedPeerIp),.array~new,10000)
if \b~ok then do; say "PEER_BIND_FAIL" b~code b~detail; exit 6; end
registry=.StoragePeerExportRegistry~new
ref=.StorageRef~new(objectId,digest)
registry~publish(.StoragePeerExport~new(ref,size+0,.StoragePeerLocalFileSourceFactory~new(sourcePath)))
service=.StoragePeerService~new(localNode,registry,262144)
sb=.StoragePeerQueueRexxBinding~bindServer(mesh,peerNode,clientId,service)
if sb==.nil | \sb~ok then do; if sb<>.nil then say "SERVICE_BIND_FAIL" sb~code sb~detail; exit 7; end
if \mesh~startListener then do; say "LISTENER_FAIL" listener~lastError; exit 8; end
say "READY node="localNode "port="listener~port "object="objectId "digest="digest "size="size
count=0
signal on halt name stopping
do forever
  tr=mesh~serveTransportOne
  if tr==.nil | \tr~ok then do
    if tr<>.nil then say "TRANSPORT_FAIL" tr~code tr~detail
    iterate
  end
  rr=sb~value~processOne
  if rr==.nil | \rr~ok then do
    if rr<>.nil then say "SERVICE_FAIL" rr~code rr~detail
    iterate
  end
  count+=1
  say "SERVED" count .StoragePeerCodec~value(rr~value,"operation","") .StoragePeerCodec~value(rr~value,"request_id","")
  if maxRequests>0 & count>=maxRequests then leave
end
stopping:
signal off halt
ignore=listener~stop
say "STOPPED requests="count
exit 0


::requires "StoragePeer.cls"
::requires "QueueRexxPeerMesh.cls"