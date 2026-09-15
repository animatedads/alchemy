ring = .CryptoMacKeyRing~new
ring~addKey("institution-access-1", "00112233445566778899aabbccddeeff")
signer = .AccessPermissionsSigner~new(ring, "institution-access-1")
now = .DateTime~new
policy = .AccessControlPolicy~new("HQ-ENTRY", "1", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "facilities")
policy~addRule(.AccessControlRule~new("STAFF-LOBBY", 100, "ALLOW", "STAFF:*", "HQ", "LOBBY")~seal)
policy~addRule(.AccessControlRule~new("ALICE-SUSPENDED", 200, "DENY", "STAFF:ALICE", "HQ", "*")~seal)
policy~seal
requestBob = .AccessControlRequest~new("B1", "STAFF:BOB", "HQ", "LOBBY", now)~seal
r1 = .AccessControlAuthority~new(signer)~decide(requestBob, policy)
call assertTrue r1~ok, "bob access evaluated"
call assertTrue r1~value~decision~allowed, "bob may enter building"
call assertEq "STAFF-LOBBY", r1~value~decision~ruleId, "allow rule"
call assertTrue r1~value~verifyProof(ring), "MAC-proved access decision verifies"
requestAlice = .AccessControlRequest~new("A1", "STAFF:ALICE", "HQ", "LOBBY", now)~seal
r2 = .AccessControlAuthority~new(signer)~decide(requestAlice, policy)
call assertFalse r2~value~decision~allowed, "higher-priority deny wins"
call assertEq "ALICE-SUSPENDED", r2~value~decision~ruleId, "deny rule"
requestOther = .AccessControlRequest~new("X1", "VISITOR:X", "HQ", "LOBBY", now)~seal
r3 = .AccessControlAuthority~new(signer)~decide(requestOther, policy)
call assertFalse r3~value~decision~allowed, "default deny"
tiePolicy = .AccessControlPolicy~new("HQ-TIE", "1", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "facilities")
tiePolicy~addRule(.AccessControlRule~new("ALLOW-TIE", 100, "ALLOW", "STAFF:BOB", "HQ", "SIDE")~seal)
tiePolicy~addRule(.AccessControlRule~new("DENY-TIE", 100, "DENY", "STAFF:BOB", "HQ", "SIDE")~seal)
tiePolicy~seal
tieRequest = .AccessControlRequest~new("T1", "STAFF:BOB", "HQ", "SIDE", now)~seal
tieDecision = .AccessControlAuthority~new(signer)~decide(tieRequest, tiePolicy)
call assertFalse tieDecision~value~decision~allowed, "DENY wins equal-priority tie"
call assertEq "DENY-TIE", tieDecision~value~decision~ruleId, "deterministic tie rule"
policyProof = signer~signArtifact("ACCESS_CONTROL_POLICY", policy)
call assertTrue policyProof~verifyWith(ring), "policy proof verifies"
call assertEq policy~semanticIdentity, policyProof~artifactIdentity, "policy identity bound"
say "PASS test_access_control"
::requires "TestSupport.cls"
::requires "AccessPermissions.cls"
