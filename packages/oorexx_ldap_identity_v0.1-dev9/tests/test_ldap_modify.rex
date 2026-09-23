dir = .IdentityDirectory~new("peer-modify")
ignore = .LdapIdentityTest~assert(dir~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice", "alice")~ok, "alice")
ignore = .LdapIdentityTest~assert(dir~createPrincipal("principal:bob", "uid=bob,ou=people,dc=example,dc=org", "PERSON", "Bob", "bob")~ok, "bob")
ignore = .LdapIdentityTest~assert(dir~createGroup("group:operators", "cn=operators,ou=groups,dc=example,dc=org", "Operators")~ok, "group")
ignore = .LdapIdentityTest~assert(dir~createResource("resource:directory", "cn=directory,ou=resources,dc=example,dc=org", "DIRECTORY", "identity://example", "Directory")~ok, "resource")
ignore = .LdapIdentityTest~assert(dir~createAclGrant("acl:modify", "cn=modify,ou=acl,dc=example,dc=org", "principal:alice", "resource:directory", "LDAP_MODIFY", "ALLOW")~ok, "modify acl")

service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, .LdapAuthenticator~new, .DirectoryAclLdapAuthority~new(dir), "resource:directory")
session = .LdapSession~new("test", "principal:alice", .true)

mods = .array~new
mods~append(.LdapModification~new("REPLACE", "cn", .array~of("Alice Updated")))
mods~append(.LdapModification~new("REPLACE", "uid", .array~of("alice2")))
r = service~modify(session, "uid=alice,ou=people,dc=example,dc=org", mods)
ignore = .LdapIdentityTest~assert(r~ok, "principal modify")
alice = dir~entryById("principal:alice")
ignore = .LdapIdentityTest~equal("Alice Updated", alice~displayName, "cn updated")
ignore = .LdapIdentityTest~equal("alice2", alice~loginName, "uid updated")

mods = .array~new
mods~append(.LdapModification~new("ADD", "member", .array~of("uid=bob,ou=people,dc=example,dc=org")))
r = service~modify(session, "cn=operators,ou=groups,dc=example,dc=org", mods)
ignore = .LdapIdentityTest~assert(r~ok, "member add")
ignore = .LdapIdentityTest~assert(dir~entryById("group:operators")~hasMember("principal:bob"), "member semantic id")

mods = .array~new
mods~append(.LdapModification~new("DELETE", "member", .array~of("uid=bob,ou=people,dc=example,dc=org")))
r = service~modify(session, "cn=operators,ou=groups,dc=example,dc=org", mods)
ignore = .LdapIdentityTest~assert(r~ok, "member delete")
ignore = .LdapIdentityTest~assert(\dir~entryById("group:operators")~hasMember("principal:bob"), "member removed")

/* Immutable semantic identity cannot be rewritten by an LDAP conversation. */
mods = .array~new
mods~append(.LdapModification~new("REPLACE", "entryUUID", .array~of("principal:mallory")))
r = service~modify(session, "uid=alice,ou=people,dc=example,dc=org", mods)
ignore = .LdapIdentityTest~assert(\r~ok, "entryUUID rejected")
ignore = .LdapIdentityTest~equal("LDAP_ATTRIBUTE_IMMUTABLE", r~code, "immutable code")
ignore = .LdapIdentityTest~assert(dir~entryById("principal:alice") <> .nil, "identity unchanged")

/* The same Modify operation works through a vocabulary/personality filter. */
filter = .AttributeAliasConversationFilter~new("test-vendor")
filter~addAlias("accountName", "uid")
filtered = .FilteredDirectoryPersonality~new("test-vendor-ldap", .NativeLdapPersonality~new, filter)
service2 = .LdapConversationService~new(dir, filtered, .LdapAuthenticator~new, .DirectoryAclLdapAuthority~new(dir), "resource:directory")
mods = .array~new
mods~append(.LdapModification~new("REPLACE", "accountName", .array~of("alice3")))
r = service2~modify(session, "uid=alice,ou=people,dc=example,dc=org", mods)
ignore = .LdapIdentityTest~assert(r~ok, "filtered modify")
ignore = .LdapIdentityTest~equal("alice3", dir~entryById("principal:alice")~loginName, "filtered edge translated")

say "LDAP MODIFY: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapConversation.cls"
