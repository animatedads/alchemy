parse arg port readyFile
if port = "" then port = 1389

dir = .IdentityDirectory~new("sync-persist-fixture")
ignore = dir~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice Persist", "alice")
ignore = dir~createCredential("credential:alice:ldap", "cn=ldap-bind,uid=alice,ou=people,dc=example,dc=org", "principal:alice", "LDAP_SIMPLE_BIND_SECRET", "secret://identity/alice/ldap", .nil, .nil, "ACTIVE")
ignore = dir~createPrincipal("principal:bob", "uid=bob,ou=people,dc=example,dc=org", "PERSON", "Bob Persist", "bob")
ignore = dir~createResource("resource:directory", "cn=directory,ou=resources,dc=example,dc=org", "DIRECTORY", "identity://example", "Identity Directory")
do action over .array~of("LDAP_SEARCH", "LDAP_MODIFY")
  ignore = dir~createAclGrant("acl:alice:" || action~lower, "cn=" || action~lower || ",ou=acl,dc=example,dc=org", "principal:alice", "resource:directory", action, "ALLOW")
end
provider = .TestSecretProvider~new
provider~put("secret://identity/alice/ldap", "wire-secret")
broker = .SecretBroker~new(provider)
authn = .SecretBrokerSimpleBindAuthenticator~new(dir, broker)
authority = .DirectoryAclLdapAuthority~new(dir)
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, authn, authority, "resource:directory")
server = .LdapWireServer~new(service, "127.0.0.1", port, "dc=example,dc=org", .nil, .nil, .false, 0.05, 0.25)
served = server~serve(2, readyFile)
say "LDAP SYNC PERSIST FIXTURE DONE connections=" || served
::requires "src/LdapWireServer.cls"
