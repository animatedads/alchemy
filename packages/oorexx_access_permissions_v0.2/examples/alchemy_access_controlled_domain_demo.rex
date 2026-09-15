/* Access Control gets Bob into TREASURY; Permission + Security Manager still
 * decides whether the exact protected method may execute. */
agentPath = arg(1)
if agentPath = "" then agentPath = "protected_demo_agent.rex"
now = .DateTime~new
subject = "STAFF:BOB"

authRing = .CryptoMacKeyRing~new
authRing~addKey("bob-auth", "00112233445566778899aabbccddeeff")
principal = .AccessPrincipal~new(subject, "bob-auth")~seal
verifier = .AuthenticationVerifier~new(authRing)

accessProofRing = .CryptoMacKeyRing~new
accessProofRing~addKey("access-proof", "102132435465768798a9bacbdcedfe0f")
accessAuthority = .AccessControlAuthority~new(.AccessPermissionsSigner~new(accessProofRing), verifier)

permissionProofRing = .CryptoMacKeyRing~new
permissionProofRing~addKey("permission-proof", "ffeeddccbbaa99887766554433221100")
permissionAuthority = .PermissionAuthority~new(.AccessPermissionsSigner~new(permissionProofRing))

entryPolicy = .AccessControlPolicy~new("TREASURY-ENTRY", "2", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "facilities")
entryRule = .AccessControlRule~new("GREEN-BADGE", 100, "ALLOW", subject, "TREASURY", "FRONT_DOOR")
entryRule~requireAttribute("BADGE", "GREEN")
entryPolicy~addRule(entryRule~seal)
entryPolicy~seal

target = .PaymentTarget~new
snapshot = .SecuritySnapshot~new("SNAP:DEMO", subject, now)~seal
framework = .SecurityPolicyFramework~new("DEMO-SECURITY", "1", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")~seal
resolver = .DemoResolver~new(subject, snapshot, framework)

methodPolicy = .PermissionPolicy~new("TREASURY-METHODS", "2", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")
methodPolicy~addRule(.PermissionRule~new("EXACT-RELEASE", 100, "ALLOW", subject, target~alchemyObjectId, "PAYMENTTARGET", "RELEASEPAYMENT", "ALLOW", framework~semanticIdentity)~seal)
methodPolicy~seal

domain = .AlchemyAccessControlledDomain~new("TREASURY", entryPolicy, accessAuthority, methodPolicy, permissionAuthority, resolver, .AlchemySecurityPolicy~new("DENY"), .AlchemySecurityRuntimeProfile~observedR13196)
entry = .AccessControlRequest~new("ENTRY-DEMO", subject, "TREASURY", "FRONT_DOOR", now)
entry~putAttribute("BADGE", "GREEN")
entry~seal
assertion = .AuthenticationAssertion~issue(principal, authRing, "ACCESS_CONTROL", entry~semanticIdentity, "demo-entry")
result = domain~enter(entry, principal, assertion)
if \result~ok then do
  say "ENTRY DENIED" result~code result~detail
  exit 2
end
session = result~value
say "Access Control:" session~accessDecisionEnvelope~decision~allowed "proof=" session~accessDecisionEnvelope~verifyProof(accessProofRing)

routine = .Routine~newFile(agentPath)
session~secure(routine)
say "Protected method result:" routine~call(target)
say "Permission proof:" session~permissionAdapter~decisionEnvelopes[1]~verifyProof(permissionProofRing)
exit 0

::class DemoResolver public
::method init
  expose subject snapshot framework counter
  use strict arg subjectArg, snapshotArg, frameworkArg
  subject = subjectArg; snapshot = snapshotArg; framework = frameworkArg; counter = 0
::method assessmentFor
  expose subject snapshot framework counter
  use strict arg principalId, obj, methodName, args, info
  if principalId <> subject then return .SecurityResult~failure("SUBJECT_MISMATCH")
  counter += 1
  action = .SecurityActionSurface~new("ACT:DEMO:" || counter, principalId, "METHOD_INVOCATION", .DateTime~new, "NORMAL", methodName)
  action~putAttribute("OBJECT_ID", obj~alchemyObjectId)
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

::requires "AccessPermissions.cls"
::requires "AlchemyAccessPermissionsAdapter.cls"
::requires "AlchemyObject.cls"
