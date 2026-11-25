/* ldap_fixture.rex -- a real ooRexx LDAP server (oorexx_ldap_identity dev9) on
 * loopback, for the ldap.role probe test.  Test only.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 25 November 2026.
 * Built the same way as that package's own sync-persist fixture server.
 * Usage: rexx ldap_fixture.rex PORT READYFILE */
parse arg port readyFile
dir = .IdentityDirectory~new("xtpd-ldap-role-fixture")
ignore = dir~createPrincipal("principal:probe", "uid=probe,ou=people,dc=example,dc=org", "PERSON", "Probe", "probe")
ignore = dir~createResource("resource:directory", "cn=directory,ou=resources,dc=example,dc=org", "DIRECTORY", "identity://example", "Identity Directory")
broker = .SecretBroker~new(.TestSecretProvider~new)
authn = .SecretBrokerSimpleBindAuthenticator~new(dir, broker)
authority = .DirectoryAclLdapAuthority~new(dir)
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, authn, authority, "resource:directory")
server = .LdapWireServer~new(service, "127.0.0.1", port, "dc=example,dc=org", .nil, .nil, .false, 0.05, 0.25)
served = server~serve(0, readyFile)
::requires "src/LdapWireServer.cls"
