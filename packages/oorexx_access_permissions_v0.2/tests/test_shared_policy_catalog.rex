now = .DateTime~new
access = .AccessControlPolicy~new("HQ-ENTRY", "1", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "facilities")
access~addRule(.AccessControlRule~new("STAFF", 100, "ALLOW", "STAFF:*", "HQ", "LOBBY")~seal)
access~seal
accessCatalog = .AccessControlPolicyCatalog~new
pubAccess = accessCatalog~publish(access)
call assertTrue pubAccess~ok, "Access Control policy publishes through shared Institutional Policy catalog"
resolvedAccess = accessCatalog~resolve("HQ-ENTRY", now)
call assertTrue resolvedAccess~ok, "Access Control policy resolves through shared catalog"
call assertEq access~semanticIdentity, resolvedAccess~value~semanticIdentity, "resolved Access Control identity exact"

perm = .PermissionPolicy~new("OBJECT-PERM", "1", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "security", "risk")
perm~addRule(.PermissionRule~new("READ", 100, "ALLOW", "STAFF:*", "OBJECT:1", "THING", "READ", "ALLOW", "*")~seal)
perm~seal
permCatalog = .PermissionPolicyCatalog~new
pubPerm = permCatalog~publish(perm)
call assertTrue pubPerm~ok, "Permission policy publishes through shared Institutional Policy catalog"
resolvedPerm = permCatalog~resolve("OBJECT-PERM", now)
call assertTrue resolvedPerm~ok, "Permission policy resolves through shared catalog"
call assertEq perm~semanticIdentity, resolvedPerm~value~semanticIdentity, "resolved Permission identity exact"
say "PASS test_shared_policy_catalog"
::requires "TestSupport.cls"
::requires "AccessPermissions.cls"
