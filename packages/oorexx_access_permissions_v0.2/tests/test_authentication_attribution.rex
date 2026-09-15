ring = .CryptoMacKeyRing~new
ring~addKey("alice-key-1", "00112233445566778899aabbccddeeff")
principal = .AccessPrincipal~new("SERVICE:ALICE", "alice-key-1")~seal
payload = .AccessPermissionsCanonical~hash("exact invocation evidence")
assertion = .AuthenticationAssertion~issue(principal, ring, "METHOD_PERMISSION", payload, "nonce-001")
verifier = .AuthenticationVerifier~new(ring)
verified = verifier~verify(assertion, principal, "METHOD_PERMISSION", payload)
call assertTrue verified~ok, "valid attribution"
wrongPayload = verifier~verify(assertion, principal, "METHOD_PERMISSION", .AccessPermissionsCanonical~hash("tampered"))
call assertFalse wrongPayload~ok, "payload binding"
call assertEq "AUTHENTICATION_PAYLOAD_MISMATCH", wrongPayload~code, "tamper code"
wrongPurpose = verifier~verify(assertion, principal, "ACCESS_CONTROL", payload)
call assertFalse wrongPurpose~ok, "purpose binding"
now = .DateTime~new
request = .AccessControlRequest~new("A1", principal~principalId, "TREASURY", "FRONT_DOOR", now)~seal
accessAssertion = .AuthenticationAssertion~issue(principal, ring, "ACCESS_CONTROL", request~semanticIdentity, "nonce-002")
policy = .AccessControlPolicy~new("BUILDING", "1", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")~seal
accessResult = .AccessControlAuthority~new(.nil, verifier)~decide(request, policy, accessAssertion, principal)
call assertTrue accessResult~ok, "decision produced"
call assertFalse accessResult~value~decision~allowed, "authentication is not access authority"
say "PASS test_authentication_attribution"
::requires "TestSupport.cls"
::requires "AccessPermissions.cls"
