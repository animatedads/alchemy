ignore = .LdapIdentityTest~assert(.IdentityDirectoryBuild~RELEASE = "0.1-dev9", "release")
dir = .IdentityDirectory~new("peer-a")
r = dir~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice Example", "alice")
ignore = .LdapIdentityTest~assert(r~ok, "create principal")
r = dir~createGroup("group:operators", "cn=operators,ou=groups,dc=example,dc=org", "Operators")
ignore = .LdapIdentityTest~assert(r~ok, "create group")
r = dir~addGroupMember("group:operators", "principal:alice")
ignore = .LdapIdentityTest~assert(r~ok, "membership")
r = dir~createResource("resource:directory", "cn=directory,ou=resources,dc=example,dc=org", "DIRECTORY", "identity://example", "Identity Directory")
ignore = .LdapIdentityTest~assert(r~ok, "resource")
r = dir~createAclGrant("acl:operators-search", "cn=operators-search,ou=acl,dc=example,dc=org", "group:operators", "resource:directory", "LDAP_SEARCH", "ALLOW")
ignore = .LdapIdentityTest~assert(r~ok, "acl")
r = dir~aclDecision("principal:alice", "resource:directory", "LDAP_SEARCH")
ignore = .LdapIdentityTest~assert(r~ok, "group ACL allow")
r = dir~aclDecision("principal:alice", "resource:directory", "LDAP_DELETE")
ignore = .LdapIdentityTest~assert(\r~ok, "default deny")
ignore = .LdapIdentityTest~equal("ACL_DEFAULT_DENY", r~code, "deny code")
aliceUuid = dir~entryById("principal:alice")~entryUuid
ignore = .LdapIdentityTest~equal(36, aliceUuid~length, "LDAP entryUUID canonical length")
ignore = .LdapIdentityTest~equal("-", aliceUuid~substr(9,1), "LDAP entryUUID separator 1")
ignore = .LdapIdentityTest~equal("-", aliceUuid~substr(14,1), "LDAP entryUUID separator 2")
ignore = .LdapIdentityTest~equal("4", aliceUuid~substr(15,1), "LDAP entryUUID version nibble")
ignore = .LdapIdentityTest~equal(aliceUuid, dir~entryById("principal:alice")~entryUuid, "LDAP entryUUID stable within entity lifetime")

say "IDENTITY CORE: OK"
::requires "tests/TestSupport.cls"
::requires "src/IdentityDirectory.cls"
