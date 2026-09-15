keyRing = .CryptoMacKeyRing~new
keyRing~addKey("locked-mac", "00112233445566778899aabbccddeeff")
authority = .AlchemyCapabilityAuthority~new(keyRing)
provider = .AlchemyInMemoryLockedMethodKeyProvider~new(keyRing, authority)
provider~addKey("locked-source", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
vault = .AlchemyLockedMethodVault~new(provider)
sealer = .AlchemyMacSealer~new(keyRing)
obj = .LockedSubject~new(sealer, authority, vault)

source = .array~new
source~append("expose total")
source~append("use strict arg n")
source~append("total = total + n")
source~append("return total")
install = obj~defineCryptoLockedMethod("SECRETADD", source, "LOCKED:EXECUTE", 0, .true, "locked-source")
call assertTrue install~ok, "locked method installed"
call assertEq "LOCKED_METHOD_INSTALLED", install~code, "install code"
call assertTrue obj~hasMethod("SECRETADD"), "protected stub exists"

publicLocked = obj~sealPublicIntrospection
call assertFalse publicLocked~payload~hasIndex("locked_methods"), "public introspection hides locked method registry"
customerIntrospectionCap = authority~issueForSeconds("test", obj~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER", 60)
customerLocked = obj~sealedIntrospection("CUSTOMER", customerIntrospectionCap)
call assertFalse customerLocked~payload~hasIndex("locked_methods"), "customer introspection hides locked method registry"

describeCap = authority~issueForSeconds("test", obj~alchemyObjectId, "CRYPTOLOCKEDMETHODDESCRIPTIONS", "LOCKED:DESCRIBE", 60)
safe = obj~cryptoLockedMethodDescriptions(describeCap)
call assertEq 1, safe~items, "one safe locked method description"
call assertEq "SECRETADD", safe[1]["method_name"], "safe description method"
call assertFalse safe[1]~hasIndex("ciphertext_hex"), "safe description does not expose ciphertext"

/* The method source must not be visible in the registered description. */
text = safe[1]~string
call assertEq 0, pos("total = total + n", text), "plaintext absent from safe record"

cap1 = authority~issueForSeconds("test", obj~alchemyObjectId, "SECRETADD", "LOCKED:EXECUTE", 60)
call assertEq 7, obj~secretAdd(7, cap1), "first locked execution"
call assertFalse obj~hasMethod("__ALCHEMY_LOCKED_ACTIVE_1"), "first transient operating method removed after success"
cap2 = authority~issueForSeconds("test", obj~alchemyObjectId, "SECRETADD", "LOCKED:EXECUTE", 60)
call assertEq 12, obj~secretAdd(5, cap2), "second locked execution preserves object variable scope"
call assertFalse obj~hasMethod("__ALCHEMY_LOCKED_ACTIVE_2"), "second transient operating method removed after success"

/* Reusing the same capability is rejected by the object-side independent gate. */
signal on syntax name replayBlocked
ignore = obj~secretAdd(1, cap2)
signal off syntax
raise syntax 88.900 array("locked capability replay unexpectedly succeeded")
replayBlocked:
  signal off syntax

/* Failed business code still removes the transient operating alias. */
failSource = .array~of("use strict arg n", "raise syntax 88.900 array('business failure ' || n)")
install2 = obj~defineCryptoLockedMethod("SECRETFAIL", failSource, "LOCKED:FAILTEST", 0, .true, "locked-source")
call assertTrue install2~ok, "failing locked method installed"
cap3 = authority~issueForSeconds("test", obj~alchemyObjectId, "SECRETFAIL", "LOCKED:FAILTEST", 60)
signal on syntax name businessFailed
ignore = obj~secretFail(9, cap3)
signal off syntax
raise syntax 88.900 array("failing locked method unexpectedly returned")
businessFailed:
  signal off syntax
call assertFalse obj~hasMethod("__ALCHEMY_LOCKED_ACTIVE_4"), "transient operating method removed after business failure"

auditCap = authority~issueForSeconds("test", obj~alchemyObjectId, "CRYPTOLOCKEDMETHODAUDIT", "LOCKED:AUDIT", 60)
audit = obj~cryptoLockedMethodAudit(auditCap)
call assertEq 8, audit~items, "two successes plus replay failure plus business failure produce paired audit events"
call assertEq "FAIL", audit[audit~items]["outcome"], "failure audit outcome"

internalCap = authority~issueForSeconds("auditor", obj~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:INTERNAL", 60)
internalLocked = obj~sealedIntrospection("INTERNAL", internalCap)
call assertTrue internalLocked~payload~hasIndex("locked_methods"), "internal introspection includes safe locked registry"
call assertEq 2, internalLocked~payload["locked_methods"]~items, "internal registry contains both locked methods"
call assertTrue internalLocked~payload~hasIndex("locked_method_audit"), "internal introspection includes locked audit"

/* This test deliberately defines plaintext from source literals.  A package SOURCE snapshot
 * therefore contains those build-time literals; production hosted code should install only
 * a prebuilt AlchemyLockedMethodRecord. */

say "PASS test_locked_method"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed: " || message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed: " || message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return

::class LockedSubject subclass AlchemyObject
::method init
  expose total
  use strict arg sealer, authority, vault
  total = 0
  forward class (super) array (.nil, sealer, authority) continue
  self~configureLockedMethodVault(vault)
  self~registerStateVariable("total", "CUSTOMER", "running total modified only by locked method")

::requires "AlchemyObjects.cls"
