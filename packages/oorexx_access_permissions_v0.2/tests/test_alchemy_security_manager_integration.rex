agentPath = arg(1)
if agentPath = "" then agentPath = "protected_method_agent.rex"
now = .DateTime~new
subjectId = "STAFF:BOB"
principal = .AccessPrincipal~new(subjectId, "bob-key-1")~seal

target = .PaymentTarget~new
objectId = target~alchemyObjectId
snapshot = .SecuritySnapshot~new("SNAP:SM", subjectId, now)~seal
framework = .SecurityPolicyFramework~new("METHOD-SECURITY", "1", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")~seal
resolver = .InvocationSecurityEffectResolver~new(subjectId, snapshot, framework)

policy = .PermissionPolicy~new("SM-PERMISSIONS", "1", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")
policy~addRule(.PermissionRule~new("EXACT-RELEASE", 100, "ALLOW", subjectId, objectId, "PAYMENTTARGET", "RELEASEPAYMENT", "ALLOW", framework~semanticIdentity)~seal)
policy~seal
ring = .CryptoMacKeyRing~new
ring~addKey("sm-permission-proof", "ffeeddccbbaa00998877665544332211")
signer = .AccessPermissionsSigner~new(ring, "sm-permission-proof")
permissionAuthority = .PermissionAuthority~new(signer)
fallback = .AlchemySecurityPolicy~new("DENY")
adapter = .AlchemyPermissionPolicyAdapter~new(principal, policy, permissionAuthority, resolver, fallback)
manager = .AlchemySecurityManager~new(adapter, .nil, .AlchemySecurityRuntimeProfile~observedR13196)
routine = .Routine~newFile(agentPath)
routine~setSecurityManager(manager)
value = routine~call(target)
call assertEq 7, value, "Security Manager enforced permission and continued method"
call assertEq 1, manager~auditEvents~items, "one manager checkpoint"
call assertTrue manager~auditEvents[1]["allowed"], "manager allowed exact method"
call assertEq 1, adapter~decisionEnvelopes~items, "permission evidence retained"
call assertTrue adapter~decisionEnvelopes[1]~verifyProof(ring), "permission evidence is cryptographically verifiable"
call assertEq objectId, adapter~decisionEnvelopes[1]~decision~objectId, "exact object bound"
call assertEq "RELEASEPAYMENT", adapter~decisionEnvelopes[1]~decision~methodName, "exact method bound"

/* Same class, different object: policy does not authorize it. */
target2 = .PaymentTarget~new
routine2 = .Routine~newFile(agentPath)
routine2~setSecurityManager(manager)
signal on syntax name denied
ignore = routine2~call(target2)
signal off syntax
raise syntax 88.900 array("different object unexpectedly authorized")
denied:
  signal off syntax
call assertEq 2, adapter~decisionEnvelopes~items, "denied permission evidence retained"
call assertFalse adapter~decisionEnvelopes[2]~decision~allowed, "different exact object denied"
call assertEq 0, target2~total, "denied method body did not run"
say "PASS test_alchemy_security_manager_integration"
exit 0

::class InvocationSecurityEffectResolver public
::method init
  expose expectedSubject snapshot framework counter
  use strict arg expectedSubjectArg, snapshotArg, frameworkArg
  expectedSubject = expectedSubjectArg
  snapshot = snapshotArg
  framework = frameworkArg
  counter = 0
::method assessmentFor
  expose expectedSubject snapshot framework counter
  use strict arg principalId, obj, methodName, args, info
  if principalId <> expectedSubject then return .SecurityResult~failure("SUBJECT_MISMATCH")
  counter += 1
  if obj~hasMethod("ALCHEMYOBJECTID") then objectId = obj~alchemyObjectId
  else objectId = obj~identityHash~string
  action = .SecurityActionSurface~new("ACT:SM:" || counter, principalId, "METHOD_INVOCATION", .DateTime~new, "NORMAL", methodName)
  action~putAttribute("OBJECT_ID", objectId)
  action~putAttribute("METHOD", methodName)
  return .SecurityEffectEngine~new~evaluate(action~seal, snapshot, framework)

::class PaymentTarget subclass AlchemyObject
::attribute total get
::method init
  expose total
  total = 0
  forward class (super) array (.nil, .nil, .nil) continue
::method releasePayment protected
  expose total
  use strict arg amount
  total += amount
  return total

::requires "TestSupport.cls"
::requires "AccessPermissions.cls"
::requires "AlchemyAccessPermissionsAdapter.cls"
::requires "AlchemyObject.cls"
