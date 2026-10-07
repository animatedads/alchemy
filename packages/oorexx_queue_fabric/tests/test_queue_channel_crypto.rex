/* ObjectQueueFabric v0.8 authenticated distributed transfer acceptance. */
assertions = 0
stateRoot = "./tmp_channel_crypto_" || .DateTime~new~microseconds
keyHex = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
protector = .QueueHmacSha512RecordProtector~new("channel-key", keyHex, .nil, 64)
manager = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin", .nil, protector)
call assertOk manager~createQueue("INBOX", "PERMANENT", "WIRE", 10, "admin"), "create authenticated inbox"
call assertOk manager~grant("INBOX", "wire-b", .QueueAccess~PUT, "admin"), "persist inbound ACL"
fabric = .QueueChannelFabric~new("QM.B", manager, .QueueInProcessTransport~new, "admin")
call assertOk fabric~defineReceiverChannel("A.TO.B", "QM.A", "wire-b", "PERMANENT", "admin"), "persist receiver definition"
call assertOk fabric~startReceiverChannel("A.TO.B", "admin"), "persist receiver running state"

headers = .table~new; headers["kind"] = "authenticated-transfer"
payload = .array~of("object", "graph")
envelope = .QueueTransmissionEnvelope~new("transfer-crypto-1", "QM.A", "B.INBOX", "source-1", "QM.B", "INBOX", payload, headers, 8, .true, "WIRE", "rk", "corr", "reply", 0)
beforeLines = countLines(stateRoot || "/queue.journal")
receive = fabric~receiveEnvelope(envelope, "A.TO.B", "wire-b")
call assertOk receive, "authenticated receiver accepts transfer"
afterLines = countLines(stateRoot || "/queue.journal")
call assertEqual beforeLines + 1, afterLines, "package insertion and transfer receipt use one journal record"
call assertEqual 1, manager~transferReceiptCount, "live transfer receipt recorded"
call assertEqual 1, manager~depth("INBOX", "admin")~value["ready"], "live package inserted"

protector2 = .QueueHmacSha512RecordProtector~new("channel-key", keyHex, .nil, 64)
manager2 = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin", .nil, protector2)
call assertEqual 1, manager2~transferReceiptCount, "authenticated restart recovers transfer receipt"
call assertEqual 1, manager2~depth("INBOX", "admin")~value["ready"], "authenticated restart recovers package"
call assertEqual "graph", manager2~browse("INBOX", "admin")~value~payload[2], "authenticated restart recovers nested payload"
call assertTrue protector2~verifiedRecords >= afterLines, "all queue journal records verified before replay"

/* Build the channel facade after core replay; its persistent definition/state
 * are independently replayed from the same authenticated journal. */
fabric2 = .QueueChannelFabric~new("QM.B", manager2, .QueueInProcessTransport~new, "admin")
call assertEqual .QueueChannelState~RUNNING, fabric2~receiverChannel("A.TO.B")~state, "authenticated receiver definition/state recovered"
duplicate = fabric2~receiveEnvelope(envelope, "A.TO.B", "wire-b")
call assertOk duplicate, "authenticated duplicate redelivery succeeds"
call assertTrue duplicate~value~duplicate, "authenticated duplicate is identified"
call assertEqual 1, manager2~depth("INBOX", "admin")~value["ready"], "authenticated duplicate does not insert twice"
call assertEqual afterLines, countLines(stateRoot || "/queue.journal"), "duplicate receipt requires no second durable mutation"

say "OBJECT QUEUE FABRIC V0.8 AUTHENTICATED CHANNEL: OK"
say "assertions=" || assertions
exit 0

countLines: procedure
  use arg path
  stream = .Stream~new(path)
  if stream~query("exists") = "" then return 0
  status = stream~open("read")
  if status \= "READY:" then return -1
  count = 0
  do while stream~lines > 0
    ignore = stream~lineIn
    count += 1
  end
  ignore = stream~close
  return count

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

::requires "ObjectQueueChannels.cls"
::requires "ObjectQueueCrypto.cls"
