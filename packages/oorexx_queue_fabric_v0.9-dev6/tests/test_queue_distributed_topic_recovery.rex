/* ObjectQueueFabric v0.8 durable distributed-topic recovery acceptance. */
assertions = 0
stamp = .DateTime~new~microseconds
rootA = "./tmp_dtopic_A_" || stamp
rootB = "./tmp_dtopic_B_" || stamp
transport = .QueueInProcessTransport~new

codecA = .QueueGraphPayloadCodec~new
ignore = .QueueDistributedTopicSupport~registerTypes(codecA)
codecB = .QueueGraphPayloadCodec~new
ignore = .QueueDistributedTopicSupport~registerTypes(codecB)
managerA = .ObjectQueueManager~new(rootA, codecA, "admin")
managerB = .ObjectQueueManager~new(rootB, codecB, "admin")
call makePermanent managerA, .array~of("XMIT.B", "DT.CTRL", "DT.PUB", "DT.DIST")
call makePermanent managerB, .array~of("XMIT.A", "DT.CTRL", "DT.PUB", "DT.DIST", "B.SUB")
call assertOk managerA~grant("DT.CTRL", "wire-a", .QueueAccess~PUT, "admin"), "grant A control"
call assertOk managerA~grant("DT.PUB", "wire-a", .QueueAccess~PUT, "admin"), "grant A pub"
call assertOk managerB~grant("DT.CTRL", "wire-b", .QueueAccess~PUT, "admin"), "grant B control"
call assertOk managerB~grant("DT.PUB", "wire-b", .QueueAccess~PUT, "admin"), "grant B pub"

channelsA = .QueueChannelFabric~new("QM.A", managerA, transport, "admin")
channelsB = .QueueChannelFabric~new("QM.B", managerB, transport, "admin")
ignore = transport~registerEndpoint("QM.A", channelsA); ignore = transport~registerEndpoint("QM.B", channelsB)
call permanentLink channelsA, "A.TO.B", "XMIT.B", "QM.B", "wire-b"
call permanentReceiver channelsB, "A.TO.B", "QM.A", "wire-b"
call permanentLink channelsB, "B.TO.A", "XMIT.A", "QM.A", "wire-a"
call permanentReceiver channelsA, "B.TO.A", "QM.B", "wire-a"
call permanentAlias channelsA, "B.CTRL", "DT.CTRL", "QM.B", "XMIT.B", "A.TO.B"
call permanentAlias channelsA, "B.PUB", "DT.PUB", "QM.B", "XMIT.B", "A.TO.B"
call permanentAlias channelsB, "A.CTRL", "DT.CTRL", "QM.A", "XMIT.A", "B.TO.A"
call permanentAlias channelsB, "A.PUB", "DT.PUB", "QM.A", "XMIT.A", "B.TO.A"

topicsA = .QueueTopicFabric~new(managerA, "admin")
topicsB = .QueueTopicFabric~new(managerB, "admin")
call assertOk topicsA~defineTopic("ORDERS", "orders", "PERMANENT", "TOPIC", "admin"), "permanent topic A"
call assertOk topicsB~defineTopic("ORDERS", "orders", "PERMANENT", "TOPIC", "admin"), "permanent topic B"
call assertOk topicsA~grantTopicAccess("ORDERS", "producer", .QueueTopicAccess~PUBLISH, "admin"), "grant producer"
call assertOk topicsB~subscribe("B.SUBSCRIPTION", "ORDERS", "uk/#", "B.SUB", "PERMANENT", "admin"), "permanent B subscription"
remoteA = .QueueDistributedTopicFabric~new("QM.A", managerA, topicsA, channelsA, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
remoteB = .QueueDistributedTopicFabric~new("QM.B", managerB, topicsB, channelsB, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
call assertOk remoteA~definePeer("QM.B", "ORDERS", "ORDERS", "B.CTRL", "B.PUB", "PERMANENT", .false, "admin"), "permanent A peer"
call assertOk remoteB~definePeer("QM.A", "ORDERS", "ORDERS", "A.CTRL", "A.PUB", "PERMANENT", .false, "admin"), "permanent B peer"

/* B advertises durable interest to A. */
call assertOk remoteB~syncPeer("QM.A", "ORDERS", "admin"), "queue persistent interest"
call assertOk channelsB~pump("B.TO.A", 0, "admin"), "send persistent interest"
call assertOk remoteA~pumpControlIngress(0, "admin"), "apply persistent interest"
call assertEqual 1, remoteA~remoteInterests~items, "A stores remote interest"

/* A publishes retained persistent work. Local acceptance records remote intent
 * and retained state atomically, then A restarts before any network send. */
payload = .table~new
payload["order"] = 8808
parts = .array~of("frame", "encode")
payload["parts"] = parts
options = .table~new
options["subtopic"] = "uk/restart"
options["persistent"] = .true
options["retain"] = .true
options["securityDomain"] = "TOPIC"
options["correlationId"] = "recover-88"
publishResult = topicsA~publish("ORDERS", payload, options, "producer")
call assertOk publishResult, "publish durable distributed retained work"
publicationId = publishResult~value~publicationId
call assertEqual 1, publishResult~value~remoteManagerCount, "one remote durable target"
call assertEqual 1, managerA~depth("DT.DIST", "admin")~value["ready"], "durable distribution work recorded"
call assertEqual 1, topicsA~retainedPublications~items, "A retained state recorded"

/* Restart A. Distributed payload factories must be registered before manager
 * recovery because a persistent distribution-work object is queued. */
codecA2 = .QueueGraphPayloadCodec~new
ignore = .QueueDistributedTopicSupport~registerTypes(codecA2)
managerA2 = .ObjectQueueManager~new(rootA, codecA2, "admin")
channelsA2 = .QueueChannelFabric~new("QM.A", managerA2, transport, "admin")
topicsA2 = .QueueTopicFabric~new(managerA2, "admin")
remoteA2 = .QueueDistributedTopicFabric~new("QM.A", managerA2, topicsA2, channelsA2, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
ignore = transport~registerEndpoint("QM.A", channelsA2)
call assertEqual 1, managerA2~depth("DT.DIST", "admin")~value["ready"], "A restart recovers distribution work"
call assertEqual 1, remoteA2~peers~items, "A restart recovers peer definition"
call assertEqual 1, remoteA2~remoteInterests~items, "A restart recovers remote interest"
call assertEqual 1, topicsA2~retainedPublications~items, "A restart recovers retained value"
recoveredWork = managerA2~browse("DT.DIST", "admin")~value~payload
call assertEqual .QueueTopicDistributionWork~PERSISTENT_TYPE, recoveredWork~queuePersistentType, "custom distribution payload recovered"
call assertEqual 8808, recoveredWork~payload["order"], "nested retained payload recovered at source"
call assertEqual "encode", recoveredWork~payload["parts"][2], "nested array recovered at source"

/* Send recovered work to B and commit local fan-out + retained + receipt. */
call assertOk remoteA2~pumpDistribution(0, "admin"), "recovered A stages channel work"
call assertOk channelsA2~pump("A.TO.B", 0, "admin"), "recovered A transmits"
call assertEqual 1, managerB~depth("DT.PUB", "admin")~value["ready"], "B receives remote publication ingress"
call assertOk remoteB~pumpPublicationIngress(0, "admin"), "B commits remote publication"
call assertEqual 1, managerB~depth("B.SUB", "admin")~value["ready"], "B subscriber receives persistent publication"
call assertEqual 1, topicsB~retainedPublications~items, "B installs retained state"
call assertEqual 1, remoteB~receipts~items, "B records distributed receipt"
received = managerB~browse("B.SUB", "admin")~value
call assertEqual 8808, received~payload["order"], "B payload table preserved"
call assertEqual "encode", received~payload["parts"][2], "B payload array preserved"
call assertEqual "recover-88", received~correlationId, "B correlation preserved"

/* Prove subscriber PPUT, retained state and distributed receipt share one
 * journal UOW on B. */
foundAtomic = .false
rows = managerB~durableStore~readJournal
do row over rows
  if row~items < 2 | row[1] \= "UOWCOMMIT" then iterate
  nested = managerB~payloadCodec~decode(row[2])
  hasPut = .false; hasRetain = .false; hasReceipt = .false
  do nestedRow over nested
    if nestedRow~items = 0 then iterate
    if nestedRow[1] = "PPUT" then hasPut = .true
    if nestedRow[1] = "TOPICRETAIN" then hasRetain = .true
    if nestedRow[1] = "DTPUBRECEIPT" then hasReceipt = .true
  end
  if hasPut & hasRetain & hasReceipt then foundAtomic = .true
end
call assertTrue foundAtomic, "B fan-out retain and receipt occupy one UOW journal record"

/* Restart B and verify all three durable consequences recover together. */
codecB2 = .QueueGraphPayloadCodec~new
ignore = .QueueDistributedTopicSupport~registerTypes(codecB2)
managerB2 = .ObjectQueueManager~new(rootB, codecB2, "admin")
channelsB2 = .QueueChannelFabric~new("QM.B", managerB2, transport, "admin")
topicsB2 = .QueueTopicFabric~new(managerB2, "admin")
remoteB2 = .QueueDistributedTopicFabric~new("QM.B", managerB2, topicsB2, channelsB2, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
ignore = transport~registerEndpoint("QM.B", channelsB2)
call assertEqual 1, managerB2~depth("B.SUB", "admin")~value["ready"], "B restart recovers subscriber package"
call assertEqual 1, topicsB2~retainedPublications~items, "B restart recovers retained state"
call assertEqual 1, remoteB2~receipts~items, "B restart recovers distributed receipt"
call assertEqual 1, remoteB2~peers~items, "B restart recovers peer definition"
call assertEqual .QueueTopicPattern~matches("orders/uk/#", topicsB2~retainedPublications[1]~topicString), .true, "retained topic string recovered"

/* Reinject same logical remote publication after restart. Receipt suppresses
 * a second local fan-out even though it is a new ingress queue package. */
duplicate = .QueueRemoteTopicPublication~new("QM.A", publicationId, "QM.A", "QM.B", "ORDERS", "ORDERS", "uk/restart", payload, .table~new, 0, .true, "TOPIC", "recover-88", "", 0, .true, .array~of("QM.A"))
duplicateOptions = .table~new
duplicateOptions["persistent"] = .true
duplicateOptions["securityDomain"] = "TOPIC"
call assertOk managerB2~put("DT.PUB", duplicate, duplicateOptions, "admin"), "queue post-restart duplicate"
call assertOk remoteB2~pumpPublicationIngress(0, "admin"), "post-restart duplicate suppressed"
call assertEqual 1, managerB2~depth("B.SUB", "admin")~value["ready"], "duplicate does not create second subscriber package"
call assertEqual 1, remoteB2~receipts~items, "duplicate does not create second receipt"

say "OBJECT QUEUE FABRIC V0.8 DISTRIBUTED TOPIC RECOVERY: OK"
say "assertions=" || assertions
exit 0

makePermanent: procedure expose assertions
  use arg manager, names
  do name over names
    call assertOk manager~createQueue(name, "PERMANENT", "TOPIC", 100, "admin"), "create permanent " || name
  end
  return
permanentLink: procedure expose assertions
  use arg fabric, channelName, xmitQueue, remoteManager, remotePrincipal
  call assertOk fabric~defineSenderChannel(channelName, xmitQueue, remoteManager, channelName, "admin", remotePrincipal, 3, "PERMANENT", "admin"), "define permanent sender " || channelName
  call assertOk fabric~startSenderChannel(channelName, "admin"), "start permanent sender " || channelName
  return
permanentReceiver: procedure expose assertions
  use arg fabric, channelName, sourceManager, inboundPrincipal
  call assertOk fabric~defineReceiverChannel(channelName, sourceManager, inboundPrincipal, "PERMANENT", "admin"), "define permanent receiver " || channelName
  call assertOk fabric~startReceiverChannel(channelName, "admin"), "start permanent receiver " || channelName
  return
permanentAlias: procedure expose assertions
  use arg fabric, aliasName, remoteQueue, remoteManager, xmitQueue, channelName
  call assertOk fabric~defineRemoteQueue(aliasName, remoteQueue, remoteManager, xmitQueue, channelName, "TOPIC", "PERMANENT", "admin", "admin"), "define permanent alias " || aliasName
  return
assertOk: procedure expose assertions
  use arg operationResult, label
  assertions += 1
  if \operationResult~ok then do
    say "ASSERT FAILED:" label "code=" operationResult~code "detail=" operationResult~detail
    exit 1
  end
  return
assertTrue: procedure expose assertions
  use arg condition, label
  assertions += 1
  if \condition then do
    say "ASSERT FAILED:" label
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
