assertions = 0
say "OBJECT QUEUE FABRIC V0.8 TORN-TAIL RECOVERY START"

root = "./tmp_recovery_" || .DateTime~new~microseconds
key = "33"~copies(64)
writer = .QueueHmacSha512RecordProtector~new("recovery-key", key, .nil, 64)
manager = .ObjectQueueManager~new(root, .nil, "admin", .nil, writer)
call assertOk manager~createQueue("RECOVER", "PERMANENT", "OPS", 10, "admin"), "create permanent queue"
options = .table~new
options["persistent"] = .true
call assertOk manager~put("RECOVER", "survivor", options, "admin"), "write durable package"

journalPath = root || "/queue.journal"
validCount = readAllLines(journalPath)~items
call appendTornFragment journalPath, "QAUTH2|partial-record-without-newline"
call assertTrue \fileEndsWithLineBreak(journalPath), "fixture is physically unterminated"

call assertTrue expectStrictFailure(root, key), "STRICT recovery rejects malformed tail"

repairProtector = .QueueHmacSha512RecordProtector~new("recovery-key", key, .nil, 64)
repaired = .ObjectQueueManager~new(root, .nil, "admin", .nil, repairProtector, "REPAIR_TORN_TAIL")
call assertTrue repaired~recoveryWarnings~items >= 1, "repair is surfaced as a recovery warning"
call assertTrue repaired~recoveryWarnings[1]~startsWith("REPAIRED_TORN_TAIL|JOURNAL|"), "warning identifies repaired journal tail"
call assertEqual validCount, readAllLines(journalPath)~items, "only torn fragment was removed"
call assertTrue fileEndsWithLineBreak(journalPath), "repaired journal is line-terminated"

depth = repaired~depth("RECOVER", "admin")
call assertOk depth, "queue remains usable after repair"
call assertEqual 1, depth~value["ready"], "committed package survives tail repair"
call assertEqual "survivor", repaired~browse("RECOVER", "admin")~value~payload, "surviving payload is intact"

/* The repaired file must subsequently pass strict recovery. */
strictProtector = .QueueHmacSha512RecordProtector~new("recovery-key", key, .nil, 64)
strictAgain = .ObjectQueueManager~new(root, .nil, "admin", .nil, strictProtector)
call assertOk strictAgain~depth("RECOVER", "admin"), "strict recovery succeeds after explicit repair"

/* A complete authenticated record with its final newline lost is not thrown
 * away.  STRICT rejects the framing defect; repair mode normalises the line
 * terminator while preserving the authenticated record and its package. */
root2 = "./tmp_recovery_valid_" || .DateTime~new~microseconds
writer2 = .QueueHmacSha512RecordProtector~new("recovery-key", key, .nil, 64)
manager2 = .ObjectQueueManager~new(root2, .nil, "admin", .nil, writer2)
call assertOk manager2~createQueue("VALIDTAIL", "PERMANENT", "OPS", 10, "admin"), "create second permanent queue"
call assertOk manager2~put("VALIDTAIL", "valid-tail-payload", options, "admin"), "write complete final record"
call removeFinalLineBreak root2 || "/queue.journal"
call assertTrue \fileEndsWithLineBreak(root2 || "/queue.journal"), "complete record fixture lacks final line break"
call assertTrue expectStrictFailure(root2, key), "STRICT rejects valid but unterminated final record"
normaliseProtector = .QueueHmacSha512RecordProtector~new("recovery-key", key, .nil, 64)
normalised = .ObjectQueueManager~new(root2, .nil, "admin", .nil, normaliseProtector, "REPAIR_TORN_TAIL")
call assertTrue normalised~recoveryWarnings~items >= 1, "valid tail normalisation is reported"
call assertTrue normalised~recoveryWarnings[1]~startsWith("NORMALIZED_UNTERMINATED_VALID_TAIL|JOURNAL|"), "normalisation warning is specific"
call assertEqual "valid-tail-payload", normalised~browse("VALIDTAIL", "admin")~value~payload, "valid final record is preserved"
call assertTrue fileEndsWithLineBreak(root2 || "/queue.journal"), "normalised journal is append-safe"

say "OBJECT QUEUE FABRIC V0.8 TORN-TAIL RECOVERY: OK"
say "assertions=" || assertions
exit 0

expectStrictFailure: procedure
  use arg root, key
  signal on syntax name rejected
  protector = .QueueHmacSha512RecordProtector~new("recovery-key", key, .nil, 64)
  manager = .ObjectQueueManager~new(root, .nil, "admin", .nil, protector)
  signal off syntax
  return .false
rejected:
  signal off syntax
  return .true

appendTornFragment: procedure
  use arg path, text
  stream = .Stream~new(path)
  status = stream~open("write append")
  if status \= "READY:" then raise syntax 88.900 array("Cannot append torn fixture")
  ignore = stream~charOut(text)
  ignore = stream~close
  return

removeFinalLineBreak: procedure
  use arg path
  stream = .Stream~new(path)
  status = stream~open("read")
  if status \= "READY:" then raise syntax 88.900 array("Cannot read line-break fixture")
  count = stream~chars
  bytes = stream~charIn(, count)
  ignore = stream~close
  if bytes~length = 0 then return
  last = bytes~right(1)
  if last = "0a"x | last = "0d"x then bytes = bytes~left(bytes~length - 1)
  stream = .Stream~new(path)
  status = stream~open("write replace")
  if status \= "READY:" then raise syntax 88.900 array("Cannot rewrite line-break fixture")
  ignore = stream~charOut(bytes)
  ignore = stream~close
  return

fileEndsWithLineBreak: procedure
  use arg path
  stream = .Stream~new(path)
  status = stream~open("read")
  if status \= "READY:" then return .false
  count = stream~chars
  if count = 0 then do
    ignore = stream~close
    return .true
  end
  last = stream~charIn(count, 1)
  ignore = stream~close
  if last = "0a"x then return .true
  if last = "0d"x then return .true
  return .false

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
