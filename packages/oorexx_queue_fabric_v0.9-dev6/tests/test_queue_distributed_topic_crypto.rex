/* ObjectQueueFabric v0.8.1 test repair; runtime/API remains v0.8. */
assertions = 0
stateRoot = "./tmp_dtopic_crypto_" || .DateTime~new~microseconds
keyHex = "11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff"

codec = .QueueGraphPayloadCodec~new
ignore = .QueueDistributedTopicSupport~registerTypes(codec)
protector = .QueueHmacSha512RecordProtector~new("dtopic-key", keyHex, .nil, 64)
manager = .ObjectQueueManager~new(stateRoot, codec, "admin", .nil, protector)
transport = .QueueInProcessTransport~new
channels = .QueueChannelFabric~new("QM.B", manager, transport, "admin")
topics = .QueueTopicFabric~new(manager, "admin")
call makeTemporary manager, .array~of("XMIT.A", "DT.CTRL", "DT.PUB", "DT.DIST")
remote = .QueueDistributedTopicFabric~new("QM.B", manager, topics, channels, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
call assertOk manager~createQueue("B.SUB", "PERMANENT", "TOPIC", 100, "admin"), "create permanent B.SUB"
call assertOk channels~defineSenderChannel("B.TO.A", "XMIT.A", "QM.A", "B.TO.A", "admin", "wire-a", 3, "TEMPORARY", "admin"), "define sender"
call assertOk channels~defineRemoteQueue("A.CTRL", "DT.CTRL", "QM.A", "XMIT.A", "B.TO.A", "TOPIC", "TEMPORARY", "admin", "admin"), "define control alias"
call assertOk channels~defineRemoteQueue("A.PUB", "DT.PUB", "QM.A", "XMIT.A", "B.TO.A", "TOPIC", "TEMPORARY", "admin", "admin"), "define publication alias"

call assertOk topics~defineTopic("ORDERS", "orders", "PERMANENT", "TOPIC", "admin"), "define topic"
call assertOk topics~subscribe("B.SUBSCRIPTION", "ORDERS", "uk/#", "B.SUB", "PERMANENT", "admin"), "define subscription"
call assertOk remote~definePeer("QM.A", "ORDERS", "ORDERS", "A.CTRL", "A.PUB", "TEMPORARY", .false, "admin"), "define peer"

payload = .table~new
payload["order"] = 991
payload["parts"] = .array~of("frame", "deliver")
remotePublication = .QueueRemoteTopicPublication~new("QM.A", "pub-crypto-991", "QM.A", "QM.B", "ORDERS", "ORDERS", "uk/crypto", payload, .table~new, 3, .true, "TOPIC", "corr-991", "", 0, .true, .array~of("QM.A"))
putOptions = .table~new
putOptions["persistent"] = .false
putOptions["securityDomain"] = "TOPIC"
call assertOk manager~put("DT.PUB", remotePublication, putOptions, "admin"), "queue authenticated remote publication"
call assertOk remote~pumpPublicationIngress(0, "admin"), "commit authenticated remote publication"
call assertEqual 1, manager~depth("B.SUB", "admin")~value["ready"], "subscriber package committed"
call assertEqual 1, topics~retainedPublications~items, "retained state committed"
call assertEqual 1, remote~receipts~items, "distributed receipt committed"

foundAtomic = .false
rows = manager~durableStore~readJournal
do row over rows
  if row~items < 2 | row[1] \= "UOWCOMMIT" then iterate
  nestedRows = manager~payloadCodec~decode(row[2])
  hasPut = .false
  hasRetain = .false
  hasReceipt = .false
  do nestedRow over nestedRows
    if nestedRow~items = 0 then iterate
    if nestedRow[1] = "PPUT" then hasPut = .true
    if nestedRow[1] = "TOPICRETAIN" then hasRetain = .true
    if nestedRow[1] = "DTPUBRECEIPT" then hasReceipt = .true
  end
  if hasPut & hasRetain & hasReceipt then foundAtomic = .true
end
call assertTrue foundAtomic, "authenticated UOW contains PPUT TOPICRETAIN DTPUBRECEIPT"
call assertTrue protector~authenticatedRecords > 0, "journal protector authenticated records"

codec2 = .QueueGraphPayloadCodec~new
ignore = .QueueDistributedTopicSupport~registerTypes(codec2)
protector2 = .QueueHmacSha512RecordProtector~new("dtopic-key", keyHex, .nil, 64)
manager2 = .ObjectQueueManager~new(stateRoot, codec2, "admin", .nil, protector2)
channels2 = .QueueChannelFabric~new("QM.B", manager2, transport, "admin")
topics2 = .QueueTopicFabric~new(manager2, "admin")
call makeTemporary manager2, .array~of("XMIT.A", "DT.CTRL", "DT.PUB", "DT.DIST")
call assertOk channels2~defineSenderChannel("B.TO.A", "XMIT.A", "QM.A", "B.TO.A", "admin", "wire-a", 3, "TEMPORARY", "admin"), "redefine sender"
call assertOk channels2~defineRemoteQueue("A.CTRL", "DT.CTRL", "QM.A", "XMIT.A", "B.TO.A", "TOPIC", "TEMPORARY", "admin", "admin"), "redefine control alias"
call assertOk channels2~defineRemoteQueue("A.PUB", "DT.PUB", "QM.A", "XMIT.A", "B.TO.A", "TOPIC", "TEMPORARY", "admin", "admin"), "redefine publication alias"
remote2 = .QueueDistributedTopicFabric~new("QM.B", manager2, topics2, channels2, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
call assertOk remote2~definePeer("QM.A", "ORDERS", "ORDERS", "A.CTRL", "A.PUB", "TEMPORARY", .false, "admin"), "redefine peer"
call assertEqual 1, manager2~depth("B.SUB", "admin")~value["ready"], "subscriber package recovered"
call assertEqual 1, topics2~retainedPublications~items, "retained state recovered"
call assertEqual 1, remote2~receipts~items, "distributed receipt recovered"
call assertEqual 1, remote2~peers~items, "peer re-established after restart"
recoveredPackage = manager2~browse("B.SUB", "admin")~value
call assertEqual 991, recoveredPackage~payload["order"], "recovered nested table payload"
call assertEqual "deliver", recoveredPackage~payload["parts"][2], "recovered nested array payload"
call assertTrue protector2~verifiedRecords > 0, "restart verified authenticated records"

/* Requeue the same logical publication after authenticated restart. */
duplicate = .QueueRemoteTopicPublication~new("QM.A", "pub-crypto-991", "QM.A", "QM.B", "ORDERS", "ORDERS", "uk/crypto", payload, .table~new, 3, .true, "TOPIC", "corr-991", "", 0, .true, .array~of("QM.A"))
duplicateOptions = .table~new
duplicateOptions["persistent"] = .false
duplicateOptions["securityDomain"] = "TOPIC"
call assertOk manager2~put("DT.PUB", duplicate, duplicateOptions, "admin"), "queue authenticated duplicate"
call assertOk remote2~pumpPublicationIngress(0, "admin"), "suppress authenticated duplicate"
call assertEqual 1, manager2~depth("B.SUB", "admin")~value["ready"], "duplicate does not refanout"
call assertEqual 1, remote2~receipts~items, "duplicate does not add receipt"

say "OBJECT QUEUE FABRIC V0.8 AUTHENTICATED DISTRIBUTED TOPIC: OK"
say "assertions=" || assertions
exit 0

makeTemporary: procedure expose assertions
  use arg manager, names
  do name over names
    call assertOk manager~createQueue(name, "TEMPORARY", "TOPIC", 100, "admin"), "create temporary " || name
  end
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
::requires "ObjectQueueCrypto.cls"
