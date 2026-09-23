parse arg port readyFile certificateFile privateKeyFile bridgeDirectory
if port = "" then port = 1389

dir = .IdentityDirectory~new("tls-wire-fixture")
ignore = dir~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice TLS", "alice")
ignore = dir~createCredential("credential:alice:ldap", "cn=ldap-bind,uid=alice,ou=people,dc=example,dc=org", "principal:alice", "LDAP_SIMPLE_BIND_SECRET", "secret://identity/alice/ldap", .nil, .nil, "ACTIVE")
ignore = dir~createResource("resource:directory", "cn=directory,ou=resources,dc=example,dc=org", "DIRECTORY", "identity://example", "Identity Directory")
ignore = dir~createAclGrant("acl:alice:search", "cn=search,ou=acl,dc=example,dc=org", "principal:alice", "resource:directory", "LDAP_SEARCH", "ALLOW")
provider = .TestSecretProvider~new
provider~put("secret://identity/alice/ldap", "wire-secret")
broker = .SecretBroker~new(provider)
authn = .SecretBrokerSimpleBindAuthenticator~new(dir, broker)
sasl = .PlainLdapSaslProvider~new(authn)
authority = .DirectoryAclLdapAuthority~new(dir)
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, authn, authority, "resource:directory", sasl)
config = .LdapTlsConfig~new
config~certificateFile = certificateFile
config~privateKeyFile = privateKeyFile
config~bridgeDirectory = bridgeDirectory
config~readTimeout = 10
config~writeTimeout = 10
tlsProvider = .OpenSslLdapTlsProvider~new(config)
server = .LdapWireServer~new(service, "127.0.0.1", port, "dc=example,dc=org", tlsProvider)
served = server~serve(2, readyFile)
tlsProvider~close
say "LDAP TLS FIXTURE DONE connections=" || served
::requires "tests/CryptoFastTestSetup.cls"
::requires "src/LdapWireServer.cls"
::requires "src/LdapOpenSslTls.cls"
