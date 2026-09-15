bridge=value("QF_CRYPTO_FOREIGN_BRIDGE",,"ENVIRONMENT")
if bridge<>"" then ignore=.CryptoForeignRuntimeInstaller~install(bridge)
parse arg root clientPortFile serverPortFile resultFile keyHex
if root="" | clientPortFile="" | serverPortFile="" | keyHex="" then exit 90
codec=.QueueGraphPayloadCodec~new
manager=.ObjectQueueManager~new(root||"/fabric",codec,"A-admin")
transport=.QueueSocketClientTransport~new("A-admin",codec)
fabric=.QueueChannelFabric~new("NODE-A",manager,transport,"A-admin")
listener=.QueueSocketListener~new("NODE-A","127.0.0.1",0,fabric,codec)
runtime=.QueueRexxPeerMeshRuntime~new("A",root,"NODE-A",manager,fabric,transport,listener,"A-admin",.TestDigest~new)
/* The reply listener must already trust B before it can bind/listen.  The
   remote endpoint port is not known yet, so install only the inbound trust
   here; bindSocketPeer() below adds the outbound endpoint once B publishes it. */
ignore=listener~trustPeer("NODE-B","mesh-ab","k1",keyHex,.array~of("127.0.0.1"))
if \runtime~startListener then do; say listener~lastError; exit 91; end
call lineout clientPortFile,listener~port
call lineout clientPortFile
serverPort=""
do i=1 to 400
  if stream(serverPortFile,"c","query exists")<>"" then do
    f=.stream~new(serverPortFile); f~open("READ"); serverPort=f~linein~strip; f~close
    if serverPort<>"" then leave
  end
  call SysSleep 0.025
end
if serverPort="" then exit 92
ops=.array~of(.QueueRexxPeerOperation~AUTHORIZE,.QueueRexxPeerOperation~HEALTH)
b=runtime~bindSocketPeer("B","NODE-B","127.0.0.1",serverPort,"mesh-ab","k1",keyHex,.array~of("127.0.0.1"),ops,10000)
if \b~ok then do; say b~code b~detail; exit 93; end
subject=.directory~new; subject["qid"]="SOCKET-JOB-1"
rr=runtime~client~request("B",.QueueRexxPeerOperation~AUTHORIZE,subject,.directory~new,0,0,"socket-test")
if \rr~ok then do; say rr~code rr~detail; exit 94; end
response=rr~value
if response["decision"]<>"APPROVE" | response["code"]<>"B-AUTHORISED" | response["source_node"]<>"B" then exit 95
if response["request_digest"]==.nil | response["request_digest"]="" then exit 96
call lineout resultFile,"decision="||response["decision"]||";source="||response["source_node"]||";auth="||listener~authenticatedCount||";accepted="||listener~acceptedCount
call lineout resultFile
ignore=listener~stop
exit 0
::class TestDigest public
::method digest
  use strict arg text
  return c2x(text~string)
::requires "QueueRexxPeerMesh.cls"
::requires "CryptoForeignRuntimeProvider.cls"
