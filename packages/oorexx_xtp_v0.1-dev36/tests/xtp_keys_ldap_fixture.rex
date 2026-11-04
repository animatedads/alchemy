/* dev32 test fixture: an Identity Directory served over LDAP holding XTP
 * service keys.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: port readyFile connections secretHex
 * Service svc.ldap, profile encrypt (key set usage XTP_ENCRYPT):
 *   generation 1, key id 00000000000a11c0, now RETIRING
 *   generation 2, key id 00000000000a11c1, ACTIVE
 * Reader principal mu-07 binds with secret secret://identity/mu-07/ldap and may search. */
parse arg port readyFile connections secretHex
if connections = '' then connections = 2
dir = .IdentityDirectory~new('xtp-keys-fixture')
ignore = dir~createPrincipal('principal:mu-07', 'uid=mu-07,ou=nodes,dc=example,dc=org', 'SERVICE', 'MU 07', 'mu-07')
ignore = dir~createCredential('credential:mu-07:ldap', 'cn=ldap-bind,uid=mu-07,ou=nodes,dc=example,dc=org', 'principal:mu-07', 'LDAP_SIMPLE_BIND_SECRET', 'secret://identity/mu-07/ldap', .nil, .nil, 'ACTIVE')
ignore = dir~createResource('resource:directory', 'cn=directory,ou=resources,dc=example,dc=org', 'DIRECTORY', 'identity://example', 'Identity Directory')
ignore = dir~createAclGrant('acl:mu-07:search', 'cn=mu-07-search,ou=acl,dc=example,dc=org', 'principal:mu-07', 'resource:directory', 'LDAP_SEARCH', 'ALLOW')
ignore = dir~createPrincipal('service:svc.ldap', 'cn=svc.ldap,ou=services,dc=example,dc=org', 'SERVICE', 'XTP service svc.ldap', 'svc.ldap')
ignore = dir~createKeySet('keyset:xtp:svc.ldap', 'cn=xtp,cn=svc.ldap,ou=services,dc=example,dc=org', 'service:svc.ldap', 'XTP_ENCRYPT')
ignore = dir~stageKeyGeneration('key:xtp:svc.ldap:1', 'cn=1,cn=xtp,cn=svc.ldap,ou=services,dc=example,dc=org', 'keyset:xtp:svc.ldap', 1, 'AES256GCM', '00000000000a11c0', 'secret://xtp/svc.ldap/1')
ignore = dir~activateKeyGeneration('keyset:xtp:svc.ldap', 'key:xtp:svc.ldap:1')
ignore = dir~stageKeyGeneration('key:xtp:svc.ldap:2', 'cn=2,cn=xtp,cn=svc.ldap,ou=services,dc=example,dc=org', 'keyset:xtp:svc.ldap', 2, 'AES256GCM', '00000000000a11c1', 'secret://xtp/svc.ldap/2')
r = dir~activateKeyGeneration('keyset:xtp:svc.ldap', 'key:xtp:svc.ldap:2')
if \r~ok then do; say 'FIXTURE FAIL activate:' r~code; exit 1; end
provider = .TestSecretProvider~new
ignore = provider~put('secret://identity/mu-07/ldap', 'mu-07-bind-secret')
broker = .SecretBroker~new(provider)
authn = .SecretBrokerSimpleBindAuthenticator~new(dir, broker)
authority = .DirectoryAclLdapAuthority~new(dir)
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, authn, authority, 'resource:directory')
addresses = .RegisteredSocketAddressProvider~new
addresses~register('ldap.public', .SocketAddresses~tcp('127.0.0.1', port))
sockets = .SocketSelector~new(addresses)
sockets~registerBinding('TCP', .RxSockTcpBinding~new)
server = .LdapWireServer~new(service, '127.0.0.1', port, 'dc=example,dc=org', .nil, .nil, .false, 0.05, 30, .nil, sockets, 'ldap.public')
served = server~serve(connections, readyFile)
say 'XTP KEYS LDAP FIXTURE DONE connections='served
::requires 'RxSockSocketBinding.cls'
::requires 'src/LdapWireServer.cls'
