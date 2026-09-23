dir = .IdentityDirectory~new("peer-a")
ignore = .LdapIdentityTest~assert(dir~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice Example", "alice")~ok, "principal")
ignore = .LdapIdentityTest~assert(dir~createCredential("credential:alice:password", "cn=password,uid=alice,ou=people,dc=example,dc=org", "principal:alice", "PASSWORD_VERIFIER", "secret://identity/alice/password")~ok, "credential")
p = .NativeLdapPersonality~new
entry = p~project(dir~entryById("credential:alice:password"), dir)
ignore = .LdapIdentityTest~equal("secret://identity/alice/password", entry~attributes~first("oorexxSecretRef"), "secret reference projected")
ignore = .LdapIdentityTest~assert(\entry~attributes~has("userPassword"), "raw password absent")
principalEntry = p~project(dir~entryById("principal:alice"), dir)
ignore = .LdapIdentityTest~equal("alice", principalEntry~attributes~first("uid"), "native uid")
filter = .AttributeAliasConversationFilter~new("example-vendor")
filter~addAlias("vendorLogin", "uid")
vendor = filter~fromNative(principalEntry)
ignore = .LdapIdentityTest~equal("alice", vendor~attributes~first("vendorLogin"), "outbound personality alias")
roundtrip = filter~toNative(vendor)
ignore = .LdapIdentityTest~equal("alice", roundtrip~attributes~first("uid"), "inbound personality alias")
ignore = .LdapIdentityTest~assert(.LdapFilter~matches("(&(objectClass=oorexxPrincipal)(uid=alice))", principalEntry), "ldap filter")
say "LDAP PERSONALITY: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapDirectoryPersonality.cls"
