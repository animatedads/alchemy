agentPath = arg(1)
if agentPath = "" then agentPath = "quota_agent.rex"

policy = .AlchemySecurityPolicy~new("DENY")
policy~allow("METHOD", "METERED", "QUOTAVICTIM")

/* Same hosted context, independently metered target objects. */
objectQuotas = .AlchemyExecutionQuotaSet~new
objectQuotas~limitMethod("METERED", "QUOTAVICTIM", 2, "OBJECT_METHOD")
objectManager = .AlchemySecurityManager~new(policy, .nil, .AlchemySecurityRuntimeProfile~observedR13196, objectQuotas)
r1 = .Routine~newFile(agentPath)
r1~setSecurityManager(objectManager)
signal on syntax name objectDenied
ignore = r1~call("OBJECT")
signal off syntax
raise syntax 88.900 array("object quota unexpectedly allowed fifth call")
objectDenied:
  signal off syntax
call assertEq 5, objectManager~auditEvents~items, "five METHOD checkpoint attempts"
last = objectManager~auditEvents[5]
call assertFalse last["allowed"], "fifth call denied"
call assertEq "execution quota exhausted", last["reason"], "quota deny reason"
q = last["quota"]
call assertEq 1, q~items, "one matching object quota"
call assertEq 2, q[1]["limit"], "object quota limit"
call assertEq 2, q[1]["used"], "object quota used before denial"
call assertEq 0, q[1]["remaining"], "object quota remaining"

/* CONTEXT quota belongs to the manager/execution context, not either object. */
contextQuotas = .AlchemyExecutionQuotaSet~new
contextQuotas~limitMethod("METERED", "QUOTAVICTIM", 3, "CONTEXT")
contextManager = .AlchemySecurityManager~new(policy, .nil, .AlchemySecurityRuntimeProfile~observedR13196, contextQuotas)
r2 = .Routine~newFile(agentPath)
r2~setSecurityManager(contextManager)
signal on syntax name contextDenied
ignore = r2~call("CONTEXT")
signal off syntax
raise syntax 88.900 array("context quota unexpectedly allowed fourth call")
contextDenied:
  signal off syntax
call assertEq 4, contextManager~auditEvents~items, "four context attempts"
last2 = contextManager~auditEvents[4]
call assertFalse last2["allowed"], "fourth context call denied"
call assertEq 3, last2["quota"][1]["used"], "three context calls consumed"

say "PASS test_security_quota"
exit 0

assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed: " || message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return

::requires "AlchemyObjects.cls"
