/* ObjectQueueFabric v0.9 distributed topic NoSQL projection acceptance. */
assertions = 0
transport = .QueueInProcessTransport~new
managerA = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
managerB = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")

do name over .array~of("XMIT.B", "DT.CTRL", "DT.PUB", "DT.DIST")
  call assertOk managerA~createQueue(name, "TEMPORARY", "TOPIC", 50, "admin"), "create A " || name
end
do name over .array~of("XMIT.A", "DT.CTRL", "DT.PUB", "DT.DIST", "B.SUB")
  call assertOk managerB~createQueue(name, "TEMPORARY", "TOPIC", 50, "admin"), "create B " || name
end
call assertOk managerA~grant("DT.CTRL", "wire-a", .QueueAccess~PUT, "admin"), "grant A ctrl"
call assertOk managerA~grant("DT.PUB", "wire-a", .QueueAccess~PUT, "admin"), "grant A pub"
call assertOk managerB~grant("DT.CTRL", "wire-b", .QueueAccess~PUT, "admin"), "grant B ctrl"
call assertOk managerB~grant("DT.PUB", "wire-b", .QueueAccess~PUT, "admin"), "grant B pub"

channelsA = .QueueChannelFabric~new("QM.A", managerA, transport, "admin")
channelsB = .QueueChannelFabric~new("QM.B", managerB, transport, "admin")
ignore = transport~registerEndpoint("QM.A", channelsA); ignore = transport~registerEndpoint("QM.B", channelsB)
call assertOk channelsA~defineSenderChannel("A.TO.B", "XMIT.B", "QM.B", "A.TO.B", "admin", "wire-b", 3, "TEMPORARY", "admin"), "sender A"
call assertOk channelsB~defineReceiverChannel("A.TO.B", "QM.A", "wire-b", "TEMPORARY", "admin"), "receiver B"
call assertOk channelsB~defineSenderChannel("B.TO.A", "XMIT.A", "QM.A", "B.TO.A", "admin", "wire-a", 3, "TEMPORARY", "admin"), "sender B"
call assertOk channelsA~defineReceiverChannel("B.TO.A", "QM.B", "wire-a", "TEMPORARY", "admin"), "receiver A"
call assertOk channelsA~startSenderChannel("A.TO.B", "admin"), "start A"
call assertOk channelsB~startReceiverChannel("A.TO.B", "admin"), "start receiver B"
call assertOk channelsB~startSenderChannel("B.TO.A", "admin"), "start B"
call assertOk channelsA~startReceiverChannel("B.TO.A", "admin"), "start receiver A"
call assertOk channelsA~defineRemoteQueue("B.CTRL", "DT.CTRL", "QM.B", "XMIT.B", "A.TO.B", "TOPIC", "TEMPORARY", "admin", "admin"), "B ctrl alias"
call assertOk channelsA~defineRemoteQueue("B.PUB", "DT.PUB", "QM.B", "XMIT.B", "A.TO.B", "TOPIC", "TEMPORARY", "admin", "admin"), "B pub alias"
call assertOk channelsB~defineRemoteQueue("A.CTRL", "DT.CTRL", "QM.A", "XMIT.A", "B.TO.A", "TOPIC", "TEMPORARY", "admin", "admin"), "A ctrl alias"
call assertOk channelsB~defineRemoteQueue("A.PUB", "DT.PUB", "QM.A", "XMIT.A", "B.TO.A", "TOPIC", "TEMPORARY", "admin", "admin"), "A pub alias"

topicsA = .QueueTopicFabric~new(managerA, "admin")
topicsB = .QueueTopicFabric~new(managerB, "admin")
call assertOk topicsA~defineTopic("ORDERS", "orders", "TEMPORARY", "TOPIC", "admin"), "topic A"
call assertOk topicsB~defineTopic("ORDERS", "orders", "TEMPORARY", "TOPIC", "admin"), "topic B"
call assertOk topicsB~subscribe("B.SUBSCRIPTION", "ORDERS", "uk/#", "B.SUB", "TEMPORARY", "admin"), "B subscription"
remoteA = .QueueDistributedTopicFabric~new("QM.A", managerA, topicsA, channelsA, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
remoteB = .QueueDistributedTopicFabric~new("QM.B", managerB, topicsB, channelsB, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
call assertOk remoteA~definePeer("QM.B", "ORDERS", "ORDERS", "B.CTRL", "B.PUB", "TEMPORARY", .false, "admin"), "A peer B"
call assertOk remoteB~definePeer("QM.A", "ORDERS", "ORDERS", "A.CTRL", "A.PUB", "TEMPORARY", .false, "admin"), "B peer A"
call assertOk remoteB~syncPeer("QM.A", "ORDERS", "admin"), "B queues interest"
call assertOk channelsB~pump("B.TO.A", 0, "admin"), "B sends interest"
call assertOk remoteA~pumpControlIngress(0, "admin"), "A applies interest"

adapter = .QueueDistributedTopicNoSQLAdapter~new(remoteA)
managerQuery = adapter~query("admin", "SELECT fabric_version FROM mq_manager")
call assertEqual .Error~SUCCESS, managerQuery~status, "manager query"
call assertEqual "0.9", managerQuery~rows[1]["fabric_version"], "v0.9 projected"
peerQuery = adapter~query("admin", "SELECT remote_manager,local_topic,remote_topic,lifecycle,allow_cross_domain FROM mq_topic_peers")
call assertEqual .Error~SUCCESS, peerQuery~status, "peer query"
call assertEqual 1, peerQuery~rows~items, "one peer"
call assertEqual "QM.B", peerQuery~rows[1]["remote_manager"], "remote manager projected"
call assertEqual "ORDERS", peerQuery~rows[1]["local_topic"], "local topic projected"
interestQuery = adapter~query("admin", "SELECT remote_manager,revision,advertisement_count FROM mq_remote_topic_interests")
call assertEqual .Error~SUCCESS, interestQuery~status, "interest query"
call assertEqual 1, interestQuery~rows~items, "one remote interest"
call assertEqual 1, interestQuery~rows[1]["advertisement_count"], "one aggregated advertisement"
advertQuery = adapter~query("admin", "SELECT pattern,origin_manager,path FROM mq_topic_interest_advertisements")
call assertEqual .Error~SUCCESS, advertQuery~status, "advertisement query"
call assertEqual 1, advertQuery~rows~items, "one advertisement row"
call assertEqual "uk/#", advertQuery~rows[1]["pattern"], "pattern projected"
call assertEqual "QM.B", advertQuery~rows[1]["origin_manager"], "origin projected"
call assertEqual "QM.B", advertQuery~rows[1]["path"], "path projected"

hiddenPeers = adapter~query("producer", "SELECT remote_manager FROM mq_topic_peers")
call assertEqual .Error~SUCCESS, hiddenPeers~status, "non-admin peer query executes"
call assertEqual 0, hiddenPeers~rows~items, "non-admin cannot inspect peers"
hiddenInterests = adapter~query("producer", "SELECT remote_manager FROM mq_remote_topic_interests")
call assertEqual 0, hiddenInterests~rows~items, "non-admin cannot inspect remote interests"

/* Generate a distributed receipt then verify projection. */
remotePublication = .QueueRemoteTopicPublication~new("QM.B", "pub-nosql-1", "QM.B", "QM.A", "ORDERS", "ORDERS", "uk/new", "value", .table~new, 0, .false, "TOPIC", "", "", 0, .false, .array~of("QM.B"))
call assertOk managerA~put("DT.PUB", remotePublication, .nil, "admin"), "queue incoming publication"
call assertOk remoteA~pumpPublicationIngress(0, "admin"), "accept incoming publication"
receiptQuery = adapter~query("admin", "SELECT origin_manager,publication_id,destination_topic,source_manager FROM mq_topic_distribution_receipts")
call assertEqual .Error~SUCCESS, receiptQuery~status, "receipt query"
call assertEqual 1, receiptQuery~rows~items, "one distribution receipt"
call assertEqual "pub-nosql-1", receiptQuery~rows[1]["publication_id"], "receipt publication projected"
trafficQuery = adapter~query("admin", "SELECT event_type,source_manager,destination_manager FROM mq_distributed_topic_traffic WHERE event_type='DT_PUBLICATION_ACCEPT'")
call assertEqual .Error~SUCCESS, trafficQuery~status, "distributed traffic query"
call assertEqual 1, trafficQuery~rows~items, "accept traffic projected"

say "OBJECT QUEUE FABRIC V0.9 DISTRIBUTED TOPIC NOSQL: OK"
say "assertions=" || assertions
exit 0

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

::requires "ObjectQueueDistributedTopicNoSQL.cls"
