assertions = 0

say "OBJECT QUEUE FABRIC V0.8 HMAC DURABILITY START"

/* Cross-implementation HMAC fixture.  This expected value was generated with
 * Python hmac.new(key, message, hashlib.sha512), not by this ooRexx class. */
hmacKey = "0b"~copies(20)
fixtureProtector = .QueueHmacSha512RecordProtector~new("fixture-key", hmacKey, .nil, 64)
fixtureLine = fixtureProtector~protect("JOURNAL", "hello")
fixtureFields = .QueueRecordCodec~decode(fixtureLine)
call assertEqual "QAUTH2", fixtureFields[1], "authenticated record uses QAUTH2 envelope"
call assertEqual "7f44251f4f51689fce272bc2f658f4e104056ca97a7862eb3d22f44157cb7277" ||,
                 "e386453f695fb01ed8cfb3525e896c3c1ff392b7b2239e9967cc7d2c6bad0517", fixtureFields[5], "SHA-512 chain fixture"
call assertEqual "d20981b0697c5d6527a2878e7b122c2b2b698df77e5cde617768ce041cfa00b2" ||,
                 "20203920d3e5d6bface66ad2888bc8b0e0f575a9a694d36e6c1d5900900d437d", fixtureFields[7], "HMAC-SHA-512 fixture"

/* Queue integration uses HMAC for every record.  An external/HSM signer can be
 * plugged in later without changing ObjectQueueManager semantics. */
stateRoot = "./tmp_crypto_" || .DateTime~new~microseconds
queueKey = "00112233445566778899aabbccddeeff" ||,
           "102132435465768798a9bacbdcedfe0f" ||,
           "112233445566778899aabbccddeeff00" ||,
           "ffeeddccbbaa99887766554433221100"
protector = .QueueHmacSha512RecordProtector~new("queue-hmac-v1", queueKey, .nil, 64)
manager = .ObjectQueueManager~new(stateRoot, .nil, "admin", .nil, protector)
call assertOk manager~createQueue("SECURE", "PERMANENT", "OPS", 10, "admin"), "create authenticated permanent queue"
options = .table~new
options["persistent"] = .true
options["priority"] = 7
headers = .table~new
headers["kind"] = "authenticated-demo"
options["headers"] = headers
putResult = manager~put("SECURE", "important-work-object", options, "admin")
call assertOk putResult, "persistent package written through authenticated journal"
putResult2 = manager~put("SECURE", "second-work-object", options, "admin")
call assertOk putResult2, "second persistent package extends authenticated chain"
call assertTrue protector~authenticatedRecords > 0, "protector authenticated durable records"
call assertTrue manager~durableStore~recordProtector == protector, "durable store owns supplied protector"

journalPath = stateRoot || "/queue.journal"
trafficPath = stateRoot || "/traffic.log"
firstJournal = firstLine(journalPath)
firstTraffic = firstLine(trafficPath)
call assertTrue firstJournal~startsWith("QAUTH2|"), "journal is authenticated envelope"
call assertTrue firstTraffic~startsWith("QAUTH2|"), "traffic log is authenticated envelope"
call assertTrue firstJournal~pos("QCREATE") = 0, "inner journal operation is not exposed as plaintext tag"

/* Restart with the same HMAC trust root must authenticate before replay. */
protector2 = .QueueHmacSha512RecordProtector~new("queue-hmac-v1", queueKey, .nil, 64)
reader = .ObjectQueueManager~new(stateRoot, .nil, "admin", .nil, protector2)
call assertTrue protector2~verifiedRecords > 0, "recovery authenticated durable records"
depthResult = reader~depth("SECURE", "admin")
call assertOk depthResult, "authenticated manager can inspect recovered queue"
call assertEqual 2, depthResult~value["ready"], "authenticated durable packages recovered"
call assertEqual "important-work-object", reader~browse("SECURE", "admin")~value~payload, "payload survives authenticated recovery"

/* Recovery with the wrong symmetric trust root fails closed. */
wrongKey = "ff"~copies(64)
call assertTrue expectWrongHmacFailure(stateRoot, wrongKey), "wrong HMAC key fails recovery"

/* Single-nibble mutation must be detected before queue state is published. */
backupPath = journalPath || ".valid"
call copyTextFile journalPath, backupPath
call mutateLastHexNibble journalPath
call assertTrue expectRecoveryFailure(stateRoot, queueKey), "single-nibble journal tamper fails closed"
call copyTextFile backupPath, journalPath

/* Interior deletion breaks sequence/hash-chain continuity. */
call copyTextFile journalPath, backupPath
call deleteSecondLine journalPath
call assertTrue expectRecoveryFailure(stateRoot, queueKey), "interior journal record deletion fails closed"
call copyTextFile backupPath, journalPath

/* Unsigned v0.1 journals are never silently accepted by authenticated mode. */
plainRoot = "./tmp_crypto_plain_" || .DateTime~new~microseconds
plainManager = .ObjectQueueManager~new(plainRoot, .nil, "admin")
call assertOk plainManager~createQueue("PLAIN", "PERMANENT", "OPS", 5, "admin"), "create legacy plaintext queue"
call assertTrue expectRecoveryFailure(plainRoot, queueKey), "authenticated mode rejects unsigned legacy journal"

say "OBJECT QUEUE FABRIC V0.8 HMAC DURABILITY: OK"
say "assertions=" || assertions
exit 0

expectRecoveryFailure: procedure
  use arg root, hmacKey
  signal on syntax name recoveryFailed
  protector = .QueueHmacSha512RecordProtector~new("queue-hmac-v1", hmacKey, .nil, 64)
  manager = .ObjectQueueManager~new(root, .nil, "admin", .nil, protector)
  signal off syntax
  return .false
recoveryFailed:
  signal off syntax
  return .true

expectWrongHmacFailure: procedure
  use arg root, hmacKey
  return expectRecoveryFailure(root, hmacKey)

firstLine: procedure
  use arg path
  stream = .Stream~new(path)
  status = stream~open("read")
  if status \= "READY:" then return ""
  line = stream~lineIn
  closeStatus = stream~close
  return line

copyTextFile: procedure
  use arg sourcePath, destinationPath
  lines = readAllLines(sourcePath)
  call writeAllLines destinationPath, lines
  return

mutateLastHexNibble: procedure
  use arg path
  lines = readAllLines(path)
  if lines~items = 0 then return
  line = lines[lines~items]
  last = line~right(1)~lower
  if last = "0" then replacement = "1"
  else replacement = "0"
  lines[lines~items] = line~left(line~length - 1) || replacement
  call writeAllLines path, lines
  return

deleteSecondLine: procedure
  use arg path
  lines = readAllLines(path)
  if lines~items < 3 then return
  kept = .array~new
  do i = 1 to lines~items
    if i = 2 then iterate
    kept~append(lines[i])
  end
  call writeAllLines path, kept
  return

readAllLines: procedure
  use arg path
  lines = .array~new
  stream = .Stream~new(path)
  status = stream~open("read")
  if status \= "READY:" then return lines
  do while stream~lines > 0
    lines~append(stream~lineIn)
  end
  closeStatus = stream~close
  return lines

writeAllLines: procedure
  use arg path, lines
  stream = .Stream~new(path)
  status = stream~open("write replace")
  if status \= "READY:" then raise syntax 88.900 array("Cannot rewrite test fixture " || path || ": " || status)
  do line over lines
    ignore = stream~lineOut(line)
  end
  closeStatus = stream~close
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

::requires "ObjectQueueCrypto.cls"
