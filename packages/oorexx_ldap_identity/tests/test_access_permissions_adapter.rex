/* Access Permissions is an optional first-tier LDAP authority provider. */
now = .DateTime~new
policy = .AccessControlPolicy~new("LDAP-ACCESS", "1", "DENY", now - .TimeSpan~new(0,0,0,0,1), .nil, "architect", "reviewer")
allowSearch = .AccessControlRule~new("ALICE-SEARCH", 100, "ALLOW", "PRINCIPAL:ALICE", "LDAP:DIRECTORY", "LDAP_SEARCH")
allowSearch~seal
ignore = policy~addRule(allowSearch)
policy~seal

authority = .AccessPermissionsLdapAuthority~new(.AccessControlAuthority~new, policy)
session = .LdapSession~new("session-1", "principal:alice", .true)

r = authority~authorize(session, "LDAP_SEARCH", "resource:directory", "dc=example,dc=org")
ignore = .LdapIdentityTest~assert(r~ok, "Access Permissions allows configured LDAP entry point")
ignore = .LdapIdentityTest~equal("ACCESS_CONTROL", r~value~kind, "decision remains access-control evidence")

r = authority~authorize(session, "LDAP_MODIFY", "resource:directory", "uid=alice,dc=example,dc=org")
ignore = .LdapIdentityTest~assert(\r~ok, "unconfigured LDAP operation denied")
ignore = .LdapIdentityTest~equal("LDAP_AUTHORIZATION_DENIED", r~code, "default deny mapped to LDAP authority")

anon = .LdapSession~new("session-anon", "", .false)
r = authority~authorize(anon, "LDAP_SEARCH", "resource:directory", "dc=example,dc=org")
ignore = .LdapIdentityTest~assert(\r~ok, "unauthenticated session denied before Access Permissions")
ignore = .LdapIdentityTest~equal("LDAP_AUTHENTICATION_REQUIRED", r~code, "authentication boundary remains separate")

say "ACCESS PERMISSIONS LDAP ADAPTER: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapAccessPermissionsAdapter.cls"
