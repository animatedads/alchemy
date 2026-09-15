now = .DateTime~new

/* Alice may truthfully sign bytes that describe Bob.  Authentication proves
 * Alice signed them; authority must therefore independently require that the
 * request subject is Alice before evaluating Bob's policy rights. */
ring = .CryptoMacKeyRing~new
ring~addKey("alice-key-1", "00112233445566778899aabbccddeeff")
alice = .AccessPrincipal~new("STAFF:ALICE", "alice-key-1")~seal
verifier = .AuthenticationVerifier~new(ring)

accessPolicy = .AccessControlPolicy~new("BOB-ENTRY", "2", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "facilities")
accessPolicy~addRule(.AccessControlRule~new("ALLOW-BOB", 100, "ALLOW", "STAFF:BOB", "HQ", "FRONT_DOOR")~seal)
accessPolicy~seal
bobEntry = .AccessControlRequest~new("IMPERSONATE-ENTRY", "STAFF:BOB", "HQ", "FRONT_DOOR", now)~seal
aliceEntryAssertion = .AuthenticationAssertion~issue(alice, ring, "ACCESS_CONTROL", bobEntry~semanticIdentity, "impersonate-entry")
accessAuthority = .AccessControlAuthority~new(.nil, verifier)
accessResult = accessAuthority~decide(bobEntry, accessPolicy, aliceEntryAssertion, alice)
call assertFalse accessResult~ok, "Alice attribution cannot be applied to Bob Access Control subject"
call assertEq "ACCESS_ATTRIBUTION_SUBJECT_MISMATCH", accessResult~code, "Access Control subject-binding code"

/* Same invariant at the exact method/object permission layer. */
objectId = "OBJECT:PAYMENT:42"
method = "RELEASEPAYMENT"
snapshot = .SecuritySnapshot~new("SNAP:BOB-IMPERSONATION", "STAFF:BOB", now)~seal
framework = .SecurityPolicyFramework~new("IMPERSONATION-SECURITY", "1", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")~seal
action = .SecurityActionSurface~new("ACT:IMPERSONATION", "STAFF:BOB", "METHOD_INVOCATION", now, "NORMAL", method)
action~putAttribute("OBJECT_ID", objectId)
action~putAttribute("METHOD", method)
assessmentResult = .SecurityEffectEngine~new~evaluate(action~seal, snapshot, framework)
call assertTrue assessmentResult~ok, "Bob Security Effect assessment created"

permissionPolicy = .PermissionPolicy~new("BOB-METHOD", "2", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")
permissionPolicy~addRule(.PermissionRule~new("ALLOW-BOB-EXACT", 100, "ALLOW", "STAFF:BOB", objectId, "PAYMENTACCOUNT", method, "ALLOW", framework~semanticIdentity)~seal)
permissionPolicy~seal
bobPermission = .PermissionRequest~new("IMPERSONATE-METHOD", "STAFF:BOB", objectId, "PAYMENTACCOUNT", method, now)
call assertTrue bobPermission~bindSecurityAssessment(assessmentResult~value), "Bob Security Effect binds to Bob request"
bobPermission~seal
alicePermissionAssertion = .AuthenticationAssertion~issue(alice, ring, "METHOD_PERMISSION", bobPermission~semanticIdentity, "impersonate-method")
permissionAuthority = .PermissionAuthority~new(.nil, verifier)
permissionResult = permissionAuthority~decide(bobPermission, permissionPolicy, alicePermissionAssertion, alice)
call assertFalse permissionResult~ok, "Alice attribution cannot be applied to Bob Permission subject"
call assertEq "PERMISSION_ATTRIBUTION_SUBJECT_MISMATCH", permissionResult~code, "Permission subject-binding code"

say "PASS test_attribution_subject_binding"
::requires "TestSupport.cls"
::requires "AccessPermissions.cls"
