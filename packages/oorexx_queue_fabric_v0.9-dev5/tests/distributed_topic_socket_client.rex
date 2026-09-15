bridge = value("QF_CRYPTO_FOREIGN_BRIDGE", , "ENVIRONMENT")
if bridge \= "" then ignore = .CryptoForeignRuntimeInstaller~install(bridge)

parse arg port keyHex
codec = .QueueGraphPayloadCodec~new
ignore = .QueueDistributedTopicSupport~registerTypes(codec)
manager = .ObjectQueueManager~new("", codec, "admin")
do name over .array~of("XMIT.B", "DT.CTRL", "DT.PUB", "DT.DIST")
  createResult = manager~createQueue(name, "TEMPORARY", "TOPIC", 50, "admin")
  if \createResult~ok then exit 31
end
transport = .QueueSocketClientTransport~new("admin", manager~payloadCodec)
ignore = transport~registerEndpoint("QM.B", "127.0.0.1", port, "wire-b", "k1", keyHex)
channels = .QueueChannelFabric~new("QM.A", manager, transport, "admin")
ignore = channels~defineSenderChannel("A.TO.B", "XMIT.B", "QM.B", "A.TO.B", "admin", "wire-b", 3, "TEMPORARY", "admin")
ignore = channels~startSenderChannel("A.TO.B", "admin")
ignore = channels~defineRemoteQueue("B.CTRL", "DT.CTRL", "QM.B", "XMIT.B", "A.TO.B", "TOPIC", "TEMPORARY", "admin", "admin")
ignore = channels~defineRemoteQueue("B.PUB", "DT.PUB", "QM.B", "XMIT.B", "A.TO.B", "TOPIC", "TEMPORARY", "admin", "admin")
topics = .QueueTopicFabric~new(manager, "admin")
ignore = topics~defineTopic("ORDERS", "orders", "TEMPORARY", "TOPIC", "admin")
ignore = topics~grantTopicAccess("ORDERS", "producer", .QueueTopicAccess~PUBLISH, "admin")
remote = .QueueDistributedTopicFabric~new("QM.A", manager, topics, channels, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
ignore = remote~definePeer("QM.B", "ORDERS", "ORDERS", "B.CTRL", "B.PUB", "TEMPORARY", .false, "admin")
advertisement = .array~of("uk/#", "QM.B", .array~of("QM.B"))
snapshot = .QueueTopicInterestSnapshot~new("socket-interest", "QM.B", "QM.A", "ORDERS", "ORDERS", 1, .array~of(advertisement))
if \manager~put("DT.CTRL", snapshot, .nil, "admin")~ok then exit 32
if \remote~pumpControlIngress(0, "admin")~ok then exit 33
payload = .table~new
payload["order"] = 808
payload["steps"] = .array~of("route", "deliver")
options = .table~new
options["subtopic"] = "uk/socket"
options["persistent"] = .true
options["securityDomain"] = "TOPIC"
publishResult = topics~publish("ORDERS", payload, options, "producer")
if \publishResult~ok then exit 34
if publishResult~value~remoteManagerCount \= 1 then exit 35
if \remote~pumpDistribution(0, "admin")~ok then exit 36
pumpResult = channels~pump("A.TO.B", 0, "admin")
if \pumpResult~ok then do
  say pumpResult~code pumpResult~detail
  exit 37
end
exit 0
::requires "ObjectQueueSocketTransport.cls"
::requires "ObjectQueueDistributedTopics.cls"

::requires "CryptoForeignRuntimeProvider.cls"
