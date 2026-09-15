/* ObjectQueueFabric v0.8 multi-hop distributed topic interest acceptance. */
assertions = 0
transport = .QueueInProcessTransport~new
managerA = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
managerB = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
managerC = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")

call makeQueues managerA, .array~of("XMIT.B", "DT.CTRL", "DT.PUB", "DT.DIST")
call makeQueues managerB, .array~of("XMIT.A", "XMIT.C", "DT.CTRL", "DT.PUB", "DT.DIST")
call makeQueues managerC, .array~of("XMIT.B", "DT.CTRL", "DT.PUB", "DT.DIST", "C.ORDERS")
call assertOk managerA~grant("DT.CTRL", "wire-a", .QueueAccess~PUT, "admin"), "grant A ctrl"
call assertOk managerA~grant("DT.PUB", "wire-a", .QueueAccess~PUT, "admin"), "grant A pub"
call assertOk managerB~grant("DT.CTRL", "wire-b", .QueueAccess~PUT, "admin"), "grant B ctrl"
call assertOk managerB~grant("DT.PUB", "wire-b", .QueueAccess~PUT, "admin"), "grant B pub"
call assertOk managerC~grant("DT.CTRL", "wire-c", .QueueAccess~PUT, "admin"), "grant C ctrl"
call assertOk managerC~grant("DT.PUB", "wire-c", .QueueAccess~PUT, "admin"), "grant C pub"

channelsA = .QueueChannelFabric~new("QM.A", managerA, transport, "admin")
channelsB = .QueueChannelFabric~new("QM.B", managerB, transport, "admin")
channelsC = .QueueChannelFabric~new("QM.C", managerC, transport, "admin")
ignore = transport~registerEndpoint("QM.A", channelsA)
ignore = transport~registerEndpoint("QM.B", channelsB)
ignore = transport~registerEndpoint("QM.C", channelsC)

call link channelsA, managerA, "A.TO.B", "XMIT.B", "QM.B", "wire-b"
call receiver channelsB, "A.TO.B", "QM.A", "wire-b"
call link channelsB, managerB, "B.TO.A", "XMIT.A", "QM.A", "wire-a"
call receiver channelsA, "B.TO.A", "QM.B", "wire-a"
call link channelsB, managerB, "B.TO.C", "XMIT.C", "QM.C", "wire-c"
call receiver channelsC, "B.TO.C", "QM.B", "wire-c"
call link channelsC, managerC, "C.TO.B", "XMIT.B", "QM.B", "wire-b"
call receiver channelsB, "C.TO.B", "QM.C", "wire-b"

call remoteAlias channelsA, "B.CTRL", "DT.CTRL", "QM.B", "XMIT.B", "A.TO.B"
call remoteAlias channelsA, "B.PUB", "DT.PUB", "QM.B", "XMIT.B", "A.TO.B"
call remoteAlias channelsB, "A.CTRL", "DT.CTRL", "QM.A", "XMIT.A", "B.TO.A"
call remoteAlias channelsB, "A.PUB", "DT.PUB", "QM.A", "XMIT.A", "B.TO.A"
call remoteAlias channelsB, "C.CTRL", "DT.CTRL", "QM.C", "XMIT.C", "B.TO.C"
call remoteAlias channelsB, "C.PUB", "DT.PUB", "QM.C", "XMIT.C", "B.TO.C"
call remoteAlias channelsC, "B.CTRL", "DT.CTRL", "QM.B", "XMIT.B", "C.TO.B"
call remoteAlias channelsC, "B.PUB", "DT.PUB", "QM.B", "XMIT.B", "C.TO.B"

topicsA = .QueueTopicFabric~new(managerA, "admin")
topicsB = .QueueTopicFabric~new(managerB, "admin")
topicsC = .QueueTopicFabric~new(managerC, "admin")
call assertOk topicsA~defineTopic("ORDERS", "orders", "TEMPORARY", "TOPIC", "admin"), "topic A"
call assertOk topicsB~defineTopic("ORDERS", "orders", "TEMPORARY", "TOPIC", "admin"), "topic B"
call assertOk topicsC~defineTopic("ORDERS", "orders", "TEMPORARY", "TOPIC", "admin"), "topic C"
call assertOk topicsA~grantTopicAccess("ORDERS", "producer", .QueueTopicAccess~PUBLISH, "admin"), "grant producer"

remoteA = .QueueDistributedTopicFabric~new("QM.A", managerA, topicsA, channelsA, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
remoteB = .QueueDistributedTopicFabric~new("QM.B", managerB, topicsB, channelsB, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
remoteC = .QueueDistributedTopicFabric~new("QM.C", managerC, topicsC, channelsC, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
call assertOk remoteA~definePeer("QM.B", "ORDERS", "ORDERS", "B.CTRL", "B.PUB", "TEMPORARY", .false, "admin"), "A peer B"
call assertOk remoteB~definePeer("QM.A", "ORDERS", "ORDERS", "A.CTRL", "A.PUB", "TEMPORARY", .false, "admin"), "B peer A"
call assertOk remoteB~definePeer("QM.C", "ORDERS", "ORDERS", "C.CTRL", "C.PUB", "TEMPORARY", .false, "admin"), "B peer C"
call assertOk remoteC~definePeer("QM.B", "ORDERS", "ORDERS", "B.CTRL", "B.PUB", "TEMPORARY", .false, "admin"), "C peer B"

/* Only C has an application subscription. */
call assertOk topicsC~subscribe("C.SUB", "ORDERS", "eu/#", "C.ORDERS", "TEMPORARY", "admin"), "C downstream subscription"

/* C -> B advertises local interest. */
call assertOk remoteC~syncPeer("QM.B", "ORDERS", "admin"), "C queues interest to B"
call assertOk channelsC~pump("C.TO.B", 0, "admin"), "C sends interest to B"
call assertOk remoteB~pumpControlIngress(0, "admin"), "B applies C interest"
call assertEqual 1, remoteB~remoteInterests~items, "B stores C interest"

/* B aggregates C's interest and advertises it to A. */
call assertOk remoteB~syncPeer("QM.A", "ORDERS", "admin"), "B queues downstream interest to A"
call assertOk channelsB~pump("B.TO.A", 0, "admin"), "B sends downstream interest to A"
call assertOk remoteA~pumpControlIngress(0, "admin"), "A applies downstream interest"
call assertEqual 1, remoteA~remoteInterests~items, "A sees one interested peer B"
interestA = remoteA~remoteInterests[1]
call assertEqual "QM.C", interestA~advertisements[1][2], "A advertisement retains C as origin"
call assertEqual "QM.C>QM.B", pathText(interestA~advertisements[1][3]), "A advertisement carries C-to-B path"

/* A sends only one network publication to B. B has no local subscriber but
 * forwards once to C because the downstream advertisement matched. */
options = .table~new
options["subtopic"] = "eu/new"
options["securityDomain"] = "TOPIC"
published = topicsA~publish("ORDERS", "through-B", options, "producer")
call assertOk published, "A publishes for downstream C"
call assertEqual 1, published~value~remoteManagerCount, "A sends one manager copy to B"
call assertEqual 1, managerA~depth("DT.DIST", "admin")~value["ready"], "A has one distribution work item"
call assertOk remoteA~pumpDistribution(0, "admin"), "A stages B transmission"
call assertOk channelsA~pump("A.TO.B", 0, "admin"), "A sends publication to B"
call assertOk remoteB~pumpPublicationIngress(0, "admin"), "B accepts and forwards publication"
call assertEqual 0, managerB~depth("DT.PUB", "admin")~value["ready"], "B ingress drained"
call assertEqual 1, managerB~depth("DT.DIST", "admin")~value["ready"], "B stages one downstream copy for C"
call assertOk remoteB~pumpDistribution(0, "admin"), "B stages C transmission"
call assertOk channelsB~pump("B.TO.C", 0, "admin"), "B sends publication to C"
call assertOk remoteC~pumpPublicationIngress(0, "admin"), "C performs local fan-out"
call assertEqual 1, managerC~depth("C.ORDERS", "admin")~value["ready"], "C subscriber receives multi-hop publication"
received = managerC~browse("C.ORDERS", "admin")~value
call assertEqual "through-B", received~payload, "multi-hop payload preserved"
call assertEqual "QM.A>QM.B>QM.C", received~headers["oqf.remote.path"], "publication loop-prevention path preserved"
call assertEqual 0, managerC~depth("DT.DIST", "admin")~value["ready"], "C does not reflect publication back toward B"

/* C withdraws. B applies it and marks upstream peer A dirty; after B syncs,
 * A no longer sees B as interested. */
call assertOk topicsC~unsubscribe("C.SUB", "admin"), "C unsubscribes"
call assertOk remoteC~syncPeer("QM.B", "ORDERS", "admin"), "C sends withdrawal"
call assertOk channelsC~pump("C.TO.B", 0, "admin"), "C transports withdrawal"
call assertOk remoteB~pumpControlIngress(0, "admin"), "B applies withdrawal"
call assertOk remoteB~syncPeer("QM.A", "ORDERS", "admin"), "B propagates withdrawal upstream"
call assertOk channelsB~pump("B.TO.A", 0, "admin"), "B transports upstream withdrawal"
call assertOk remoteA~pumpControlIngress(0, "admin"), "A applies upstream withdrawal"
post = topicsA~publish("ORDERS", "no-route", options, "producer")
call assertOk post, "publish after downstream withdrawal"
call assertEqual 0, post~value~remoteManagerCount, "no remote manager remains after cascaded withdrawal"

say "OBJECT QUEUE FABRIC V0.8 DISTRIBUTED TOPIC MULTIHOP: OK"
say "assertions=" || assertions
exit 0

makeQueues: procedure expose assertions
  use arg manager, names
  do name over names
    call assertOk manager~createQueue(name, "TEMPORARY", "TOPIC", 100, "admin"), "create queue " || name
  end
  return
link: procedure expose assertions
  use arg fabric, manager, channelName, xmitQueue, remoteManager, remotePrincipal
  call assertOk fabric~defineSenderChannel(channelName, xmitQueue, remoteManager, channelName, "admin", remotePrincipal, 3, "TEMPORARY", "admin"), "define sender " || channelName
  call assertOk fabric~startSenderChannel(channelName, "admin"), "start sender " || channelName
  return
receiver: procedure expose assertions
  use arg fabric, channelName, sourceManager, inboundPrincipal
  call assertOk fabric~defineReceiverChannel(channelName, sourceManager, inboundPrincipal, "TEMPORARY", "admin"), "define receiver " || channelName
  call assertOk fabric~startReceiverChannel(channelName, "admin"), "start receiver " || channelName
  return
remoteAlias: procedure expose assertions
  use arg fabric, aliasName, remoteQueue, remoteManager, xmitQueue, channelName
  call assertOk fabric~defineRemoteQueue(aliasName, remoteQueue, remoteManager, xmitQueue, channelName, "TOPIC", "TEMPORARY", "admin", "admin"), "define remote alias " || aliasName
  return
pathText: procedure
  use arg path
  text = ""
  do item over path
    if text \= "" then text ||= ">"
    text ||= item
  end
  return text
assertOk: procedure expose assertions
  use arg operationResult, label
  assertions += 1
  if \operationResult~ok then do
    say "ASSERT FAILED:" label "code=" operationResult~code "detail=" operationResult~detail
    exit 1
  end
  return
assertEqual: procedure expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "ObjectQueueDistributedTopics.cls"
