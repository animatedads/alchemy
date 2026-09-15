agentPath = arg(1)
if agentPath = "" then agentPath = "protected_method_agent.rex"
now = .DateTime~new
subjectId = "STAFF:BOB"

/* Authentication attribution key.  Valid identity evidence is required at the
 * domain boundary, but still grants neither entry nor method authority. */
authRing = .CryptoMacKeyRing~new
authRing~addKey("bob-auth-1", "00112233445566778899aabbccddeeff")
principal = .AccessPrincipal~new(subjectId, "bob-auth-1")~seal
verifier = .AuthenticationVerifier~new(authRing)

/* Access Control decisions and Permission decisions use separate proof keys. */
accessProofRing = .CryptoMacKeyRing~new
accessProofRing~addKey("access-proof-1", "102132435465768798a9bacbdcedfe0f")
accessSigner = .AccessPermissionsSigner~new(accessProofRing, "access-proof-1")
accessAuthority = .AccessControlAuthority~new(accessSigner, verifier)

permissionProofRing = .CryptoMacKeyRing~new
permissionProofRing~addKey("permission-proof-1", "ffeeddccbbaa99887766554433221100")
permissionSigner = .AccessPermissionsSigner~new(permissionProofRing, "permission-proof-1")
permissionAuthority = .PermissionAuthority~new(permissionSigner)

accessPolicy = .AccessControlPolicy~new("TREASURY-ENTRY", "2", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "facilities")
entryRule = .AccessControlRule~new("BOB-TREASURY", 100, "ALLOW", subjectId, "TREASURY", "FRONT_DOOR")
entryRule~requireAttribute("BADGE", "GREEN")
entryRule~seal
accessPolicy~addRule(entryRule)
accessPolicy~seal

/* Real Security Effect evaluation remains the semantic prerequisite for each
 * protected method invocation. */
target = .PaymentTarget~new
objectId = target~alchemyObjectId
snapshot = .SecuritySnapshot~new("SNAP:PAIR", subjectId, now)~seal
framework = .SecurityPolicyFramework~new("PAIR-METHOD-SECURITY", "1", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")~seal
resolver = .InvocationSecurityEffectResolver~new(subjectId, snapshot, framework)
fallback = .AlchemySecurityPolicy~new("DENY")
runtime = .AlchemySecurityRuntimeProfile~observedR13196

/* First prove the architectural boundary: entry succeeds, but method use is
 * still denied because the separate Permission policy grants nothing. */
denyPermission = .PermissionPolicy~new("TREASURY-METHODS-DENY", "2", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")~seal
denyDomain = .AlchemyAccessControlledDomain~new("TREASURY", accessPolicy, accessAuthority, denyPermission, permissionAuthority, resolver, fallback, runtime)

entry1 = .AccessControlRequest~new("ENTRY-1", subjectId, "TREASURY", "FRONT_DOOR", now)
entry1~putAttribute("BADGE", "GREEN")
entry1~seal
assertion1 = .AuthenticationAssertion~issue(principal, authRing, "ACCESS_CONTROL", entry1~semanticIdentity, "entry-nonce-1")
sessionResult1 = denyDomain~enter(entry1, principal, assertion1)
call assertTrue sessionResult1~ok, "Access Control admitted principal"
session1 = sessionResult1~value
call assertTrue session1~accessDecisionEnvelope~decision~allowed, "session retains Access Control ALLOW"
call assertTrue session1~accessDecisionEnvelope~verifyProof(accessProofRing), "Access Control ALLOW proof verifies"

routine1 = .Routine~newFile(agentPath)
session1~secure(routine1)
signal on syntax name methodDenied
ignore = routine1~call(target)
signal off syntax
raise syntax 88.900 array("method unexpectedly authorized merely because building entry succeeded")
methodDenied:
  signal off syntax
call assertEq 0, target~total, "denied protected method body did not execute"
call assertEq 1, session1~permissionAdapter~decisionEnvelopes~items, "separate Permission decision retained"
call assertFalse session1~permissionAdapter~decisionEnvelopes[1]~decision~allowed, "entry did not become method permission"
call assertTrue session1~permissionAdapter~decisionEnvelopes[1]~verifyProof(permissionProofRing), "denied Permission decision proof verifies"

/* Now grant the exact object/method.  The same Access Control policy is used,
 * but the method succeeds only because the separate Permission policy allows
 * this exact object identity after Security Effect returns ALLOW. */
allowPermission = .PermissionPolicy~new("TREASURY-METHODS-ALLOW", "2", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")
allowPermission~addRule(.PermissionRule~new("BOB-EXACT-RELEASE", 100, "ALLOW", subjectId, objectId, "PAYMENTTARGET", "RELEASEPAYMENT", "ALLOW", framework~semanticIdentity)~seal)
allowPermission~seal
allowDomain = .AlchemyAccessControlledDomain~new("TREASURY", accessPolicy, accessAuthority, allowPermission, permissionAuthority, resolver, fallback, runtime)
entry2 = .AccessControlRequest~new("ENTRY-2", subjectId, "TREASURY", "FRONT_DOOR", .DateTime~new)
entry2~putAttribute("BADGE", "GREEN")
entry2~seal
assertion2 = .AuthenticationAssertion~issue(principal, authRing, "ACCESS_CONTROL", entry2~semanticIdentity, "entry-nonce-2")
sessionResult2 = allowDomain~enter(entry2, principal, assertion2)
call assertTrue sessionResult2~ok, "second Access Control admission"
session2 = sessionResult2~value
routine2 = .Routine~newFile(agentPath)
session2~secure(routine2)
value = routine2~call(target)
call assertEq 7, value, "exact Permission authorizes protected method"
call assertEq 7, target~total, "allowed body executed once"
call assertEq 1, session2~permissionAdapter~decisionEnvelopes~items, "allow Permission evidence retained"
call assertTrue session2~permissionAdapter~decisionEnvelopes[1]~decision~allowed, "separate Permission ALLOW"
call assertTrue session2~permissionAdapter~decisionEnvelopes[1]~verifyProof(permissionProofRing), "Permission ALLOW proof verifies"

/* Cryptographically attributed principal with the wrong building context is
 * still denied at the outer boundary, before a Security Manager session exists. */
badEntry = .AccessControlRequest~new("ENTRY-3", subjectId, "TREASURY", "FRONT_DOOR", .DateTime~new)
badEntry~putAttribute("BADGE", "RED")
badEntry~seal
badAssertion = .AuthenticationAssertion~issue(principal, authRing, "ACCESS_CONTROL", badEntry~semanticIdentity, "entry-nonce-3")
badResult = allowDomain~enter(badEntry, principal, badAssertion)
call assertFalse badResult~ok, "wrong building context denied"
call assertEq "ACCESS_DENIED", badResult~code, "outer boundary denial code"
call assertTrue badResult~value~verifyProof(accessProofRing), "denied Access Control decision is also provable"

/* The executable protected-domain composition fails closed when Access Control
 * can decide but cannot produce a cryptographic decision proof. */
unsignedAuthority = .AccessControlAuthority~new(.nil, verifier)
unsignedDomain = .AlchemyAccessControlledDomain~new("TREASURY", accessPolicy, unsignedAuthority, allowPermission, permissionAuthority, resolver, fallback, runtime)
unsignedEntry = .AccessControlRequest~new("ENTRY-4", subjectId, "TREASURY", "FRONT_DOOR", .DateTime~new)
unsignedEntry~putAttribute("BADGE", "GREEN")
unsignedEntry~seal
unsignedAssertion = .AuthenticationAssertion~issue(principal, authRing, "ACCESS_CONTROL", unsignedEntry~semanticIdentity, "entry-nonce-4")
unsignedResult = unsignedDomain~enter(unsignedEntry, principal, unsignedAssertion)
call assertFalse unsignedResult~ok, "protected domain requires proved Access Control ALLOW"
call assertEq "ACCESS_PROOF_REQUIRED", unsignedResult~code, "missing proof fails closed"

say "PASS test_alchemy_access_control_pairing"
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
  action = .SecurityActionSurface~new("ACT:PAIR:" || counter, principalId, "METHOD_INVOCATION", .DateTime~new, "NORMAL", methodName)
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
