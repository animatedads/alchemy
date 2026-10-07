bridge = value("QF_CRYPTO_FOREIGN_BRIDGE", , "ENVIRONMENT")
if bridge \= "" then ignore = .CryptoForeignRuntimeInstaller~install(bridge)

parse arg storeRoot portFile statusFile keyHex
codec = .QueueGraphPayloadCodec~new
ignore = .QueueDistributedTopicSupport~registerTypes(codec)
manager = .ObjectQueueManager~new(storeRoot, codec, "admin")
do name over .array~of("XMIT.A", "DT.CTRL", "DT.PUB", "DT.DIST", "B.SUB")
  if manager~queue(name) == .nil then do
    createResult = manager~createQueue(name, "PERMANENT", "TOPIC", 50, "admin")
    if \createResult~ok then exit 21
  end
end
ignore = manager~grant("DT.PUB", "wire-b", .QueueAccess~PUT, "admin")
ignore = manager~grant("DT.CTRL", "wire-b", .QueueAccess~PUT, "admin")
channels = .QueueChannelFabric~new("QM.B", manager, .QueueInProcessTransport~new, "admin")
if channels~receiverChannel("A.TO.B") == .nil then do
  ignore = channels~defineReceiverChannel("A.TO.B", "QM.A", "wire-b", "PERMANENT", "admin")
end
ignore = channels~startReceiverChannel("A.TO.B", "admin")
if channels~senderChannel("B.TO.A") == .nil then do
  ignore = channels~defineSenderChannel("B.TO.A", "XMIT.A", "QM.A", "B.TO.A", "admin", "wire-a", 3, "PERMANENT", "admin")
end
if channels~remoteQueue("A.CTRL") == .nil then ignore = channels~defineRemoteQueue("A.CTRL", "DT.CTRL", "QM.A", "XMIT.A", "B.TO.A", "TOPIC", "PERMANENT", "admin", "admin")
if channels~remoteQueue("A.PUB") == .nil then ignore = channels~defineRemoteQueue("A.PUB", "DT.PUB", "QM.A", "XMIT.A", "B.TO.A", "TOPIC", "PERMANENT", "admin", "admin")
topics = .QueueTopicFabric~new(manager, "admin")
if topics~topic("ORDERS") == .nil then ignore = topics~defineTopic("ORDERS", "orders", "PERMANENT", "TOPIC", "admin")
if topics~subscription("B.SUBSCRIPTION") == .nil then ignore = topics~subscribe("B.SUBSCRIPTION", "ORDERS", "uk/#", "B.SUB", "PERMANENT", "admin")
remote = .QueueDistributedTopicFabric~new("QM.B", manager, topics, channels, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
if remote~peer("QM.A", "ORDERS") == .nil then ignore = remote~definePeer("QM.A", "ORDERS", "ORDERS", "A.CTRL", "A.PUB", "PERMANENT", .false, "admin")
listener = .QueueSocketListener~new("QM.B", "127.0.0.1", 0, channels, manager~payloadCodec)
ignore = listener~trustPeer("QM.A", "wire-b", "k1", keyHex, .array~of("127.0.0.1"))
if \listener~start then exit 22
call lineout portFile, listener~port
call lineout portFile
serveResult = listener~serveOne
ignore = listener~stop
if \serveResult~ok then exit 23
pumpResult = remote~pumpPublicationIngress(0, "admin")
if \pumpResult~ok then do
  say pumpResult~code pumpResult~detail
  exit 24
end
package = manager~browse("B.SUB", "admin")~value
call lineout statusFile, "depth=" || manager~depth("B.SUB", "admin")~value["ready"] || ";receipts=" || remote~receipts~items || ";order=" || package~payload["order"] || ";step2=" || package~payload["steps"][2] || ";path=" || package~headers["oqf.remote.path"]
call lineout statusFile
exit 0
::requires "ObjectQueueSocketTransport.cls"
::requires "ObjectQueueDistributedTopics.cls"

::requires "CryptoForeignRuntimeProvider.cls"
