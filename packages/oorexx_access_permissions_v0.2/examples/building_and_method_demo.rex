/* Compact demonstration of the two separate authorities. */
now = .DateTime~new
ring = .CryptoMacKeyRing~new
ring~addKey("demo-authority", "00112233445566778899aabbccddeeff")
signer = .AccessPermissionsSigner~new(ring, "demo-authority")

access = .AccessControlPolicy~new("OFFICE", "1", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "facilities")
access~addRule(.AccessControlRule~new("STAFF-IN", 100, "ALLOW", "STAFF:*", "HQ", "LOBBY")~seal)
access~seal
entry = .AccessControlRequest~new("ENTRY-1", "STAFF:BOB", "HQ", "LOBBY", now)~seal
entryDecision = .AccessControlAuthority~new(signer)~decide(entry, access)~value
say "Access Control (enter building):" entryDecision~decision~allowed "proof=" entryDecision~verifyProof(ring)
say "Passing that gate does not grant any object method permission."
::requires "AccessPermissions.cls"
