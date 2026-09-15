agentPath = arg(1)
if agentPath = "" then agentPath = "locked_method_agent.rex"

keyRing = .CryptoMacKeyRing~new
keyRing~addKey("locked-sm-mac", "00112233445566778899aabbccddeeff")
authority = .AlchemyCapabilityAuthority~new(keyRing)
provider = .AlchemyInMemoryLockedMethodKeyProvider~new(keyRing, authority)
provider~addKey("locked-sm-source", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
vault = .AlchemyLockedMethodVault~new(provider)
sealer = .AlchemyMacSealer~new(keyRing)
obj = .HostLocked~new(sealer, authority, vault)
source = .array~of("expose total", "use strict arg n", "total=total+n", "return total")
installed = obj~defineCryptoLockedMethod("SECRETADD", source, "LOCKED:EXECUTE", 2, .true, "locked-sm-source")
call assertTrue installed~ok, "locked method installed before customer routine"

/* Security Manager verifies but does not consume: the vault is the independent
 * consuming gate.  This allows both gates to validate the same single-use token. */
policy = .AlchemySecurityPolicy~new("DENY")
policy~requireCapability("SECRETADD", "HOSTLOCKED", "LOCKED:EXECUTE", 2, .false)
manager = .AlchemySecurityManager~new(policy, authority, .AlchemySecurityRuntimeProfile~observedR13196)
r = .Routine~newFile(agentPath)
r~setSecurityManager(manager)
cap = authority~issueForSeconds("customer", obj~alchemyObjectId, "SECRETADD", "LOCKED:EXECUTE", 60)
value = r~call(obj, 4, cap)
call assertEq 4, value, "security-manager + vault gated execution"
call assertEq 1, manager~auditEvents~items, "one protected-method checkpoint"
call assertTrue manager~auditEvents[1]["allowed"], "security manager authorized wrapper"

/* Same token still passes the non-consuming SM check, but the vault rejects it
 * because the independent key-release gate consumed it on first execution. */
r2 = .Routine~newFile(agentPath)
r2~setSecurityManager(manager)
signal on syntax name replayDenied
ignore = r2~call(obj, 3, cap)
signal off syntax
raise syntax 88.900 array("replayed locked capability unexpectedly executed")
replayDenied:
  signal off syntax
call assertEq 2, manager~auditEvents~items, "replay reached second manager checkpoint"
call assertTrue manager~auditEvents[2]["allowed"], "SM layer independently verified replay token without consuming"
call assertEq 4, obj~currentTotal, "business method did not run on replay"

say "PASS test_locked_method_security_manager"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed: " || message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return

::class HostLocked subclass AlchemyObject
::method init
  expose total
  use strict arg sealer, authority, vault
  total = 0
  forward class (super) array (.nil, sealer, authority) continue
  self~configureLockedMethodVault(vault)
::method currentTotal
  expose total
  return total

::requires "AlchemyObjects.cls"
