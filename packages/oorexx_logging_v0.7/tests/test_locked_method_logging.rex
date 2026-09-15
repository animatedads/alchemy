ring = .CryptoMacKeyRing~new
ring~addKey("locked-log-mac", "00112233445566778899aabbccddeeff")
authority = .AlchemyCapabilityAuthority~new(ring)
provider = .AlchemyInMemoryLockedMethodKeyProvider~new(ring, authority)
provider~addKey("locked-log-source", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
vault = .AlchemyLockedMethodVault~new(provider)
sealer = .AlchemyMacSealer~new(ring)
obj = .LockedLoggingSubject~new(sealer, authority, vault)

source = .array~new
source~append("use strict arg log, detail")
source~append("log~log(log~WARN, detail)")
source~append("return detail")
installed = obj~defineCryptoLockedMethod("SECRETLOG", source, "LOCKED:LOG", 0, .true, "locked-log-source")
call assertTrue installed~ok, "locked logging method installed"

service = .LogService~new("locked-log-service")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
payload1 = .LockedPayload~new("disabled")

/* No rule: locked code still receives a valid logger object, but it is the
 * zero-work singleton and emits nothing. */
log = service~loggerFor(obj, "SECRETLOG", .array~of(payload1), .Log~INTERNAL)
call assertFalse log~active, "locked method receives null logger when inactive"
cap1 = authority~issueForSeconds("test", obj~alchemyObjectId, "SECRETLOG", "LOCKED:LOG", 60)
returned = obj~secretLog(log, payload1, cap1)
call assertTrue returned == payload1, "locked body returns original structured payload"
call assertEq 0, mem~count, "inactive locked logging emits nothing"

rule = .LogRule~new("locked-active", "locked", "LockedLoggingSubject", "SECRETLOG", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~WARN, .nil, .array~of("memory"), .array~of(.Log~BODY))
service~addRule(rule)
payload2 = .LockedPayload~new("active")
log = service~loggerFor(obj, "SECRETLOG", .array~of(payload2), .Log~INTERNAL)
call assertTrue log~active, "locked method receives active emitter when rule matches"
cap2 = authority~issueForSeconds("test", obj~alchemyObjectId, "SECRETLOG", "LOCKED:LOG", 60)
returned = obj~secretLog(log, payload2, cap2)
call assertTrue returned == payload2, "active locked body result preserved"
call assertEq 1, mem~count, "locked body emitted exactly one explicit event"
event = mem~events[1]
call assertTrue event~payload == payload2, "locked log event retains payload object identity"
call assertEq "SECRETLOG", event~methodName, "semantic locked method identity retained"
call assertEq "WARN", event~levelName, "emitter-local WARN constant works inside transient method"

say "PASS test_locked_method_logging"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class LockedPayload
::attribute label get
::method init
  expose label
  use strict arg label
  label = label

::class LockedLoggingSubject subclass AlchemyObject
::method init
  use strict arg sealer, authority, vault
  forward class (super) array (.nil, sealer, authority) continue
  self~configureLockedMethodVault(vault)

::requires "LoggingCore.cls"
::requires "AlchemyObjects.cls"
