/* ObjectQueueFabric v0.8 distributed topic interest/fan-out acceptance. */
assertions = 0
transport = .QueueInProcessTransport~new
managerA = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
managerB = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")

/* Local transport plumbing. */
do qName over .array~of("XMIT.B", "DT.CTRL", "DT.PUB", "DT.DIST", "A.LOCAL")
  call assertOk managerA~createQueue(qName, "TEMPORARY", "TOPIC", 50, "admin"), "create A queue " || qName
end
do qName over .array~of("XMIT.A", "DT.CTRL", "DT.PUB", "DT.DIST", "B.ONE", "B.TWO", "B.THREE")
  call assertOk managerB~createQueue(qName, "TEMPORARY", "TOPIC", 50, "admin"), "create B queue " || qName
end
call assertOk managerA~grant("DT.CTRL", "wire-a", .QueueAccess~PUT, "admin"), "grant A control ingress"
call assertOk managerA~grant("DT.PUB", "wire-a", .QueueAccess~PUT, "admin"), "grant A publication ingress"
call assertOk managerB~grant("DT.CTRL", "wire-b", .QueueAccess~PUT, "admin"), "grant B control ingress"
call assertOk managerB~grant("DT.PUB", "wire-b", .QueueAccess~PUT, "admin"), "grant B publication ingress"

channelsA = .QueueChannelFabric~new("QM.A", managerA, transport, "admin")
channelsB = .QueueChannelFabric~new("QM.B", managerB, transport, "admin")
ignore = transport~registerEndpoint("QM.A", channelsA)
ignore = transport~registerEndpoint("QM.B", channelsB)
call assertOk channelsA~defineSenderChannel("A.TO.B", "XMIT.B", "QM.B", "A.TO.B", "admin", "wire-b", 3, "TEMPORARY", "admin"), "define A sender"
call assertOk channelsB~defineReceiverChannel("A.TO.B", "QM.A", "wire-b", "TEMPORARY", "admin"), "define B receiver"
call assertOk channelsB~defineSenderChannel("B.TO.A", "XMIT.A", "QM.A", "B.TO.A", "admin", "wire-a", 3, "TEMPORARY", "admin"), "define B sender"
call assertOk channelsA~defineReceiverChannel("B.TO.A", "QM.B", "wire-a", "TEMPORARY", "admin"), "define A receiver"
call assertOk channelsA~startSenderChannel("A.TO.B", "admin"), "start A sender"
call assertOk channelsB~startReceiverChannel("A.TO.B", "admin"), "start B receiver"
call assertOk channelsB~startSenderChannel("B.TO.A", "admin"), "start B sender"
call assertOk channelsA~startReceiverChannel("B.TO.A", "admin"), "start A receiver"
call assertOk channelsA~defineRemoteQueue("B.CTRL", "DT.CTRL", "QM.B", "XMIT.B", "A.TO.B", "TOPIC", "TEMPORARY", "admin", "admin"), "define B control alias"
call assertOk channelsA~defineRemoteQueue("B.PUB", "DT.PUB", "QM.B", "XMIT.B", "A.TO.B", "TOPIC", "TEMPORARY", "admin", "admin"), "define B publication alias"
call assertOk channelsB~defineRemoteQueue("A.CTRL", "DT.CTRL", "QM.A", "XMIT.A", "B.TO.A", "TOPIC", "TEMPORARY", "admin", "admin"), "define A control alias"
call assertOk channelsB~defineRemoteQueue("A.PUB", "DT.PUB", "QM.A", "XMIT.A", "B.TO.A", "TOPIC", "TEMPORARY", "admin", "admin"), "define A publication alias"

topicsA = .QueueTopicFabric~new(managerA, "admin")
topicsB = .QueueTopicFabric~new(managerB, "admin")
call assertOk topicsA~defineTopic("ORDERS", "orders", "TEMPORARY", "TOPIC", "admin"), "define A topic"
call assertOk topicsB~defineTopic("ORDERS", "orders", "TEMPORARY", "TOPIC", "admin"), "define B topic"
call assertOk topicsA~grantTopicAccess("ORDERS", "producer", .QueueTopicAccess~PUBLISH, "admin"), "grant A publisher"

remoteA = .QueueDistributedTopicFabric~new("QM.A", managerA, topicsA, channelsA, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
remoteB = .QueueDistributedTopicFabric~new("QM.B", managerB, topicsB, channelsB, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
call assertOk remoteA~definePeer("QM.B", "ORDERS", "ORDERS", "B.CTRL", "B.PUB", "TEMPORARY", .false, "admin"), "define A topic peer"
call assertOk remoteB~definePeer("QM.A", "ORDERS", "ORDERS", "A.CTRL", "A.PUB", "TEMPORARY", .false, "admin"), "define B topic peer"

/* Both sides have interest. B has two matching subscriptions but advertises
 * aggregate manager interest, so A stages one remote copy for QM.B. */
call assertOk topicsA~subscribe("A.LOCAL.SUB", "ORDERS", "uk/#", "A.LOCAL", "TEMPORARY", "admin"), "subscribe A local"
call assertOk topicsB~subscribe("B.ONE.SUB", "ORDERS", "uk/#", "B.ONE", "TEMPORARY", "admin"), "subscribe B one"
call assertOk topicsB~subscribe("B.TWO.SUB", "ORDERS", "uk/#", "B.TWO", "TEMPORARY", "admin"), "subscribe B two"
call syncOne remoteA, channelsA, remoteB, channelsB, "QM.B", "ORDERS", "A.TO.B", "B side receives A interest"
call syncOne remoteB, channelsB, remoteA, channelsA, "QM.A", "ORDERS", "B.TO.A", "A side receives B interest"
call assertEqual 1, remoteA~remoteInterests~items, "A has one remote interest state"
call assertEqual 1, remoteB~remoteInterests~items, "B has one remote interest state"

payload = .table~new
payload["order"] = 42
steps = .array~of("validate", "dispatch")
payload["steps"] = steps
options = .table~new
options["subtopic"] = "uk/new"
options["persistent"] = .false
options["securityDomain"] = "TOPIC"
published = topicsA~publish("ORDERS", payload, options, "producer")
call assertOk published, "publish distributed topic"
call assertEqual 1, published~value~matchedCount, "one local A subscription matched"
call assertEqual 1, published~value~remoteManagerCount, "one remote manager matched"
call assertEqual 1, managerA~depth("DT.DIST", "admin")~value["ready"], "one distribution item for B despite two B subscriptions"
call assertEqual 1, managerA~depth("A.LOCAL", "admin")~value["ready"], "A local delivery committed atomically"
call assertOk remoteA~pumpDistribution(0, "admin"), "A stages remote publication"
call assertEqual 1, managerA~depth("XMIT.B", "admin")~value["ready"], "one XMIT publication for B"
call assertOk channelsA~pump("A.TO.B", 0, "admin"), "A channel sends publication"
call assertEqual 1, managerB~depth("DT.PUB", "admin")~value["ready"], "B receives one broker publication"
call assertOk remoteB~pumpPublicationIngress(0, "admin"), "B performs local fan-out"
call assertEqual 1, managerB~depth("B.ONE", "admin")~value["ready"], "B subscriber one receives"
call assertEqual 1, managerB~depth("B.TWO", "admin")~value["ready"], "B subscriber two receives"
call assertEqual 0, managerB~depth("DT.DIST", "admin")~value["ready"], "publication path suppresses bounce back to A"
call assertEqual "dispatch", managerB~browse("B.ONE", "admin")~value~payload["steps"][2], "nested object graph survives distributed fan-out"

/* Duplicate broker ingress is suppressed by origin/publication receipt. */
remoteEnvelope = .QueueRemoteTopicPublication~new("QM.A", published~value~publicationId, "QM.A", "QM.B", "ORDERS", "ORDERS", "uk/new", payload, .table~new, 0, .false, "TOPIC", "", "", 0, .false, .array~of("QM.A"))
call assertOk managerB~put("DT.PUB", remoteEnvelope, .nil, "admin"), "inject duplicate broker publication"
call assertOk remoteB~pumpPublicationIngress(0, "admin"), "duplicate broker publication handled"
call assertEqual 1, managerB~depth("B.ONE", "admin")~value["ready"], "duplicate does not refanout one"
call assertEqual 1, managerB~depth("B.TWO", "admin")~value["ready"], "duplicate does not refanout two"
call assertEqual 1, remoteB~receipts~items, "one distributed receipt records publication"

/* Withdrawal replaces the remote snapshot with empty interest. */
call assertOk topicsB~unsubscribe("B.ONE.SUB", "admin"), "unsubscribe B one"
call assertOk topicsB~unsubscribe("B.TWO.SUB", "admin"), "unsubscribe B two"
call syncOne remoteB, channelsB, remoteA, channelsA, "QM.A", "ORDERS", "B.TO.A", "A receives B withdrawal"
options2 = options~copy
options2["subtopic"] = "uk/after-withdraw"
withdrawPublish = topicsA~publish("ORDERS", "local-only", options2, "producer")
call assertOk withdrawPublish, "publish after withdrawal"
call assertEqual 0, withdrawPublish~value~remoteManagerCount, "withdrawal removes remote manager match"
call assertEqual 0, managerA~depth("DT.DIST", "admin")~value["ready"], "withdrawal produces no distribution work"

/* A retained value predating new B interest is handed off when B advertises. */
retainedOptions = options~copy
retainedOptions["subtopic"] = "uk/retained"
retainedOptions["retain"] = .true
retainedPublish = topicsA~publish("ORDERS", "retained-value", retainedOptions, "producer")
call assertOk retainedPublish, "retain while B has no interest"
call assertEqual 0, retainedPublish~value~remoteManagerCount, "retained publication not sent without interest"
call assertOk topicsB~subscribe("B.THREE.SUB", "ORDERS", "uk/#", "B.THREE", "TEMPORARY", "admin"), "subscribe B after retain"
call syncOne remoteB, channelsB, remoteA, channelsA, "QM.A", "ORDERS", "B.TO.A", "A receives renewed B interest"
call assertEqual 1, managerA~depth("DT.DIST", "admin")~value["ready"], "interest activation stages retained handoff"
call assertOk remoteA~pumpDistribution(0, "admin"), "stage retained handoff to channel"
call assertOk channelsA~pump("A.TO.B", 0, "admin"), "send retained handoff"
call assertOk remoteB~pumpPublicationIngress(0, "admin"), "B accepts retained handoff"
call assertEqual 1, managerB~depth("B.THREE", "admin")~value["ready"], "new B subscriber gets retained value"
call assertEqual "retained-value", managerB~browse("B.THREE", "admin")~value~payload, "retained payload preserved"
call assertEqual 1, topicsB~retainedPublications~items, "retained state installed at B"

say "OBJECT QUEUE FABRIC V0.8 DISTRIBUTED TOPICS: OK"
say "assertions=" || assertions
exit 0

syncOne: procedure expose assertions
  use arg sourceRemote, sourceChannels, targetRemote, targetChannels, destinationManager, topicName, senderChannel, label
  syncResult = sourceRemote~syncPeer(destinationManager, topicName, "admin")
  call assertOk syncResult, label || " queue snapshot"
  pumpResult = sourceChannels~pump(senderChannel, 0, "admin")
  call assertOk pumpResult, label || " transport snapshot"
  applyResult = targetRemote~pumpControlIngress(0, "admin")
  call assertOk applyResult, label || " apply snapshot"
  return

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
