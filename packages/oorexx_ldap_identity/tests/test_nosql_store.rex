parse arg root
if root = '' then root = value('LDAP_NOSQL_TEST_ROOT',, 'ENVIRONMENT')
if root = '' then raise syntax 88.900 array('test root required')

say 'NOSQL DIRECTORY STORE START'
store = .NoSQLDirectoryStore~new(root)
dir = .IdentityDirectory~new('peer-nosql', store)

nb = .DateTime~fromUtcIsoDate('2026-09-22T12:00:00.000000Z')
na = .DateTime~fromUtcIsoDate('2027-09-22T12:00:00.000000Z')

r = dir~createPrincipal('principal:007', 'uid=007,ou=people,dc=example,dc=org', 'PERSON', '007', '007')
ignore = .LdapIdentityTest~assert(r~ok, 'NoSQL principal append')
entryUuidBefore = dir~entryById('principal:007')~entryUuid
r = dir~createCredential('credential:007', 'cn=password,uid=007,ou=people,dc=example,dc=org', 'principal:007', 'PASSWORD', 'secret://principal/007', nb, na, 'ACTIVE')
ignore = .LdapIdentityTest~assert(r~ok, 'NoSQL credential append')
r = dir~createResource('resource:ldap', 'cn=ldap,ou=resources,dc=example,dc=org', 'LDAP_DIRECTORY', 'ldap://directory', 'LDAP')
ignore = .LdapIdentityTest~assert(r~ok, 'NoSQL resource append')
r = dir~createAclGrant('acl:007', 'cn=007,ou=acl,dc=example,dc=org', 'principal:007', 'resource:ldap', 'LDAP_SEARCH', 'ALLOW')
ignore = .LdapIdentityTest~assert(r~ok, 'NoSQL ACL append')
rev = dir~revision

store2 = .NoSQLDirectoryStore~new(root)
recovered = .IdentityDirectory~new('peer-nosql', store2)
ignore = .LdapIdentityTest~equal(rev, recovered~revision, 'NoSQL revision recovered')
ignore = .LdapIdentityTest~equal('007', recovered~entryById('principal:007')~displayName, 'NoSQL JSON keeps numeric-looking display string')
ignore = .LdapIdentityTest~equal(entryUuidBefore, recovered~entryById('principal:007')~entryUuid, 'LDAP entryUUID stable across durable recovery')
cred = recovered~entryById('credential:007')
ignore = .LdapIdentityTest~assert(cred~notBefore~isA(.DateTime), 'NoSQL notBefore is DateTime')
ignore = .LdapIdentityTest~equal(nb~utcIsoDate, cred~notBefore~utcIsoDate, 'NoSQL DateTime instant recovered')
ignore = .LdapIdentityTest~equal('secret://principal/007', cred~secretRef, 'NoSQL stores secret reference only')
ignore = .LdapIdentityTest~assert(recovered~aclDecision('principal:007', 'resource:ldap', 'LDAP_SEARCH')~ok, 'NoSQL ACL recovered')

r = recovered~updatePrincipal('principal:007', 'Bond')
ignore = .LdapIdentityTest~assert(r~ok, 'NoSQL update after recovery')
store3 = .NoSQLDirectoryStore~new(root)
recovered2 = .IdentityDirectory~new('peer-nosql', store3)
ignore = .LdapIdentityTest~equal('Bond', recovered2~entryById('principal:007')~displayName, 'NoSQL second restart sees update')
ignore = .LdapIdentityTest~equal(entryUuidBefore, recovered2~entryById('principal:007')~entryUuid, 'LDAP entryUUID stable across update and second restart')

peerMismatch = store3~bindDirectory('different-peer')
ignore = .LdapIdentityTest~assert(\peerMismatch~ok, 'NoSQL durable peer binding refuses identity drift')
ignore = .LdapIdentityTest~equal('STORE_PEER_MISMATCH', peerMismatch~code, 'peer mismatch code')

caps = store3~capabilities
ignore = .LdapIdentityTest~assert(caps['durable'], 'NoSQL provider advertises durable')
ignore = .LdapIdentityTest~equal('NOSQLSERVER_FILE', caps['provider'], 'NoSQL provider identity')

say 'NOSQL DIRECTORY STORE: OK'

::requires 'src/NoSQLDirectoryStore.cls'
::requires 'tests/TestSupport.cls'
