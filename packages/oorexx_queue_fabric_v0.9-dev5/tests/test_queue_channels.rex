/* ObjectQueueFabric v0.8 distributed channel/store-and-forward acceptance. */
assertions = 0
rootA = "./tmp_channel_A_" || .DateTime~new~microseconds
rootB = "./tmp_channel_B_" || .DateTime~new~microseconds

transport = .QueueInProcessTransport~new
managerA = .ObjectQueueManager~new(rootA, .QueueGraphPayloadCodec~new, "admin")
managerB = .ObjectQueueManager~new(rootB, .QueueGraphPayloadCodec~new, "admin")

call assertOk managerA~createQueue("XMIT.B", "PERMANENT", "WIRE", 10, "admin"), "create persistent transmission queue"
call assertOk managerB~createQueue("INBOX", "PERMANENT", "WIRE", 1, "admin"), "create persistent remote inbox"
call assertOk managerB~createQueue("OTHER", "PERMANENT", "WIRE", 10, "admin"), "create alternate remote queue"
call assertOk managerB~grant("INBOX", "wire-b", .QueueAccess~PUT, "admin"), "grant receiver principal PUT"
call assertOk managerB~grant("OTHER", "wire-b", .QueueAccess~PUT, "admin"), "grant receiver principal alternate PUT"

fabricA = .QueueChannelFabric~new("QM.A", managerA, transport, "admin")
fabricB = .QueueChannelFabric~new("QM.B", managerB, transport, "admin")
ignore = transport~registerEndpoint("QM.A", fabricA)
ignore = transport~registerEndpoint("QM.B", fabricB)

sender = fabricA~defineSenderChannel("A.TO.B", "XMIT.B", "QM.B", "A.TO.B", "admin", "wire-b", 3, "PERMANENT", "admin")
call assertOk sender, "define sender channel"
receiver = fabricB~defineReceiverChannel("A.TO.B", "QM.A", "wire-b", "PERMANENT", "admin")
call assertOk receiver, "define receiver channel"
call assertOk fabricA~startSenderChannel("A.TO.B", "admin"), "start sender channel"
call assertOk fabricB~startReceiverChannel("A.TO.B", "admin"), "start receiver channel"
remoteDef = fabricA~defineRemoteQueue("B.INBOX", "INBOX", "QM.B", "XMIT.B", "A.TO.B", "WIRE", "PERMANENT", "admin", "admin")
call assertOk remoteDef, "define remote queue alias"
call assertOk fabricA~grantRemotePut("B.INBOX", "producer", "admin"), "grant remote alias put"

denied = fabricA~put("B.INBOX", "forbidden", .nil, "stranger")
call assertFalse denied~ok, "remote alias ACL enforced"
call assertEqual "ACCESS_DENIED", denied~code, "remote alias ACL code"

headers = .table~new
headers["job"] = "render-42"
nested = .table~new
nested["kind"] = "render"
steps = .array~new
steps~append("camera")
steps~append("encode")
nested["steps"] = steps
options = .table~new
options["persistent"] = .true
options["priority"] = 7
options["securityDomain"] = "WIRE"
options["routingKey"] = "video.ready"
options["correlationId"] = "corr-1"
options["replyTo"] = "QM.A/REPLY"
options["headers"] = headers
queued = fabricA~put("B.INBOX", nested, options, "producer")
call assertOk queued, "queue remote object graph"
envelope1 = queued~value
call assertEqual .QueueTransmissionEnvelope~PERSISTENT_TYPE, envelope1~queuePersistentType, "remote put returns transmission envelope"
call assertEqual 1, managerA~depth("XMIT.B", "admin")~value["ready"], "remote put lands on transmission queue"
call assertEqual 0, managerB~depth("INBOX", "admin")~value["ready"], "remote destination untouched before pump"

pump1 = fabricA~pump("A.TO.B", 1, "admin")
call assertOk pump1, "pump one transmission"
call assertEqual 0, managerA~depth("XMIT.B", "admin")~value["total"], "successful transmission ACKs xmit package"
call assertEqual 1, managerB~depth("INBOX", "admin")~value["ready"], "remote inbox receives package"
remotePackage = managerB~browse("INBOX", "admin")~value
call assertEqual "render", remotePackage~payload["kind"], "nested payload table preserved"
call assertEqual "encode", remotePackage~payload["steps"][2], "nested payload array preserved"
call assertEqual "render-42", remotePackage~headers["job"], "headers preserved"
call assertEqual 7, remotePackage~priority, "priority preserved"
call assertEqual "video.ready", remotePackage~routingKey, "routing key preserved"
call assertEqual "corr-1", remotePackage~correlationId, "correlation id preserved"
call assertEqual "QM.A/REPLY", remotePackage~replyTo, "reply-to preserved"
call assertEqual "B.INBOX", remotePackage~requestedQueue, "source remote alias retained"
call assertEqual envelope1~transferId, remotePackage~parentPackageId, "source transfer identity retained"
call assertEqual 1, managerB~transferReceiptCount, "receiver records transfer receipt"

/* Redelivery after a lost sender acknowledgement is idempotent at receiver. */
duplicate1 = fabricB~receiveEnvelope(envelope1, "A.TO.B", "wire-b")
call assertOk duplicate1, "duplicate delivery accepted idempotently"
call assertTrue duplicate1~value~duplicate, "duplicate receipt marked duplicate"
call assertEqual 1, managerB~depth("INBOX", "admin")~value["ready"], "duplicate does not insert second package"
call assertEqual 1, managerB~transferReceiptCount, "duplicate does not create second receipt"

/* Receiver receipt survives restart and still suppresses duplicate insertion. */
managerB2 = .ObjectQueueManager~new(rootB, .QueueGraphPayloadCodec~new, "admin")
fabricB2 = .QueueChannelFabric~new("QM.B", managerB2, transport, "admin")
ignore = transport~registerEndpoint("QM.B", fabricB2)
call assertEqual 1, managerB2~transferReceiptCount, "durable transfer receipt recovered"
call assertEqual .QueueChannelState~RUNNING, fabricB2~receiverChannel("A.TO.B")~state, "receiver running state recovered"
duplicate2 = fabricB2~receiveEnvelope(envelope1, "A.TO.B", "wire-b")
call assertOk duplicate2, "post-restart duplicate accepted idempotently"
call assertTrue duplicate2~value~duplicate, "post-restart duplicate marked"
call assertEqual 1, managerB2~depth("INBOX", "admin")~value["ready"], "post-restart duplicate does not insert"

/* Reusing a transfer ID for another destination is rejected, not deduped. */
conflictOptions = .table~new
conflictOptions["persistent"] = .true
conflictOptions["securityDomain"] = "WIRE"
conflictOptions["sourceManager"] = "QM.A"
conflict = managerB2~acceptTransfer(envelope1~transferId, "OTHER", "conflict", conflictOptions, "wire-b")
call assertFalse conflict~ok, "transfer id destination conflict rejected"
call assertEqual "TRANSFER_ID_CONFLICT", conflict~code, "transfer id conflict code"

/* Full destination creates backpressure. XMIT work is RELEASED, not backed out. */
options2 = options~copy
options2["correlationId"] = "corr-2"
queued2 = fabricA~put("B.INBOX", "second", options2, "producer")
call assertOk queued2, "queue second remote package"
backpressure = fabricA~pump("A.TO.B", 1, "admin")
call assertFalse backpressure~ok, "full remote queue causes channel delivery failure"
call assertEqual "CHANNEL_DELIVERY_FAILED", backpressure~code, "backpressure channel code"
call assertEqual .QueueChannelState~RETRYING, fabricA~senderChannel("A.TO.B")~state, "sender enters retrying state"
call assertEqual 1, managerA~depth("XMIT.B", "admin")~value["ready"], "backpressured transmission remains ready"
held = managerA~browse("XMIT.B", "admin")~value
call assertEqual 0, held~backoutCount, "channel release does not increment application backout count"
call assertEqual 1, held~deliveryCount, "failed channel attempt still increments delivery count"

/* Free remote capacity and retry the same transfer. */
removed = managerB2~get("INBOX", "admin")
call assertOk removed, "free remote queue capacity"
duplicateAfterConsume = fabricB2~receiveEnvelope(envelope1, "A.TO.B", "wire-b")
call assertOk duplicateAfterConsume, "receipt suppresses duplicate after original package consumption"
call assertTrue duplicateAfterConsume~value~duplicate, "post-consumption redelivery still marked duplicate"
call assertEqual 0, managerB2~depth("INBOX", "admin")~value["ready"], "post-consumption duplicate does not resurrect package"
retry = fabricA~pump("A.TO.B", 1, "admin")
call assertOk retry, "retry succeeds after backpressure clears"
call assertEqual .QueueChannelState~RUNNING, fabricA~senderChannel("A.TO.B")~state, "sender returns to running"
call assertEqual 0, fabricA~senderChannel("A.TO.B")~retryCount, "successful retry clears retry count"
call assertEqual 0, managerA~depth("XMIT.B", "admin")~value["total"], "retried xmit package removed"
call assertEqual "second", managerB2~browse("INBOX", "admin")~value~payload, "second payload arrives after retry"

/* Store-and-forward survives source manager restart while peer is unavailable. */
ignore = managerB2~get("INBOX", "admin")
ignore = transport~unregisterEndpoint("QM.B")
queued3 = fabricA~put("B.INBOX", "offline", options, "producer")
call assertOk queued3, "queue while remote endpoint later unavailable"
offlineEnvelope = queued3~value
offlineAttempt = fabricA~pump("A.TO.B", 1, "admin")
call assertFalse offlineAttempt~ok, "unavailable manager causes retryable failure"
call assertEqual 1, managerA~depth("XMIT.B", "admin")~value["ready"], "offline work retained in xmit queue"

managerA2 = .ObjectQueueManager~new(rootA, .QueueGraphPayloadCodec~new, "admin")
fabricA2 = .QueueChannelFabric~new("QM.A", managerA2, transport, "admin")
ignore = transport~registerEndpoint("QM.A", fabricA2)
call assertEqual 1, managerA2~depth("XMIT.B", "admin")~value["ready"], "persistent envelope recovered after sender restart"
recoveredEnvelope = managerA2~browse("XMIT.B", "admin")~value~payload
call assertEqual offlineEnvelope~transferId, recoveredEnvelope~transferId, "transmission envelope identity recovered"
call assertEqual .QueueChannelState~RUNNING, fabricA2~senderChannel("A.TO.B")~state, "last durable sender RUNNING state recovered"
call assertTrue fabricA2~remoteQueue("B.INBOX") \== .nil, "permanent remote queue definition recovered"
call assertTrue fabricA2~remoteQueue("B.INBOX")~allowsInternal("producer", .QueueAccess~PUT, .nil) = .false, "remote ACL authority remains sealed"

/* Re-register peer and deliver the recovered envelope. */
ignore = transport~registerEndpoint("QM.B", fabricB2)
recoveredPump = fabricA2~pump("A.TO.B", 1, "admin")
call assertOk recoveredPump, "recovered store-and-forward package delivered"
call assertEqual "offline", managerB2~browse("INBOX", "admin")~value~payload, "offline payload delivered after restart"

/* Receiver channel binding rejects wrong source identity and wrong principal. */
forged = .QueueTransmissionEnvelope~new("forged-1", "QM.EVIL", "X", "forged-1", "QM.B", "INBOX", "evil", .table~new, 0, .false, "WIRE")
wrongSource = fabricB2~receiveEnvelope(forged, "A.TO.B", "wire-b")
call assertFalse wrongSource~ok, "receiver rejects wrong source manager"
call assertEqual "SOURCE_MANAGER_MISMATCH", wrongSource~code, "wrong source code"
wrongPrincipal = fabricB2~receiveEnvelope(envelope1, "A.TO.B", "not-wire-b")
call assertFalse wrongPrincipal~ok, "receiver rejects wrong channel principal"
call assertEqual "CHANNEL_PRINCIPAL_MISMATCH", wrongPrincipal~code, "wrong principal code"

/* Explicit pause/stop state gates channel activity. */
call assertOk fabricA2~pauseSenderChannel("A.TO.B", "admin"), "pause sender"
pausedPump = fabricA2~pump("A.TO.B", 1, "admin")
call assertFalse pausedPump~ok, "paused sender cannot pump"
call assertEqual "CHANNEL_NOT_RUNNING", pausedPump~code, "paused sender code"
call assertOk fabricA2~stopSenderChannel("A.TO.B", "admin"), "stop sender"
call assertEqual .QueueChannelState~STOPPED, fabricA2~senderChannel("A.TO.B")~state, "sender stopped"

/* Retry limit can stop a persistently failing channel without discarding XMIT work. */
call assertOk managerA2~createQueue("XMIT.LIMIT", "TEMPORARY", "WIRE", 5, "admin"), "create retry-limit xmit"
call assertOk fabricA2~defineSenderChannel("LIMIT", "XMIT.LIMIT", "QM.MISSING", "LIMIT", "admin", "wire-b", 1, "TEMPORARY", "admin"), "define retry-limit sender"
call assertOk fabricA2~startSenderChannel("LIMIT", "admin"), "start retry-limit sender"
call assertOk fabricA2~defineRemoteQueue("MISSING.Q", "INBOX", "QM.MISSING", "XMIT.LIMIT", "LIMIT", "WIRE", "TEMPORARY", "admin", "admin"), "define retry-limit alias"
call assertOk fabricA2~put("MISSING.Q", "retain-me", options, "admin"), "queue retry-limit package"
limitFailure = fabricA2~pump("LIMIT", 1, "admin")
call assertFalse limitFailure~ok, "retry-limit delivery fails"
call assertEqual .QueueChannelState~STOPPED, fabricA2~senderChannel("LIMIT")~state, "retry limit stops channel"
call assertEqual 1, fabricA2~senderChannel("LIMIT")~retryCount, "retry limit preserves failure count"
call assertEqual 1, managerA2~depth("XMIT.LIMIT", "admin")~value["ready"], "retry-limit stop preserves xmit work"

say "OBJECT QUEUE FABRIC V0.8 CHANNELS: OK"
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
assertTrue: procedure expose assertions
  use arg condition, label
  assertions += 1
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return
assertFalse: procedure expose assertions
  use arg condition, label
  assertions += 1
  if condition then do
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

::requires "ObjectQueueChannels.cls"
