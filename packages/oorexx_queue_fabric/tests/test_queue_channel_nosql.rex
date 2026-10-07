/* ObjectQueueFabric v0.9 distributed channel NoSQL projection acceptance. */
assertions = 0
transport = .QueueInProcessTransport~new
managerA = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
managerB = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call assertOk managerA~createQueue("XMIT.B", "TEMPORARY", "WIRE", 10, "admin"), "create xmit"
call assertOk managerB~createQueue("INBOX", "TEMPORARY", "WIRE", 10, "admin"), "create inbox"
call assertOk managerB~grant("INBOX", "wire-b", .QueueAccess~PUT, "admin"), "grant inbound"
fabricA = .QueueChannelFabric~new("QM.A", managerA, transport, "admin")
fabricB = .QueueChannelFabric~new("QM.B", managerB, transport, "admin")
ignore = transport~registerEndpoint("QM.B", fabricB)
call assertOk fabricA~defineSenderChannel("A.TO.B", "XMIT.B", "QM.B", "A.TO.B", "admin", "wire-b", 5, "TEMPORARY", "admin"), "define sender"
call assertOk fabricB~defineReceiverChannel("A.TO.B", "QM.A", "wire-b", "TEMPORARY", "admin"), "define receiver"
call assertOk fabricA~startSenderChannel("A.TO.B", "admin"), "start sender"
call assertOk fabricB~startReceiverChannel("A.TO.B", "admin"), "start receiver"
call assertOk fabricA~defineRemoteQueue("B.INBOX", "INBOX", "QM.B", "XMIT.B", "A.TO.B", "WIRE", "TEMPORARY", "admin", "admin"), "define remote"
call assertOk fabricA~grantRemotePut("B.INBOX", "producer", "admin"), "grant producer"

adapterA = .QueueChannelNoSQLAdapter~new(fabricA)
senderQuery = adapterA~query("admin", "SELECT channel_name,state,transmission_queue,remote_manager,retry_limit,sent_count FROM mq_sender_channels WHERE channel_name='A.TO.B'")
call assertEqual .Error~SUCCESS, senderQuery~status, "sender channel query"
call assertEqual 1, senderQuery~rows~items, "one sender channel row"
call assertEqual "RUNNING", senderQuery~rows[1]["state"], "sender state projected"
call assertEqual "XMIT.B", senderQuery~rows[1]["transmission_queue"], "xmit projected"
call assertEqual "QM.B", senderQuery~rows[1]["remote_manager"], "remote manager projected"
call assertEqual 5, senderQuery~rows[1]["retry_limit"], "retry limit projected"
call assertEqual 0, senderQuery~rows[1]["sent_count"], "initial sent count projected"

remoteAdmin = adapterA~query("admin", "SELECT alias_name,remote_queue,channel_name,security_domain FROM mq_remote_queues WHERE alias_name='B.INBOX'")
call assertEqual .Error~SUCCESS, remoteAdmin~status, "remote queue admin query"
call assertEqual 1, remoteAdmin~rows~items, "remote queue visible to admin"
call assertEqual "INBOX", remoteAdmin~rows[1]["remote_queue"], "remote queue name projected"
call assertEqual "A.TO.B", remoteAdmin~rows[1]["channel_name"], "remote channel projected"

remoteProducer = adapterA~query("producer", "SELECT alias_name FROM mq_remote_queues")
call assertEqual .Error~SUCCESS, remoteProducer~status, "remote queue producer query"
call assertEqual 1, remoteProducer~rows~items, "authorised producer sees remote alias"
senderProducer = adapterA~query("producer", "SELECT channel_name FROM mq_sender_channels")
call assertEqual .Error~SUCCESS, senderProducer~status, "non-admin sender query"
call assertEqual 0, senderProducer~rows~items, "non-admin does not see channel credentials/state"

options = .table~new; options["securityDomain"] = "WIRE"
queued = fabricA~put("B.INBOX", "hello", options, "producer")
call assertOk queued, "queue remote message"
call assertOk fabricA~pump("A.TO.B", 1, "admin"), "deliver remote message"

senderAfter = adapterA~query("admin", "SELECT sent_count,retry_count,state FROM mq_sender_channels WHERE channel_name='A.TO.B'")
call assertEqual 1, senderAfter~rows[1]["sent_count"], "sent count becomes queryable"
call assertEqual 0, senderAfter~rows[1]["retry_count"], "retry count queryable"
call assertEqual "RUNNING", senderAfter~rows[1]["state"], "running state retained"

adapterB = .QueueChannelNoSQLAdapter~new(fabricB)
receiverQuery = adapterB~query("admin", "SELECT channel_name,source_manager,state,received_count,duplicate_count,rejected_count FROM mq_receiver_channels WHERE channel_name='A.TO.B'")
call assertEqual .Error~SUCCESS, receiverQuery~status, "receiver channel query"
call assertEqual 1, receiverQuery~rows~items, "one receiver row"
call assertEqual "QM.A", receiverQuery~rows[1]["source_manager"], "receiver source manager projected"
call assertEqual 1, receiverQuery~rows[1]["received_count"], "receive count projected"

receiptQuery = adapterB~query("admin", "SELECT transfer_id,queue_name,source_manager FROM mq_transfer_receipts")
call assertEqual .Error~SUCCESS, receiptQuery~status, "transfer receipt query"
call assertEqual 1, receiptQuery~rows~items, "transfer receipt projected"
call assertEqual "INBOX", receiptQuery~rows[1]["queue_name"], "receipt queue projected"
call assertEqual "QM.A", receiptQuery~rows[1]["source_manager"], "receipt source manager projected"

managerQuery = adapterB~query("admin", "SELECT fabric_version FROM mq_manager")
call assertEqual "0.9", managerQuery~rows[1]["fabric_version"], "channel adapter includes v0.9 base manager projection"

say "OBJECT QUEUE FABRIC V0.9 CHANNEL NOSQL: OK"
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

::requires "ObjectQueueChannelNoSQL.cls"
