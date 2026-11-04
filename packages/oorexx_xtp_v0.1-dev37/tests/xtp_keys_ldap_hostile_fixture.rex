/* dev33 test fixture: an Identity Directory with hostile entries next to the
 * XTP keys of svc.ldap.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5),
 * from the probes of the second dev32 security review.
 * Arguments: port readyFile connections secretHex mode
 *   tenant:    svc.ldap's generation 2 is revoked and generation 3 rotated in;
 *              the tenant service:evil has a set whose only generation is broken
 *   inject:    a principal whose id carries a second key line (review F1)
 *   placement: a generation for svc.ldap's set, placed in the tenant's subtree
 *   client:    (dev35, gateway mode B) client alice of svc.ldap, under the
 *              service's entry, with her own key; and client mallory, whose
 *              principal sits in the tenant's subtree instead
 *   anchor:    (dev35) a service principal service:svc.deep placed inside the
 *              tenant's subtree, with a key set; the client passes serviceBaseDn */
parse arg port readyFile connections secretHex mode
dir = .IdentityDirectory~new('xtp-keys-hostile')
ignore = dir~createPrincipal('principal:mu-07', 'uid=mu-07,ou=nodes,dc=example,dc=org', 'SERVICE', 'MU 07', 'mu-07')
ignore = dir~createCredential('credential:mu-07:ldap', 'cn=ldap-bind,uid=mu-07,ou=nodes,dc=example,dc=org', 'principal:mu-07', 'LDAP_SIMPLE_BIND_SECRET', 'secret://identity/mu-07/ldap', .nil, .nil, 'ACTIVE')
ignore = dir~createResource('resource:directory', 'cn=directory,ou=resources,dc=example,dc=org', 'DIRECTORY', 'identity://example', 'Identity Directory')
ignore = dir~createAclGrant('acl:mu-07:search', 'cn=mu-07-search,ou=acl,dc=example,dc=org', 'principal:mu-07', 'resource:directory', 'LDAP_SEARCH', 'ALLOW')
ignore = dir~createPrincipal('service:svc.ldap', 'cn=svc.ldap,ou=services,dc=example,dc=org', 'SERVICE', 'svc', 'svc.ldap')
ignore = dir~createKeySet('keyset:xtp:svc.ldap', 'cn=xtp,cn=svc.ldap,ou=services,dc=example,dc=org', 'service:svc.ldap', 'XTP_ENCRYPT')
ignore = dir~stageKeyGeneration('key:xtp:svc.ldap:1', 'cn=1,cn=xtp,cn=svc.ldap,ou=services,dc=example,dc=org', 'keyset:xtp:svc.ldap', 1, 'AES256GCM', '00000000000a11c0', 'secret://xtp/svc.ldap/1')
ignore = dir~activateKeyGeneration('keyset:xtp:svc.ldap', 'key:xtp:svc.ldap:1')
ignore = dir~stageKeyGeneration('key:xtp:svc.ldap:2', 'cn=2,cn=xtp,cn=svc.ldap,ou=services,dc=example,dc=org', 'keyset:xtp:svc.ldap', 2, 'AES256GCM', '00000000000a11c1', 'secret://xtp/svc.ldap/2')
ignore = dir~activateKeyGeneration('keyset:xtp:svc.ldap', 'key:xtp:svc.ldap:2')
/* the tenant service:evil, which may write only under cn=evil,ou=services */
ignore = dir~createPrincipal('service:evil', 'cn=evil,ou=services,dc=example,dc=org', 'SERVICE', 'evil', 'evil')
if mode = 'tenant' then do
  /* operator: generation 2 compromised -> revoked; generation 3 rotated in */
  ignore = dir~stageKeyGeneration('key:xtp:svc.ldap:3', 'cn=3,cn=xtp,cn=svc.ldap,ou=services,dc=example,dc=org', 'keyset:xtp:svc.ldap', 3, 'AES256GCM', '00000000000a11c2', 'secret://xtp/svc.ldap/3')
  ignore = dir~activateKeyGeneration('keyset:xtp:svc.ldap', 'key:xtp:svc.ldap:3')
  r = dir~revokeKeyGeneration('key:xtp:svc.ldap:2', 'compromised')
  /* tenant: one malformed generation in its own subtree */
  ignore = dir~createKeySet('keyset:xtp:evil', 'cn=xtp,cn=evil,ou=services,dc=example,dc=org', 'service:evil', 'XTP_ENCRYPT')
  ignore = dir~stageKeyGeneration('key:xtp:evil:1', 'cn=1,cn=xtp,cn=evil,ou=services,dc=example,dc=org', 'keyset:xtp:evil', 1, 'DES', 'zz', 'secret://xtp/evil/1')
  r = dir~activateKeyGeneration('keyset:xtp:evil', 'key:xtp:evil:1')
end
if mode = 'inject' then do
  crafted = 'service:evil/x 00000000000098aa authenticate aes256gcm' copies('1', 64) || '0a'x || 'svc.ldap 00000000000098bb encrypt aes256gcm' copies('7', 64) || '0a'x || '#'
  r1 = dir~createPrincipal(crafted, 'cn=x,cn=evil,ou=services,dc=example,dc=org', 'SERVICE', 'x', 'x')
  r2 = dir~createKeySet('keyset:x', 'cn=xtp,cn=x,cn=evil,ou=services,dc=example,dc=org', crafted, 'XTP_ENCRYPT')
  r3 = dir~stageKeyGeneration('key:x:1', 'cn=1,cn=xtp,cn=x,cn=evil,ou=services,dc=example,dc=org', 'keyset:x', 1, 'AES256GCM', '00000000000098cc', 'secret://xtp/' || crafted~substr(9) || '/1')
  r4 = dir~activateKeyGeneration('keyset:x', 'key:x:1')
  say 'FIXTURE inject entries' r1~ok r2~ok r3~ok r4~ok
end
if mode = 'placement' then do
  r1 = dir~stageKeyGeneration('key:xtp:svc.ldap:9', 'cn=9,cn=evil,ou=services,dc=example,dc=org', 'keyset:xtp:svc.ldap', 9, 'AES256GCM', '00000000000098dd', 'secret://xtp/svc.ldap/9')
  r2 = dir~activateKeyGeneration('keyset:xtp:svc.ldap', 'key:xtp:svc.ldap:9')
  say 'FIXTURE placement entries' r1~ok r2~ok
end
if mode = 'client' then do
  r1 = dir~createPrincipal('service:svc.ldap/client:alice', 'cn=alice,cn=svc.ldap,ou=services,dc=example,dc=org', 'SERVICE', 'alice', 'alice')
  r2 = dir~createKeySet('keyset:xtp:svc.ldap:alice', 'cn=xtp,cn=alice,cn=svc.ldap,ou=services,dc=example,dc=org', 'service:svc.ldap/client:alice', 'XTP_ENCRYPT')
  r3 = dir~stageKeyGeneration('key:xtp:svc.ldap:alice:1', 'cn=1,cn=xtp,cn=alice,cn=svc.ldap,ou=services,dc=example,dc=org', 'keyset:xtp:svc.ldap:alice', 1, 'AES256GCM', '00000000000a11ce', 'secret://xtp/svc.ldap/alice/1')
  r4 = dir~activateKeyGeneration('keyset:xtp:svc.ldap:alice', 'key:xtp:svc.ldap:alice:1')
  m1 = dir~createPrincipal('service:svc.ldap/client:mallory', 'cn=mallory,cn=evil,ou=services,dc=example,dc=org', 'SERVICE', 'mallory', 'mallory')
  m2 = dir~createKeySet('keyset:xtp:svc.ldap:mallory', 'cn=xtp,cn=mallory,cn=evil,ou=services,dc=example,dc=org', 'service:svc.ldap/client:mallory', 'XTP_ENCRYPT')
  m3 = dir~stageKeyGeneration('key:xtp:svc.ldap:mallory:1', 'cn=1,cn=xtp,cn=mallory,cn=evil,ou=services,dc=example,dc=org', 'keyset:xtp:svc.ldap:mallory', 1, 'AES256GCM', '000000000000bad1', 'secret://xtp/svc.ldap/mallory/1')
  m4 = dir~activateKeyGeneration('keyset:xtp:svc.ldap:mallory', 'key:xtp:svc.ldap:mallory:1')
  say 'FIXTURE client entries' r1~ok r2~ok r3~ok r4~ok m1~ok m2~ok m3~ok m4~ok
end
if mode = 'anchor' then do
  r1 = dir~createPrincipal('service:svc.deep', 'cn=svc.deep,cn=evil,ou=services,dc=example,dc=org', 'SERVICE', 'deep', 'deep')
  r2 = dir~createKeySet('keyset:xtp:svc.deep', 'cn=xtp,cn=svc.deep,cn=evil,ou=services,dc=example,dc=org', 'service:svc.deep', 'XTP_ENCRYPT')
  r3 = dir~stageKeyGeneration('key:xtp:svc.deep:1', 'cn=1,cn=xtp,cn=svc.deep,cn=evil,ou=services,dc=example,dc=org', 'keyset:xtp:svc.deep', 1, 'AES256GCM', '00000000000dee01', 'secret://xtp/svc.deep/1')
  r4 = dir~activateKeyGeneration('keyset:xtp:svc.deep', 'key:xtp:svc.deep:1')
  say 'FIXTURE anchor entries' r1~ok r2~ok r3~ok r4~ok
end
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
::requires 'RxSockSocketBinding.cls'
::requires 'src/LdapWireServer.cls'
