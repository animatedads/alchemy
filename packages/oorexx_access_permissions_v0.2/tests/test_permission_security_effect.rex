now = .DateTime~new
subject = "STAFF:BOB"
objectId = "OBJECT:PAYMENT:42"
objectClass = "PAYMENTACCOUNT"
method = "RELEASEPAYMENT"

/* Real Security Effect assessments, one ALLOW and one HOLD. */
snapshot = .SecuritySnapshot~new("SNAP:BOB", subject, now)~seal
allowFramework = .SecurityPolicyFramework~new("PAYMENT-SECURITY", "1", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")~seal
allowAction = .SecurityActionSurface~new("ACT:ALLOW", subject, "METHOD_INVOCATION", now, "NORMAL", method)
allowAction~putAttribute("OBJECT_ID", objectId)
allowAction~putAttribute("METHOD", method)
allowAssessmentResult = .SecurityEffectEngine~new~evaluate(allowAction~seal, snapshot, allowFramework)
call assertTrue allowAssessmentResult~ok, "allow assessment"
call assertEq "ALLOW", allowAssessmentResult~value~disposition, "allow disposition"

holdRule = .SecurityPolicyRule~new("HOLD-PAYMENT", 10, "METHOD_INVOCATION", "HOLD", "review required")~seal
holdFramework = .SecurityPolicyFramework~new("PAYMENT-SECURITY", "2", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")
holdFramework~addRule(holdRule)
holdFramework~seal
holdAction = .SecurityActionSurface~new("ACT:HOLD", subject, "METHOD_INVOCATION", now, "NORMAL", method)
holdAction~putAttribute("OBJECT_ID", objectId)
holdAction~putAttribute("METHOD", method)
holdAction~seal
holdAssessmentResult = .SecurityEffectEngine~new~evaluate(holdAction, snapshot, holdFramework)
call assertTrue holdAssessmentResult~ok, "hold assessment"
call assertEq "HOLD", holdAssessmentResult~value~disposition, "hold disposition"

policy = .PermissionPolicy~new("PAYMENT-METHOD-PERMISSIONS", "1", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")
policy~addRule(.PermissionRule~new("BOB-RELEASE-EXACT", 100, "ALLOW", subject, objectId, objectClass, method, "ALLOW", allowFramework~semanticIdentity)~seal)
policy~seal
ring = .CryptoMacKeyRing~new
ring~addKey("permission-decisions-1", "11223344556677889900aabbccddeeff")
signer = .AccessPermissionsSigner~new(ring, "permission-decisions-1")
authority = .PermissionAuthority~new(signer)

request = .PermissionRequest~new("P1", subject, objectId, objectClass, method, now)
call assertTrue request~bindSecurityAssessment(allowAssessmentResult~value), "bind allow assessment"
request~seal
permissionResult = authority~decide(request, policy)
call assertTrue permissionResult~ok, "permission evaluated"
call assertTrue permissionResult~value~decision~allowed, "exact object/method allowed"
call assertTrue permissionResult~value~verifyProof(ring), "MAC permission proof verifies"
call assertEq allowFramework~semanticIdentity, permissionResult~value~decision~securityPolicyIdentity, "Security Effect policy identity retained"

wrongObjectId = "OBJECT:PAYMENT:43"
wrongAction = .SecurityActionSurface~new("ACT:WRONG-OBJECT", subject, "METHOD_INVOCATION", now, "NORMAL", method)
wrongAction~putAttribute("OBJECT_ID", wrongObjectId)
wrongAction~putAttribute("METHOD", method)
wrongAssessmentResult = .SecurityEffectEngine~new~evaluate(wrongAction~seal, snapshot, allowFramework)
call assertTrue wrongAssessmentResult~ok, "wrong-object Security Effect assessment valid for that object"
wrongObject = .PermissionRequest~new("P2", subject, wrongObjectId, objectClass, method, now)
call assertTrue wrongObject~bindSecurityAssessment(wrongAssessmentResult~value), "wrong-object assessment binds only to wrong object"
wrongObject~seal
wrong = authority~decide(wrongObject, policy)
call assertFalse wrong~value~decision~allowed, "permission does not float across object identity"

holdRequest = .PermissionRequest~new("P3", subject, objectId, objectClass, method, now)
holdRequest~bindSecurityAssessment(holdAssessmentResult~value)
holdRequest~seal
held = authority~decide(holdRequest, policy)
call assertFalse held~value~decision~allowed, "Security Effect HOLD cannot satisfy ALLOW-only permission"
say "PASS test_permission_security_effect"
::requires "TestSupport.cls"
::requires "AccessPermissions.cls"
