keyRing = .CryptoMacKeyRing~new
keyRing~addKey("expiry-test", "00112233445566778899aabbccddeeff")
authority = .AlchemyCapabilityAuthority~new(keyRing)
objectId = "object-1"
operation = "DOIT"
purpose = "TEST"
day = date("B") + 0
secondOfDay = time("S") + 0

if secondOfDay > 0 then expiredStamp = day || ":" || (secondOfDay - 1)
else expiredStamp = (day - 1) || ":86399"
expired = authority~issue("alice", objectId, operation, purpose, expiredStamp)
call assertFalse authority~verify(expired, objectId, operation, purpose, .false), "past capability rejected"

futureSecond = secondOfDay + 60
futureDay = day + (futureSecond % 86400)
futureSecond = futureSecond // 86400
futureStamp = futureDay || ":" || futureSecond
future = authority~issue("alice", objectId, operation, purpose, futureStamp)
call assertTrue authority~verify(future, objectId, operation, purpose, .false), "future capability accepted"

short = authority~issueForSeconds("alice", objectId, operation, purpose, 30)
call assertTrue authority~verify(short, objectId, operation, purpose, .false), "relative lifetime capability accepted"

/* Changing a signed expiry without recomputing its MAC must fail. */
tamperSecond = secondOfDay + 3600
tamperDay = day + (tamperSecond % 86400)
tamperSecond = tamperSecond // 86400
tamperedStamp = tamperDay || ":" || tamperSecond
tampered = .AlchemyCapability~new(future~capabilityId, future~subject, future~objectId, future~operation, future~purpose, future~issuedAt, tamperedStamp, future~nonce, future~algorithm, future~keyId, future~tag)
call assertFalse authority~verify(tampered, objectId, operation, purpose, .false), "tampered expiry rejected"

signal on syntax name invalidExpiry
bad = authority~issue("alice", objectId, operation, purpose, "tomorrow")
raise syntax 88.900 array("nonnumeric capability expiry accepted")
invalidExpiry:
signal off syntax

say "PASS test_capability_expiry"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed: " || message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed: " || message)
  return

::requires "AlchemyObjects.cls"
