/* ObjectQueueFabric v0.8 authenticated durable topic/UOW acceptance. */
assertions = 0
stateRoot = "./tmp_topic_crypto_" || .DateTime~new~microseconds
keyHex = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
protector = .QueueHmacSha512RecordProtector~new("topic-key", keyHex, .nil, 64)
manager = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin", .nil, protector)
call assertOk manager~createQueue("SUB.Q", "PERMANENT", "APP", 10, "admin"), "create durable subscriber queue"
topics = .QueueTopicFabric~new(manager)
call assertOk topics~defineTopic("STATE", "state", "PERMANENT", "APP", "admin"), "create durable topic"
call assertOk topics~subscribe("STATE.SUB", "STATE", "#", "SUB.Q", "PERMANENT", "admin"), "create durable subscription"
beforeLines = countLines(stateRoot || "/queue.journal")
call assertEqual 3, beforeLines, "queue/topic/subscription definitions are three records"

payload = .table~new
payload["status"] = "green"
payload["nodes"] = .array~of("a", "b")
options = .table~new
options["subtopic"] = "service/api"
options["persistent"] = .true
options["retain"] = .true
options["correlationId"] = "topic-crypto-1"
published = topics~publish("STATE", payload, options, "admin")
call assertOk published, "publish authenticated retained work"
call assertEqual 1, published~value~matchedCount, "one durable subscriber matched"
call assertTrue published~value~retained, "publication retained"
call assertEqual beforeLines + 1, countLines(stateRoot || "/queue.journal"), "fanout and retained state use one authenticated UOW record"
call assertEqual 1, manager~depth("SUB.Q", "admin")~value["ready"], "subscriber package committed"
call assertEqual 1, topics~retainedPublications~items, "retained state committed"

/* Inspect the authenticated journal through the protector, not raw QAUTH2 text. */
rows = manager~durableStore~readJournal
lastRow = rows[rows~items]
call assertEqual "UOWCOMMIT", lastRow[1], "topic publication durable envelope is UOWCOMMIT"
nestedRows = manager~payloadCodec~decode(lastRow[2])
foundPut = .false
foundRetain = .false
do nestedRow over nestedRows
  if nestedRow[1] = "PPUT" then foundPut = .true
  if nestedRow[1] = "TOPICRETAIN" then foundRetain = .true
end
call assertTrue foundPut, "UOW durable envelope contains subscriber PPUT"
call assertTrue foundRetain, "same UOW durable envelope contains retained publication"

protector2 = .QueueHmacSha512RecordProtector~new("topic-key", keyHex, .nil, 64)
manager2 = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin", .nil, protector2)
topics2 = .QueueTopicFabric~new(manager2)
call assertTrue topics2~topic("STATE") \== .nil, "authenticated topic definition recovered"
call assertTrue topics2~subscription("STATE.SUB") \== .nil, "authenticated subscription recovered"
call assertEqual 1, topics2~retainedPublications~items, "authenticated retained publication recovered"
call assertEqual "green", topics2~retainedPublications[1]~payload["status"], "retained payload recovered"
call assertEqual "b", topics2~retainedPublications[1]~payload["nodes"][2], "nested retained graph recovered"
call assertEqual 1, manager2~depth("SUB.Q", "admin")~value["ready"], "subscriber package recovered from same UOW"
recoveredPackage = manager2~browse("SUB.Q", "admin")~value
call assertEqual "green", recoveredPackage~payload["status"], "subscriber payload recovered"
call assertEqual published~value~publicationId, recoveredPackage~headers["oqf.topic.publication_id"], "publication identity recovered"
call assertTrue protector2~verifiedRecords >= 4, "authenticated topic records verified"

say "OBJECT QUEUE FABRIC V0.8 AUTHENTICATED TOPIC: OK"
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

::requires "ObjectQueueTopics.cls"
::requires "ObjectQueueCrypto.cls"
