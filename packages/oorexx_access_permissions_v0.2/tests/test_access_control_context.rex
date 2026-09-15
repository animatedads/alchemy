now = .DateTime~new
policy = .AccessControlPolicy~new("HQ-CONTEXT", "2", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "facilities")
rule = .AccessControlRule~new("GREEN-BADGE-CORP", 100, "ALLOW", "STAFF:*", "HQ", "FRONT_DOOR")
call assertTrue rule~requireAttribute("badge", "green"), "badge requirement accepted"
call assertTrue rule~requireAttribute("network", "corp-*"), "network requirement accepted"
rule~seal
call assertFalse rule~requireAttribute("badge", "*"), "sealed rule immutable"
policy~addRule(rule)
policy~seal

authority = .AccessControlAuthority~new

good = .AccessControlRequest~new("CTX-1", "STAFF:BOB", "HQ", "FRONT_DOOR", now)
good~putAttribute("badge", "GREEN")
good~putAttribute("network", "CORP-LONDON")
good~seal
goodResult = authority~decide(good, policy)
call assertTrue goodResult~ok, "context decision produced"
call assertTrue goodResult~value~decision~allowed, "all required context attributes allow entry"
call assertEq "GREEN-BADGE-CORP", goodResult~value~decision~ruleId, "context rule selected"

missing = .AccessControlRequest~new("CTX-2", "STAFF:BOB", "HQ", "FRONT_DOOR", now)
missing~putAttribute("badge", "GREEN")
missing~seal
missingResult = authority~decide(missing, policy)
call assertFalse missingResult~value~decision~allowed, "missing required context defaults deny"

wrong = .AccessControlRequest~new("CTX-3", "STAFF:BOB", "HQ", "FRONT_DOOR", now)
wrong~putAttribute("badge", "RED")
wrong~putAttribute("network", "CORP-LONDON")
wrong~seal
wrongResult = authority~decide(wrong, policy)
call assertFalse wrongResult~value~decision~allowed, "wrong required context defaults deny"

/* Returned requirements are a defensive copy; policy cannot be altered through it. */
copy = rule~requiredAttributes
copy["BADGE"] = "*"
stillWrong = authority~decide(wrong, policy)
call assertFalse stillWrong~value~decision~allowed, "requirements copy cannot mutate sealed rule"

/* Canonical identity is insertion-order independent. */
rule2 = .AccessControlRule~new("GREEN-BADGE-CORP", 100, "ALLOW", "STAFF:*", "HQ", "FRONT_DOOR")
rule2~requireAttribute("network", "corp-*")
rule2~requireAttribute("badge", "green")
rule2~seal
call assertEq rule~canonicalText, rule2~canonicalText, "required-attribute canonicalization deterministic"

/* Request attributes are snapshotted as strings at insertion time.  A mutable
 * source object cannot alter a sealed request's canonical identity later. */
mutable = .MutableAttributeValue~new("GREEN")
stable = .AccessControlRequest~new("CTX-4", "STAFF:BOB", "HQ", "FRONT_DOOR", now)
stable~putAttribute("badge", mutable)
stable~putAttribute("network", "CORP-LONDON")
stable~seal
identityBefore = stable~semanticIdentity
mutable~value = "RED"
call assertEq identityBefore, stable~semanticIdentity, "sealed request attribute snapshot is stable"
call assertTrue authority~decide(stable, policy)~value~decision~allowed, "mutating source object cannot alter sealed request"

say "PASS test_access_control_context"
::class MutableAttributeValue public
::attribute value
::method init
  expose value
  use strict arg valueArg
  value = valueArg
::method string
  expose value
  return value~string
::requires "TestSupport.cls"
::requires "AccessPermissions.cls"
