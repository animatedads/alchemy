bridge=value("QF_CRYPTO_FOREIGN_BRIDGE",,"ENVIRONMENT")
if bridge<>"" then ignore=.CryptoForeignRuntimeInstaller~install(bridge)
parse arg root clientPort serverPortFile resultFile keyHex
if root="" | clientPort="" | serverPortFile="" | keyHex="" then exit 80
codec=.QueueGraphPayloadCodec~new
manager=.ObjectQueueManager~new(root||"/fabric",codec,"B-admin")
transport=.QueueSocketClientTransport~new("B-admin",codec)
fabric=.QueueChannelFabric~new("NODE-B",manager,transport,"B-admin")
listener=.QueueSocketListener~new("NODE-B","127.0.0.1",0,fabric,codec)
runtime=.QueueRexxPeerMeshRuntime~new("B",root,"NODE-B",manager,fabric,transport,listener,"B-admin",.TestDigest~new)
ops=.array~of(.QueueRexxPeerOperation~AUTHORIZE,.QueueRexxPeerOperation~HEALTH)
b=runtime~bindSocketPeer("A","NODE-A","127.0.0.1",clientPort,"mesh-ab","k1",keyHex,.array~of("127.0.0.1"),ops,10000)
if \b~ok then do; say b~code b~detail; exit 81; end
ignore=runtime~service~registerHandler(.QueueRexxPeerOperation~AUTHORIZE,.QueueRexxPeerStaticDecisionHandler~new("APPROVE","B-AUTHORISED","peer B approved"))
if \runtime~startListener then do; say listener~lastError; exit 82; end
call lineout serverPortFile,listener~port
call lineout serverPortFile
t=runtime~serveTransportOne
if \t~ok then do; say "transport" t~code t~detail; exit 83; end
s=runtime~servePeer("A",1)
if \s~ok then do; say "service" s~code s~detail; exit 84; end
call lineout resultFile,"auth="||listener~authenticatedCount||";accepted="||listener~acceptedCount
call lineout resultFile
ignore=listener~stop
exit 0
::class TestDigest public
::method digest
  use strict arg text
  return c2x(text~string)
::requires "QueueRexxPeerMesh.cls"
::requires "CryptoForeignRuntimeProvider.cls"
