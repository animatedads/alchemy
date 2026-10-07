/* Object Queue Fabric v0.8: aggregated remote topic interest and one-copy broker delivery. */
transport = .QueueInProcessTransport~new
managerA = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
managerB = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call makeQueues managerA, .array~of("XMIT.B", "DT.CTRL", "DT.PUB", "DT.DIST")
call makeQueues managerB, .array~of("XMIT.A", "DT.CTRL", "DT.PUB", "DT.DIST", "B.ORDERS")
ignore = managerA~grant("DT.CTRL", "wire-a", .QueueAccess~PUT, "admin")
ignore = managerA~grant("DT.PUB", "wire-a", .QueueAccess~PUT, "admin")
ignore = managerB~grant("DT.CTRL", "wire-b", .QueueAccess~PUT, "admin")
ignore = managerB~grant("DT.PUB", "wire-b", .QueueAccess~PUT, "admin")

channelsA = .QueueChannelFabric~new("QM.A", managerA, transport, "admin")
channelsB = .QueueChannelFabric~new("QM.B", managerB, transport, "admin")
ignore = transport~registerEndpoint("QM.A", channelsA)
ignore = transport~registerEndpoint("QM.B", channelsB)
call link channelsA, "A.TO.B", "XMIT.B", "QM.B", "wire-b"
call receiver channelsB, "A.TO.B", "QM.A", "wire-b"
call link channelsB, "B.TO.A", "XMIT.A", "QM.A", "wire-a"
call receiver channelsA, "B.TO.A", "QM.B", "wire-a"
call alias channelsA, "B.CTRL", "DT.CTRL", "QM.B", "XMIT.B", "A.TO.B"
call alias channelsA, "B.PUB", "DT.PUB", "QM.B", "XMIT.B", "A.TO.B"
call alias channelsB, "A.CTRL", "DT.CTRL", "QM.A", "XMIT.A", "B.TO.A"
call alias channelsB, "A.PUB", "DT.PUB", "QM.A", "XMIT.A", "B.TO.A"

topicsA = .QueueTopicFabric~new(managerA, "admin")
topicsB = .QueueTopicFabric~new(managerB, "admin")
ignore = topicsA~defineTopic("ORDERS", "orders", "TEMPORARY", "TOPIC", "admin")
ignore = topicsB~defineTopic("ORDERS", "orders", "TEMPORARY", "TOPIC", "admin")
ignore = topicsA~grantTopicAccess("ORDERS", "producer", .QueueTopicAccess~PUBLISH, "admin")
ignore = topicsB~subscribe("B.UK", "ORDERS", "uk/#", "B.ORDERS", "TEMPORARY", "admin")

distributedA = .QueueDistributedTopicFabric~new("QM.A", managerA, topicsA, channelsA, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
distributedB = .QueueDistributedTopicFabric~new("QM.B", managerB, topicsB, channelsB, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
ignore = distributedA~definePeer("QM.B", "ORDERS", "ORDERS", "B.CTRL", "B.PUB", "TEMPORARY", .false, "admin")
ignore = distributedB~definePeer("QM.A", "ORDERS", "ORDERS", "A.CTRL", "A.PUB", "TEMPORARY", .false, "admin")

/* B advertises one aggregated interest to A. */
ignore = distributedB~syncPeer("QM.A", "ORDERS", "admin")
ignore = channelsB~pump("B.TO.A", 0, "admin")
ignore = distributedA~pumpControlIngress(0, "admin")

payload = .table~new
payload["order"] = 808
payload["steps"] = .array~of("render", "dispatch")
options = .table~new
options["subtopic"] = "uk/new"
options["securityDomain"] = "TOPIC"
publishResult = topicsA~publish("ORDERS", payload, options, "producer")
say "remote managers:" publishResult~value~remoteManagerCount
say "distribution depth:" managerA~depth("DT.DIST", "admin")~value["ready"]

ignore = distributedA~pumpDistribution(0, "admin")
ignore = channelsA~pump("A.TO.B", 0, "admin")
ignore = distributedB~pumpPublicationIngress(0, "admin")
received = managerB~browse("B.ORDERS", "admin")~value
say "B depth:" managerB~depth("B.ORDERS", "admin")~value["ready"]
say "order:" received~payload["order"]
say "step 2:" received~payload["steps"][2]
say "broker path:" received~headers["oqf.remote.path"]
exit 0

makeQueues: procedure
  use arg manager, names
  do name over names
    ignore = manager~createQueue(name, "TEMPORARY", "TOPIC", 100, "admin")
  end
  return
link: procedure
  use arg fabric, channelName, xmitQueue, remoteManager, remotePrincipal
  ignore = fabric~defineSenderChannel(channelName, xmitQueue, remoteManager, channelName, "admin", remotePrincipal, 3, "TEMPORARY", "admin")
  ignore = fabric~startSenderChannel(channelName, "admin")
  return
receiver: procedure
  use arg fabric, channelName, sourceManager, inboundPrincipal
  ignore = fabric~defineReceiverChannel(channelName, sourceManager, inboundPrincipal, "TEMPORARY", "admin")
  ignore = fabric~startReceiverChannel(channelName, "admin")
  return
alias: procedure
  use arg fabric, aliasName, remoteQueue, remoteManager, xmitQueue, channelName
  ignore = fabric~defineRemoteQueue(aliasName, remoteQueue, remoteManager, xmitQueue, channelName, "TOPIC", "TEMPORARY", "admin", "admin")
  return

::requires "ObjectQueueDistributedTopics.cls"
