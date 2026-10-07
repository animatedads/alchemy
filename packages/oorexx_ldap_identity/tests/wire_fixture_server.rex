parse arg port readyFile
if port = "" then port = 1389

dir = .IdentityDirectory~new("wire-fixture")
ignore = dir~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice Example", "alice")
ignore = dir~createCredential("credential:alice:ldap", "cn=ldap-bind,uid=alice,ou=people,dc=example,dc=org", "principal:alice", "LDAP_SIMPLE_BIND_SECRET", "secret://identity/alice/ldap", .nil, .nil, "ACTIVE")
ignore = dir~createPrincipal("principal:bob", "uid=bob,ou=people,dc=example,dc=org", "PERSON", "Bob No Authority", "bob")
ignore = dir~createCredential("credential:bob:ldap", "cn=ldap-bind,uid=bob,ou=people,dc=example,dc=org", "principal:bob", "LDAP_SIMPLE_BIND_SECRET", "secret://identity/bob/ldap", .nil, .nil, "ACTIVE")
ignore = dir~createResource("resource:directory", "cn=directory,ou=resources,dc=example,dc=org", "DIRECTORY", "identity://example", "Identity Directory")
do action over .array~of("LDAP_SEARCH", "LDAP_COMPARE", "LDAP_ADD", "LDAP_MODIFY", "LDAP_MODIFY_DN", "LDAP_DELETE")
  aclId = "acl:alice:" || action~lower
  dn = "cn=" || action~lower || ",ou=acl,dc=example,dc=org"
  ignore = dir~createAclGrant(aclId, dn, "principal:alice", "resource:directory", action, "ALLOW")
end
provider = .TestSecretProvider~new
provider~put("secret://identity/alice/ldap", "wire-secret")
provider~put("secret://identity/bob/ldap", "bob-secret")
broker = .SecretBroker~new(provider)
authn = .SecretBrokerSimpleBindAuthenticator~new(dir, broker)
authority = .DirectoryAclLdapAuthority~new(dir)
sasl = .PlainLdapSaslProvider~new(authn)
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, authn, authority, "resource:directory", sasl)
server = .LdapWireServer~new(service, "127.0.0.1", port, "dc=example,dc=org")
served = server~serve(3, readyFile)
say "LDAP WIRE FIXTURE DONE connections=" || served
::requires "src/LdapWireServer.cls"
