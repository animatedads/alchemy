assertions = 0
say "OBJECT QUEUE FABRIC V0.8 HMAC KEY ROTATION START"

root = "./tmp_rotation_" || .DateTime~new~microseconds
key1 = "11"~copies(64)
key2 = "22"~copies(64)

writer = .QueueHmacSha512RecordProtector~new("hmac-2026-a", key1, .nil, 64)
manager = .ObjectQueueManager~new(root, .nil, "admin", .nil, writer)
call assertOk manager~createQueue("ROTATE", "PERMANENT", "OPS", 10, "admin"), "create permanent queue"
options = .table~new
options["persistent"] = .true
call assertOk manager~put("ROTATE", "before-rotation", options, "admin"), "write with first key"

call assertTrue writer~rotateKey("hmac-2026-b", key2), "rotate active HMAC key"
call assertEqual "hmac-2026-b", writer~keyId, "new key is active"
call assertTrue expectKeyIdRebindFailure(writer, key1), "active key id cannot be rebound to different material"
call assertOk manager~put("ROTATE", "after-rotation", options, "admin"), "write with second key"

journal = readAllLines(root || "/queue.journal")
call assertTrue journal~items >= 3, "journal contains records across rotation"
first = .QueueRecordCodec~decode(journal[1])
last = .QueueRecordCodec~decode(journal[journal~items])
call assertEqual "hmac-2026-a", first[6], "first record names historical key"
call assertEqual "hmac-2026-b", last[6], "last record names rotated key"

/* Recovery starts from the newest active key but explicitly retains the old
 * key for historical replay. */
readerProtector = .QueueHmacSha512RecordProtector~new("hmac-2026-b", key2, .nil, 64)
call assertTrue readerProtector~addTrustedKey("hmac-2026-a", key1), "old HMAC key retained for replay"
reader = .ObjectQueueManager~new(root, .nil, "admin", .nil, readerProtector)
depth = reader~depth("ROTATE", "admin")
call assertOk depth, "rotated-key journal recovers"
call assertEqual 2, depth~value["ready"], "both historical packages recover"
call assertEqual "hmac-2026-b", readerProtector~keyId, "recovery does not roll active key backwards"

/* New writes continue with the active key after replay. */
call assertOk reader~put("ROTATE", "post-restart", options, "admin"), "post-restart write succeeds"
journal = readAllLines(root || "/queue.journal")
last = .QueueRecordCodec~decode(journal[journal~items])
call assertEqual "hmac-2026-b", last[6], "post-restart record uses active key"

/* Forgetting a historical key is fail-closed: replay cannot silently skip the
 * old authenticated prefix. */
call assertTrue expectMissingHistoricalKeyFailure(root, key2), "missing historical key rejects replay"

say "OBJECT QUEUE FABRIC V0.8 HMAC KEY ROTATION: OK"
say "assertions=" || assertions
exit 0

expectMissingHistoricalKeyFailure: procedure
  use arg root, key2
  signal on syntax name rejected
  protector = .QueueHmacSha512RecordProtector~new("hmac-2026-b", key2, .nil, 64)
  manager = .ObjectQueueManager~new(root, .nil, "admin", .nil, protector)
  signal off syntax
  return .false
rejected:
  signal off syntax
  return .true

expectKeyIdRebindFailure: procedure
  use arg protector, otherKey
  signal on syntax name rejected
  ignore = protector~addTrustedKey("hmac-2026-b", otherKey)
  signal off syntax
  return .false
rejected:
  signal off syntax
  return .true

readAllLines: procedure
  use arg path
  lines = .array~new
  stream = .Stream~new(path)
  status = stream~open("read")
  if status \= "READY:" then return lines
  do while stream~lines > 0
    lines~append(stream~lineIn)
  end
  ignore = stream~close
  return lines

assertOk: procedure expose assertions
  use arg result, label
  assertions += 1
  if \result~ok then do
    say "ASSERT FAILED:" label "code=" result~code "detail=" result~detail
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
