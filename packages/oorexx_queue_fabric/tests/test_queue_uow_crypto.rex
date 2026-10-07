/* ObjectQueueFabric v0.8 authenticated durable UOW acceptance. */
assertions = 0
stateRoot = "./tmp_uow_crypto_" || .DateTime~new~microseconds
keyHex = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
protector = .QueueHmacSha512RecordProtector~new("uow-key", keyHex, .nil, 64)
manager = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin", .nil, protector)
call assertOk manager~createQueue("P1", "PERMANENT", "OPS", 10, "admin"), "create P1"
call assertOk manager~createQueue("P2", "PERMANENT", "OPS", 10, "admin"), "create P2"
options = .table~new; options["persistent"] = .true
call assertOk manager~put("P1", "before", options, "admin"), "seed P1"
call assertEqual 3, countLines(stateRoot || "/queue.journal"), "three records before UOW commit"
uow = manager~beginUnitOfWork("admin")~value
call assertOk manager~uowGet(uow, "P1"), "reserve durable input"
call assertOk manager~uowPut(uow, "P2", "after", options), "stage durable output"
call assertEqual 3, countLines(stateRoot || "/queue.journal"), "reservation/staging do not journal partial transaction"
call assertOk manager~commitUnitOfWork(uow), "commit authenticated UOW"
call assertEqual 4, countLines(stateRoot || "/queue.journal"), "UOW durable state stored as one authenticated record"

protector2 = .QueueHmacSha512RecordProtector~new("uow-key", keyHex, .nil, 64)
manager2 = .ObjectQueueManager~new(stateRoot, .QueueGraphPayloadCodec~new, "admin", .nil, protector2)
call assertEqual 0, manager2~depth("P1", "admin")~value["total"], "authenticated replay applies UOW removal"
call assertEqual 1, manager2~depth("P2", "admin")~value["ready"], "authenticated replay applies UOW put"
call assertEqual "after", manager2~browse("P2", "admin")~value~payload, "authenticated UOW payload recovered"
call assertTrue protector2~verifiedRecords >= 4, "authenticated UOW record verified"

say "OBJECT QUEUE FABRIC V0.8 AUTHENTICATED UOW: OK"
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

::requires "ObjectQueueCrypto.cls"
